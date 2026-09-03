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
            // Encode as base64 for Gemini PDF vision/document understanding
            let binary = "";
            const len = bytes.byteLength;
            for (let i = 0; i < len; i++) {
              binary += String.fromCharCode(bytes[i]);
            }
            base64Pdf = btoa(binary);
          } else {
            textContent = new TextDecoder().decode(bytes);
          }
        }
      } catch (dlErr) {
        console.warn("[parse-stem-ocr] Storage download notice:", dlErr);
      }
    }

    // 3. AI Smart Flashcard Synthesis using Gemini / LLM
    const geminiApiKey =
      Deno.env.get("GEMINI_API_KEY") ||
      Deno.env.get("GOOGLE_AI_API_KEY") ||
      "";

    const flashcards: FlashcardItem[] = [];

    if (geminiApiKey && (textContent.length > 50 || base64Pdf)) {
      try {
        const systemPrompt =
          "You are an expert pedagogical AI specializing in synthesizing high-yield SM-2 spaced repetition flashcards from study documents.\n" +
          "Your task is to thoroughly analyze this document and generate between 12 and 22 comprehensive, high-quality flashcards.\n\n" +
          "RULES FOR CARDS:\n" +
          "1. TOPIC: Must be a clear, specific question or concept prompt. NEVER output a vague phrase or single word (e.g. Do NOT output 'What is high-probability?'). Instead, ask: 'What are the timeframes used in this strategy and what is the role of each?' or 'How is the Rectangle defined in this trading plan?'.\n" +
          "2. RAW_TEXT: Must be a complete, highly explanatory answer containing all rules, conditions, bullet points, or checklist steps. Never give a 1-word answer or echo the question.\n" +
          "3. LATEX_CONTENT: If the card involves a mathematical formula, ratio, or calculation (e.g. Risk-to-Reward Ratio \\ge 3:1, Exponential Moving Average, calculus), provide valid LaTeX math notation. Otherwise set to null.\n" +
          "4. CONFIDENCE_SCORE: Set to 0.98.\n" +
          "5. Cover all key sections: Definitions, timeframes, indicators, entry triggers, execution steps, risk management (stop loss / take profit), and pre-trade checklist.\n\n" +
          "Output format: Return ONLY a JSON array of card objects with keys: topic, raw_text, latex_content, confidence_score.";

        const contents: any[] = [];
        const parts: any[] = [{ text: systemPrompt }];

        if (base64Pdf) {
          parts.push({
            inline_data: {
              mime_type: "application/pdf",
              data: base64Pdf,
            },
          });
        } else {
          parts.push({
            text: `DOCUMENT CONTENT:\n${textContent.substring(0, 50000)}`,
          });
        }

        contents.push({ role: "user", parts });

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
              if (item.topic && item.raw_text && item.topic.length > 5 && item.raw_text.length > 10) {
                flashcards.push({
                  topic: item.topic.trim(),
                  raw_text: item.raw_text.trim(),
                  latex_content: item.latex_content ?? null,
                  confidence_score: item.confidence_score ?? 0.98,
                });
              }
            }
          }
        } else {
          const errText = await aiResponse.text();
          console.warn("[parse-stem-ocr] Gemini API returned non-OK:", errText);
        }
      } catch (aiErr) {
        console.error("[parse-stem-ocr] Gemini generation exception:", aiErr);
      }
    }

    // 4. Fallback if AI yielded zero cards or key missing
    if (flashcards.length === 0) {
      if (textContent.length > 0) {
        // Generate heuristic cards from text sections
        const lines = textContent.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
        let curTopic = "";
        let curBody: string[] = [];

        for (const line of lines) {
          const isHeader = /^(?:(?:Part|Step|Rule|Section|\d+\.|\d+\.\d+|[A-Z]\.)\s+[A-Z]|\b[A-Z][a-zA-Z\s]{3,30}:)/.test(line);
          if (isHeader) {
            if (curTopic && curBody.length > 0) {
              flashcards.push({
                topic: curTopic,
                raw_text: curBody.join(" "),
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
          flashcards.push({
            topic: curTopic,
            raw_text: curBody.join(" "),
            confidence_score: 0.95,
          });
        }
      }
    }

    // 5. Insert synthesized snippets into `public.extracted_snippets` (correct schema table)
    const snippetsToInsert = flashcards.map((c) => ({
      id: crypto.randomUUID(),
      document_id: documentId,
      user_id: userId,
      raw_text: c.raw_text,
      latex_content: c.latex_content ?? null,
      topic: c.topic,
      confidence_score: c.confidence_score ?? 0.98,
    }));

    if (snippetsToInsert.length > 0) {
      const { error: snippetErr } = await supabase
        .from("extracted_snippets")
        .insert(snippetsToInsert);

      if (snippetErr) {
        console.error("[parse-stem-ocr] Insert to extracted_snippets error:", snippetErr);
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
