import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface OcrRequestPayload {
  documentId: string;
  storagePath: string;
  fileType: string;
  courseCode?: string;
  extractedText?: string;
}

interface FlashcardItem {
  topic: string;
  raw_text: string;
  latex_content?: string | null;
  confidence_score?: number;
}

interface DocumentChunk {
  title: string;
  text: string;
  index: number;
}

/**
 * Splits massive, multi-hundred page documents into cohesive chapter or
 * semantic paragraph sections so Gemini and local heuristics process the
 * entire document from beginning to end without arbitrary character truncations.
 */
function segmentDocumentIntoChaptersOrWindows(fullText: string): DocumentChunk[] {
  const trimmed = fullText.trim();
  if (!trimmed) return [];

  const MAX_CHUNK_LENGTH = 35000; // ~5,000-7,000 words per chunk for optimal LLM synthesis

  // 1. Detect formal chapter / module / unit / lecture / section markers
  const chapterRegex =
    /(?:^|\n)(?:(?:CHAPTER|Chapter|MODULE|Module|UNIT|Unit|SECTION|Section|PART|Part|LECTURE|Lecture)\s+(?:\d+|[IVXLCDM]+|[A-Z])\b[^\n]*|#{1,3}\s+[^\n]+)/gi;
  const matches = Array.from(trimmed.matchAll(chapterRegex));

  const chunks: DocumentChunk[] = [];

  if (matches.length >= 2) {
    for (let i = 0; i < matches.length; i++) {
      const match = matches[i];
      const startIdx = match.index ?? 0;
      const endIdx =
        i + 1 < matches.length ? matches[i + 1].index ?? trimmed.length : trimmed.length;
      const rawTitle = match[0].trim().replace(/^#+\s*/, "");
      const chapterBody = trimmed.substring(startIdx, endIdx).trim();

      if (chapterBody.length <= MAX_CHUNK_LENGTH) {
        chunks.push({
          title: rawTitle,
          text: chapterBody,
          index: chunks.length + 1,
        });
      } else {
        // Subdivide oversized chapters on paragraph boundaries
        const subParts = partitionByParagraphs(chapterBody, MAX_CHUNK_LENGTH);
        for (let p = 0; p < subParts.length; p++) {
          chunks.push({
            title: `${rawTitle} (Part ${p + 1})`,
            text: subParts[p],
            index: chunks.length + 1,
          });
        }
      }
    }
  } else {
    // No explicit chapter markers; partition into cohesive semantic paragraph windows
    const subParts = partitionByParagraphs(trimmed, MAX_CHUNK_LENGTH);
    for (let p = 0; p < subParts.length; p++) {
      chunks.push({
        title: `Section ${p + 1}`,
        text: subParts[p],
        index: chunks.length + 1,
      });
    }
  }

  return chunks;
}

/**
 * Partitions continuous text into paragraph-preserving blocks without breaking mid-sentence.
 */
function partitionByParagraphs(text: string, maxLen: number): string[] {
  const paragraphs = text.split(/(?:\r?\n){2,}/);
  const result: string[] = [];
  let current = "";

  for (const para of paragraphs) {
    const clean = para.trim();
    if (!clean) continue;

    if (current.length + clean.length + 2 > maxLen && current.length > 500) {
      result.push(current.trim());
      current = clean;
    } else {
      current = current ? `${current}\n\n${clean}` : clean;
    }
  }

  if (current.trim().length > 0) {
    result.push(current.trim());
  }

  return result.length > 0 ? result : [text];
}

/**
 * Safe chunked Uint8Array to base64 conversion preventing call-stack overflow on large buffers.
 */
function safeUint8ArrayToBase64(bytes: Uint8List): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk as unknown as number[]);
  }
  return btoa(binary);
}

/**
 * Deep contextual question formatter for heuristic / fallback parsing
 */
function formatContextualQuestion(header: string, bodyText: string): string {
  const clean = header
    .replace(/^(?:(?:Part|Step|Rule|Section|\d+\.|\d+\.\d+|[A-Z]\.)\s*)+/i, "")
    .replace(/:$/, "")
    .trim();
  const lower = clean.toLowerCase();
  const lowerBody = bodyText.toLowerCase();

  if (
    (lower.includes("timeframe") || lowerBody.includes("timeframe")) &&
    (lowerBody.includes("m15") || lowerBody.includes("m1"))
  ) {
    return "What timeframes are utilized in this strategy, and what is the role of each chart?";
  }
  if (lower.includes("rectangle") || lowerBody.includes("rectangle")) {
    return "What is the role of the rectangle in this trading strategy, and how does it define entries?";
  }
  if (lower.endsWith("defined") || lower.endsWith("definition")) {
    const subject = clean.replace(/\s+(?:defined|definition)$/i, "").trim();
    return `What is the definition and core concept of ${subject}?`;
  }
  if (
    lower.startsWith("what") ||
    lower.startsWith("how") ||
    lower.startsWith("why") ||
    lower.startsWith("explain")
  ) {
    return clean.endsWith("?") ? clean : `${clean}?`;
  }
  if (clean.length > 0) {
    return `What are the key rules and concepts regarding ${clean}?`;
  }
  return "What are the key principles explained in this section?";
}

/**
 * Extracts fallback flashcards from structured text lines in a section
 */
function extractFallbackCardsFromChunk(chunkText: string, defaultTopic: string): FlashcardItem[] {
  const cards: FlashcardItem[] = [];
  const lines = chunkText
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  let curTopic = "";
  let curBody: string[] = [];

  for (const line of lines) {
    const isHeader =
      /^(?:(?:Part|Step|Rule|Section|\d+\.|\d+\.\d+|[A-Z]\.)\s+[A-Z]|\b[A-Z][a-zA-Z\s]{3,35}:)/.test(
        line
      );
    if (isHeader) {
      if (curTopic && curBody.length > 0) {
        const bodyStr = curBody.join(" ");
        cards.push({
          topic: formatContextualQuestion(curTopic, bodyStr),
          raw_text: bodyStr,
          confidence_score: 0.95,
        });
        curBody = [];
      }
      curTopic = line.replace(/:$/, "").trim();
    } else if (curTopic) {
      curBody.push(line);
    }
  }

  if (curTopic && curBody.length > 0) {
    const bodyStr = curBody.join(" ");
    cards.push({
      topic: formatContextualQuestion(curTopic, bodyStr),
      raw_text: bodyStr,
      confidence_score: 0.95,
    });
  }

  // If no formal headers were found in this chunk, create a card from the text itself
  if (cards.length === 0 && chunkText.trim().length >= 30) {
    const sentences = chunkText
      .split(/(?<=[.?!])\s+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 15);
    if (sentences.length > 0) {
      const prompt = `What are the key principles of ${defaultTopic}?`;
      cards.push({
        topic: prompt,
        raw_text: sentences.slice(0, 5).join(" "),
        confidence_score: 0.90,
      });
    }
  }

  return cards;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let userId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace(/^Bearer\s+/i, "");
      const {
        data: { user },
      } = await supabase.auth.getUser(token);
      userId = user?.id ?? null;
    }

    if (!userId) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload: OcrRequestPayload = await req.json().catch(() => ({}));
    const { documentId, storagePath, fileType, courseCode, extractedText } = payload;

    if (!documentId) {
      return new Response(JSON.stringify({ error: "documentId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Check Semantic Cache for pre-extracted OCR text
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabase,
      `ocr_extract:${documentId}:${storagePath}`,
      { courseCode }
    );

    if (cacheResult.hit && cacheResult.data?.snippets) {
      return new Response(
        JSON.stringify({
          success: true,
          document_id: documentId,
          snippets: cacheResult.data.snippets,
          cache_hit: true,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "X-Cache": "HIT",
          },
        }
      );
    }

    // Update document status to parsingOcr
    await supabase
      .from("documents")
      .update({ processing_status: "parsingOcr" })
      .eq("id", documentId);

    // 2. Obtain content (text or binary bytes)
    let textContent = extractedText ?? "";
    let base64Pdf: string | null = null;

    if (!textContent && storagePath) {
      try {
        const { data: fileBlob, error: downloadError } = await supabase.storage
          .from("study-documents")
          .download(storagePath);

        if (!downloadError && fileBlob) {
          const arrayBuffer = await fileBlob.arrayBuffer();
          const bytes = new Uint8List(arrayBuffer);
          const ext = (fileType || "").toLowerCase();

          if (ext.includes("pdf") || storagePath.toLowerCase().endsWith(".pdf")) {
            // If PDF is <= 18MB, encode for Gemini vision/document understanding safely
            if (bytes.byteLength < 18 * 1024 * 1024) {
              base64Pdf = safeUint8ArrayToBase64(bytes);
            }
          } else {
            textContent = new TextDecoder().decode(bytes);
          }
        }
      } catch (dlErr) {
        console.warn("[parse-stem-ocr] Storage download notice:", dlErr);
      }
    }

    // 3. AI Smart Flashcard Synthesis using Gemini across the ENTIRE document
    const geminiApiKey =
      Deno.env.get("GEMINI_API_KEY") ||
      Deno.env.get("GOOGLE_AI_API_KEY") ||
      "";

    const flashcards: FlashcardItem[] = [];

    if (textContent.length > 50) {
      // Document is segmented into chapters / cohesive semantic windows
      const chunks = segmentDocumentIntoChaptersOrWindows(textContent);
      console.log(
        `[parse-stem-ocr] Segmented document into ${chunks.length} chapter/semantic chunks for comprehensive synthesis.`
      );

      // Process chunks concurrently in batches of 4 to guarantee fast, non-blocking execution
      const BATCH_SIZE = 4;

      for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
        const currentBatch = chunks.slice(i, i + BATCH_SIZE);

        const batchResults = await Promise.allSettled(
          currentBatch.map(async (chunk) => {
            if (geminiApiKey) {
              try {
                const systemPrompt =
                  "You are an expert pedagogical AI specializing in synthesizing high-yield SM-2 spaced repetition flashcards from study documents.\n" +
                  `Your task is to thoroughly analyze this document section: "${chunk.title}" (Part ${chunk.index} of ${chunks.length}) and generate comprehensive, high-quality flashcards.\n\n` +
                  "RULES FOR CARDS:\n" +
                  "1. TOPIC: Must be a clear, specific question or concept prompt covering key definitions, rules, mechanisms, or principles in this section.\n" +
                  "2. RAW_TEXT: Must be a complete, highly explanatory answer containing all definitions, steps, conditions, or bullet points.\n" +
                  "3. LATEX_CONTENT: If the card involves a mathematical formula, ratio, or calculation (e.g. Risk-to-Reward Ratio \\ge 3:1, calculus), provide valid LaTeX math notation. Otherwise set to null.\n" +
                  "4. CONFIDENCE_SCORE: Set to 0.98.\n" +
                  "5. CRITICAL: NO ARTIFICIAL CAP. Generate as many high-quality, distinct cards as needed to thoroughly cover this section without omitting any key concept.\n\n" +
                  "Output format: Return ONLY a JSON array of card objects with keys: topic, raw_text, latex_content, confidence_score.";

                const contents = [
                  {
                    role: "user",
                    parts: [
                      { text: systemPrompt },
                      { text: `SECTION CONTENT (${chunk.title}):\n${chunk.text}` },
                    ],
                  },
                ];

                const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
                const aiResponse = await fetch(geminiUrl, {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({
                    contents,
                    generationConfig: {
                      response_mime_type: "application/json",
                      temperature: 0.2,
                    },
                  }),
                });

                if (aiResponse.ok) {
                  const aiJson = await aiResponse.json();
                  const candidateText =
                    aiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

                  if (candidateText) {
                    const parsed = JSON.parse(candidateText);
                    const cardArray = Array.isArray(parsed)
                      ? parsed
                      : Array.isArray(parsed.cards)
                      ? parsed.cards
                      : Array.isArray(parsed.flashcards)
                      ? parsed.flashcards
                      : [];

                    const extractedFromAi: FlashcardItem[] = [];
                    for (const item of cardArray) {
                      if (
                        item.topic &&
                        item.raw_text &&
                        item.topic.length > 5 &&
                        item.raw_text.length > 10
                      ) {
                        extractedFromAi.push({
                          topic: item.topic.trim(),
                          raw_text: item.raw_text.trim(),
                          latex_content: item.latex_content ?? null,
                          confidence_score: item.confidence_score ?? 0.98,
                        });
                      }
                    }

                    if (extractedFromAi.length > 0) {
                      return extractedFromAi;
                    }
                  }
                }
              } catch (chunkErr) {
                console.warn(
                  `[parse-stem-ocr] AI synthesis notice on "${chunk.title}":`,
                  chunkErr
                );
              }
            }

            // Fallback for this specific chunk if AI unavailable or returned 0
            return extractFallbackCardsFromChunk(chunk.text, chunk.title);
          })
        );

        for (const res of batchResults) {
          if (res.status === "fulfilled" && Array.isArray(res.value)) {
            flashcards.push(...res.value);
          }
        }
      }
    } else if (base64Pdf && geminiApiKey) {
      // Direct PDF Vision analysis when extractedText is not pre-populated
      try {
        const systemPrompt =
          "You are an expert pedagogical AI specializing in synthesizing high-yield SM-2 spaced repetition flashcards from study documents.\n" +
          "Your task is to thoroughly analyze this entire document from beginning to end across all chapters and generate comprehensive, high-quality flashcards.\n\n" +
          "RULES FOR CARDS:\n" +
          "1. TOPIC: Must be a clear, specific question or concept prompt covering key definitions, rules, mechanisms, or principles across all sections.\n" +
          "2. RAW_TEXT: Must be a complete, highly explanatory answer containing all rules, conditions, bullet points, or checklist steps.\n" +
          "3. LATEX_CONTENT: If the card involves a mathematical formula, ratio, or calculation, provide valid LaTeX math notation. Otherwise set to null.\n" +
          "4. CONFIDENCE_SCORE: Set to 0.98.\n" +
          "5. CRITICAL: NO ARTIFICIAL CAP. Generate as many high-quality flashcards as necessary to cover every chapter in this document.\n\n" +
          "Output format: Return ONLY a JSON array of card objects with keys: topic, raw_text, latex_content, confidence_score.";

        const contents = [
          {
            role: "user",
            parts: [
              { text: systemPrompt },
              {
                inline_data: {
                  mime_type: "application/pdf",
                  data: base64Pdf,
                },
              },
            ],
          },
        ];

        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const aiResponse = await fetch(geminiUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents,
            generationConfig: {
              response_mime_type: "application/json",
              temperature: 0.2,
            },
          }),
        });

        if (aiResponse.ok) {
          const aiJson = await aiResponse.json();
          const candidateText =
            aiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

          if (candidateText) {
            const parsed = JSON.parse(candidateText);
            const cardArray = Array.isArray(parsed)
              ? parsed
              : Array.isArray(parsed.cards)
              ? parsed.cards
              : Array.isArray(parsed.flashcards)
              ? parsed.flashcards
              : [];

            for (const item of cardArray) {
              if (
                item.topic &&
                item.raw_text &&
                item.topic.length > 5 &&
                item.raw_text.length > 10
              ) {
                flashcards.push({
                  topic: item.topic.trim(),
                  raw_text: item.raw_text.trim(),
                  latex_content: item.latex_content ?? null,
                  confidence_score: item.confidence_score ?? 0.98,
                });
              }
            }
          }
        }
      } catch (pdfErr) {
        console.error("[parse-stem-ocr] Gemini base64 PDF error:", pdfErr);
      }
    }

    // 4. Global deduplication of cards across chapter boundaries
    const seenTopics = new Set<string>();
    const uniqueFlashcards: FlashcardItem[] = [];

    for (const card of flashcards) {
      const normalizedTopic = card.topic.toLowerCase().replace(/[^a-z0-9]/g, "");
      if (!seenTopics.has(normalizedTopic)) {
        seenTopics.add(normalizedTopic);
        uniqueFlashcards.push(card);
      }
    }

    // 5. Insert synthesized snippets into `public.extracted_snippets` in batches of 100
    const snippetsToInsert = uniqueFlashcards.map((c) => ({
      id: crypto.randomUUID(),
      document_id: documentId,
      user_id: userId,
      raw_text: c.raw_text,
      latex_content: c.latex_content ?? null,
      topic: c.topic,
      confidence_score: c.confidence_score ?? 0.98,
    }));

    if (snippetsToInsert.length > 0) {
      const DB_BATCH = 100;
      for (let i = 0; i < snippetsToInsert.length; i += DB_BATCH) {
        const slice = snippetsToInsert.slice(i, i + DB_BATCH);
        const { error: snippetErr } = await supabase
          .from("extracted_snippets")
          .insert(slice);

        if (snippetErr) {
          console.error(
            "[parse-stem-ocr] Insert to extracted_snippets error:",
            snippetErr
          );
        }
      }
    }

    // Update document status to completed
    await supabase
      .from("documents")
      .update({ processing_status: "completed" })
      .eq("id", documentId);

    // Cache the OCR output
    await SemanticCacheProvider.setCachedResponse(
      supabase,
      `ocr_extract:${documentId}:${storagePath}`,
      { snippets: snippetsToInsert },
      { courseCode }
    );

    return new Response(
      JSON.stringify({
        success: true,
        document_id: documentId,
        snippets: snippetsToInsert,
        snippets_extracted: snippetsToInsert.length,
        cache_hit: false,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "X-Cache": "MISS",
        },
      }
    );
  } catch (error) {
    console.error("Error in parse-stem-ocr:", error);
    return new Response(
      JSON.stringify({
        error: (error as Error).message || "Internal Server Error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
