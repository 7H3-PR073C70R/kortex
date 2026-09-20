import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { LunaClient } from "../_shared/luna_client.ts";
import { ServerDocumentParser } from "../_shared/server_document_parser.ts";

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
  filename?: string;
  courseCode?: string;
  courseId?: string;
  courseTitle?: string;
  deckTitle?: string;
  extractedText?: string;
}

/**
 * Broadcasts progress updates to client via Supabase Realtime channel.
 */
async function broadcastProgress(
  supabase: any,
  documentId: string,
  data: {
    status: string;
    progress: number;
    stageMessage: string;
    deckId?: string;
  }
) {
  try {
    const channel = supabase.channel(`document_ingestion:${documentId}`);
    await channel.send({
      type: "broadcast",
      event: "ingestion_progress",
      payload: {
        documentId,
        ...data,
        timestamp: new Date().toISOString(),
      },
    });
    await supabase.removeChannel(channel);
  } catch (err) {
    console.warn("[parse-stem-ocr] Realtime progress broadcast notice:", err);
  }
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
    const {
      documentId,
      storagePath,
      fileType = "pdf",
      filename = "Document.pdf",
      courseCode = "GENERAL",
      courseId,
      courseTitle,
      deckTitle: requestedDeckTitle,
      extractedText,
    } = payload;

    if (!documentId) {
      return new Response(JSON.stringify({ error: "documentId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Zero-Trust Ownership Verification
    const { data: documentRecord } = await supabase
      .from("documents")
      .select("id, user_id, filename, content_hash")
      .eq("id", documentId)
      .maybeSingle();

    if (documentRecord && documentRecord.user_id !== userId) {
      return new Response(
        JSON.stringify({ error: "Forbidden: You do not own this document" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const contentHash = documentRecord?.content_hash;
    const resolvedFilename = documentRecord?.filename || filename;
    const cleanDeckTitle =
      requestedDeckTitle ||
      courseTitle ||
      resolvedFilename.replace(/\.[a-zA-Z0-9]+$/, "").trim();

    // Stage 1: Document Download & Loading (15%)
    await broadcastProgress(supabase, documentId, {
      status: "parsingOcr",
      progress: 0.15,
      stageMessage: "Loading document on server compute...",
    });

    await supabase
      .from("documents")
      .update({ processing_status: "parsingOcr" })
      .eq("id", documentId);

    // Fetch document bytes from Storage bucket if text is not pre-provided
    let fileBytes: Uint8Array | null = null;
    if (storagePath) {
      try {
        const { data: fileBlob, error: downloadError } = await supabase.storage
          .from("study-documents")
          .download(storagePath);

        if (!downloadError && fileBlob) {
          const buffer = await fileBlob.arrayBuffer();
          fileBytes = new Uint8Array(buffer);
        } else if (downloadError) {
          console.warn("[parse-stem-ocr] Storage download error:", downloadError.message);
        }
      } catch (dlErr) {
        console.warn("[parse-stem-ocr] Storage download exception:", dlErr);
      }
    }

    // Stage 2: Server-Side Compute Extraction (35%)
    await broadcastProgress(supabase, documentId, {
      status: "parsingOcr",
      progress: 0.35,
      stageMessage: "Extracting text, layout, and visual diagrams on server compute...",
    });

    const parser = new ServerDocumentParser(supabase);
    let parsedDoc = {
      fullText: extractedText || "",
      sections: [] as Array<{ title: string; text: string; index: number }>,
      images: [] as Array<{ url: string; label: string }>,
      isScannedOrImage: false,
    };

    if (fileBytes && fileBytes.length > 0) {
      const parsedFromFile = await parser.parseDocument({
        documentId,
        bytes: fileBytes,
        fileType,
        filename: resolvedFilename,
        contentHash,
      });
      parsedDoc.images = parsedFromFile.images;
      parsedDoc.isScannedOrImage = parsedFromFile.isScannedOrImage;
      if (parsedFromFile.fullText && parsedFromFile.fullText.length > (extractedText?.length ?? 0)) {
        parsedDoc.fullText = parsedFromFile.fullText;
        parsedDoc.sections = parsedFromFile.sections;
      }
    }

    if ((!parsedDoc.fullText || parsedDoc.fullText.trim().length === 0) && extractedText) {
      parsedDoc.fullText = extractedText;
    }

    if (parsedDoc.sections.length === 0 && parsedDoc.fullText.trim().length > 0) {
      parsedDoc.sections = parser.segmentIntoSections(parsedDoc.fullText, cleanDeckTitle);
    }

    // When the PDF is scanned/image-only, build a single image-aware section so
    // Luna receives proper visual context rather than hitting the structural fallback.
    if (
      parsedDoc.sections.length === 0 &&
      parsedDoc.isScannedOrImage &&
      parsedDoc.images.length > 0
    ) {
      const imageList = parsedDoc.images
        .map((img, i) => `- Figure ${i + 1}: ${img.label}`)
        .join("\n");
      parsedDoc.sections = [
        {
          title: cleanDeckTitle,
          text: `[Scanned/Image-Only Document — ${cleanDeckTitle}]\n\nThe following diagrams were extracted from the document:\n${imageList}\n\nSynthesize comprehensive, high-yield active-recall flashcards covering all visual, conceptual, mathematical, and factual content visible in the attached diagram(s). Reference each figure by label where appropriate.`,
          index: 1,
        },
      ];
      console.log(`[parse-stem-ocr] Scanned doc with ${parsedDoc.images.length} image(s): built image-aware section for Luna.`);
    }

    // Stage 3: OCR processing verification (55%)
    await broadcastProgress(supabase, documentId, {
      status: "parsingOcr",
      progress: 0.55,
      stageMessage: parsedDoc.isScannedOrImage
        ? "Processing visual OCR and diagram assets..."
        : `Extracted ${parsedDoc.fullText.length > 0 ? `${parsedDoc.sections.length} document sections` : "empty content"} and ${parsedDoc.images.length} diagrams...`,
    });

    // Stage 4: Semantic Mapping via Luna (75%)
    await broadcastProgress(supabase, documentId, {
      status: "generatingCards",
      progress: 0.75,
      stageMessage: "Synthesizing high-yield flashcards with Luna...",
    });

    const luna = new LunaClient();
    const generatedCards: Array<{
      id: string;
      front: string;
      back: string;
      back_latex?: string | null;
      explanation?: string | null;
      image_url?: string | null;
      tags: string[];
    }> = [];

    // Synthesize cards with Luna:
    // When text fits within optimal reasoning context (<= 45,000 chars), synthesize a cohesive
    // high-yield deck in a single unified pass with all diagrams in context.
    if (parsedDoc.fullText.trim().length > 0 && parsedDoc.fullText.length <= 45000) {
      try {
        console.log(
          `[parse-stem-ocr] Synthesizing unified deck for "${cleanDeckTitle}" (${parsedDoc.fullText.length} chars, ${parsedDoc.images.length} images) with Luna...`
        );
        const cards = await luna.generateFlashcardsFromSemanticMapping({
          content: parsedDoc.fullText,
          topic: cleanDeckTitle,
          courseCode,
          availableImages: parsedDoc.images,
          cardCountHint: Math.min(30, Math.max(12, Math.round(parsedDoc.fullText.length / 350))),
        });

        for (const c of cards) {
          generatedCards.push({
            id: crypto.randomUUID(),
            front: c.front,
            back: c.back,
            back_latex: c.latex_content,
            explanation: c.explanation || c.hints,
            image_url: c.image_url,
            tags: c.tags || [cleanDeckTitle, courseCode],
          });
        }
        console.log(`[parse-stem-ocr] Unified Luna synthesis produced ${generatedCards.length} high-yield cards.`);
      } catch (lunaErr) {
        console.error(`[parse-stem-ocr] Unified Luna generation error:`, lunaErr);
      }
    }

    // If unified pass was skipped (long doc) or yielded no cards, synthesize across sections in parallel
    if (generatedCards.length === 0 && parsedDoc.sections.length > 0) {
      console.log(`[parse-stem-ocr] Synthesizing across ${parsedDoc.sections.length} sections in parallel...`);
      const sectionPromises = parsedDoc.sections.slice(0, 8).map(async (section) => {
        try {
          return await luna.generateFlashcardsFromSemanticMapping({
            content: section.text,
            topic: section.title,
            courseCode,
            availableImages: parsedDoc.images,
          });
        } catch (secErr) {
          console.error(`[parse-stem-ocr] Section "${section.title}" Luna error:`, secErr);
          return [];
        }
      });

      const sectionResults = await Promise.all(sectionPromises);
      for (let sIdx = 0; sIdx < sectionResults.length; sIdx++) {
        const secCards = sectionResults[sIdx];
        const sec = parsedDoc.sections[sIdx];
        for (const c of secCards) {
          generatedCards.push({
            id: crypto.randomUUID(),
            front: c.front,
            back: c.back,
            back_latex: c.latex_content,
            explanation: c.explanation || c.hints,
            image_url: c.image_url,
            tags: c.tags || [sec?.title || cleanDeckTitle, courseCode],
          });
        }
      }
    }

    // Structural fallback: Luna was unreachable or returned 0 cards.
    // Generate one meaningful card per distinct paragraph block, ensuring
    // the back always has real content (never garbage glyph sequences).
    if (generatedCards.length === 0 && parsedDoc.sections.length > 0) {
      console.warn("[parse-stem-ocr] Luna returned 0 cards; generating structured fallback cards from extracted sections...");

      for (const sec of parsedDoc.sections) {
        // Skip sections that appear to be raw scanned-PDF descriptors or are too short
        const isDescriptorSection = sec.text.startsWith("[Scanned") || sec.text.startsWith("[Visual");

        // Split into substantive paragraphs (≥ 40 chars each)
        const paragraphs = sec.text
          .split(/\n\n+/)
          .map((p) => p.trim())
          .filter((p) => p.length >= 40 && !p.startsWith("["));

        if (paragraphs.length > 0 && !isDescriptorSection) {
          for (let pIdx = 0; pIdx < paragraphs.length; pIdx++) {
            const p = paragraphs[pIdx];
            // Use full lines as the back content
            const lines = p.split("\n").map((l) => l.trim()).filter((l) => l.length > 5);
            if (lines.length === 0) continue;

            // Derive a clean front question from the first non-trivial line
            const firstLine = lines[0];
            const isSentence = firstLine.includes(".") || firstLine.length > 80;
            const front = isSentence
              ? `What are the key points covered in: "${firstLine.slice(0, 70).trim()}"?`
              : firstLine.endsWith("?")
              ? firstLine
              : `Explain: ${firstLine}`;

            const back = lines.slice(0, 10).join("\n");

            generatedCards.push({
              id: crypto.randomUUID(),
              front,
              back,
              back_latex: null,
              explanation: `Extracted from: ${sec.title}`,
              image_url: parsedDoc.images[pIdx % parsedDoc.images.length]?.url ?? null,
              tags: [sec.title, cleanDeckTitle, courseCode].filter(Boolean),
            });
          }
        } else if (isDescriptorSection && parsedDoc.images.length > 0) {
          // For scanned docs with images, create one card per image
          for (let imgIdx = 0; imgIdx < parsedDoc.images.length; imgIdx++) {
            const img = parsedDoc.images[imgIdx];
            generatedCards.push({
              id: crypto.randomUUID(),
              front: `What concepts, data, or information are shown in Figure ${imgIdx + 1} of ${cleanDeckTitle}?`,
              back: `Refer to the attached diagram: ${img.label}. Review the visual content and note all key concepts, labels, axes, and relationships shown.`,
              back_latex: null,
              explanation: `Visual content from ${cleanDeckTitle}`,
              image_url: img.url,
              tags: [cleanDeckTitle, courseCode, "diagram"].filter(Boolean),
            });
          }
        }
      }
    }

    // Ultimate fallback: document had no extractable content at all.
    // Produce ONE well-formed card that instructs the user rather than showing garbage.
    if (generatedCards.length === 0) {
      const hasImages = parsedDoc.images.length > 0;
      generatedCards.push({
        id: crypto.randomUUID(),
        front: `What are the core concepts covered in ${cleanDeckTitle}?`,
        back: hasImages
          ? `This document is image-based. Review the ${parsedDoc.images.length} attached diagram(s) for the study content. Re-upload as a text-searchable PDF for richer flashcard generation.`
          : `No extractable text was found in this document. For best results, upload a text-searchable PDF. Deck title: ${cleanDeckTitle}.`,
        back_latex: null,
        explanation: hasImages ? "Visual-only document — see attached diagram(s)" : "Document had no extractable content",
        image_url: parsedDoc.images[0]?.url ?? null,
        tags: [cleanDeckTitle, courseCode].filter(Boolean),
      });
      console.warn(`[parse-stem-ocr] Ultimate fallback activated for '${cleanDeckTitle}' — document had no usable content.`);
    }

    // Stage 5: Database Persistence (90%)
    await broadcastProgress(supabase, documentId, {
      status: "syncingDb",
      progress: 0.90,
      stageMessage: `Persisting ${generatedCards.length} flashcards to library...`,
    });

    const deckId = crypto.randomUUID();
    const nowIso = new Date().toISOString();

    // Canonical Deck & Cards population for Content-Addressed Storage
    let canonicalDeckId: string | null = null;
    if (contentHash) {
      const { data: canonicalDoc } = await supabase
        .from("canonical_documents")
        .select("id")
        .eq("content_hash", contentHash)
        .maybeSingle();

      if (canonicalDoc?.id) {
        const canonicalDocId = canonicalDoc.id;

        const { data: existingCanonicalDeck } = await supabase
          .from("canonical_decks")
          .select("id")
          .eq("canonical_document_id", canonicalDocId)
          .maybeSingle();

        if (existingCanonicalDeck?.id) {
          canonicalDeckId = existingCanonicalDeck.id;
        } else {
          canonicalDeckId = crypto.randomUUID();
          await supabase.from("canonical_decks").insert({
            id: canonicalDeckId,
            canonical_document_id: canonicalDocId,
            default_title: cleanDeckTitle,
            subject: courseTitle || courseCode,
            total_cards: generatedCards.length,
            created_at: nowIso,
          });

          const canonicalCardsInserts = generatedCards.map((c, idx) => ({
            id: crypto.randomUUID(),
            canonical_deck_id: canonicalDeckId,
            order_index: idx,
            front: c.front,
            back: c.back,
            front_latex: c.front_latex || null,
            back_latex: c.back_latex || null,
            explanation: c.explanation || null,
            image_url: c.image_url || null,
            source_topic: c.tags?.[0] || "General",
            tags: c.tags || [],
            created_at: nowIso,
          }));

          if (canonicalCardsInserts.length > 0) {
            await supabase.from("canonical_cards").insert(canonicalCardsInserts);
          }
        }

        // Mark canonical document completed
        await supabase
          .from("canonical_documents")
          .update({
            processing_status: "completed",
            updated_at: nowIso,
          })
          .eq("id", canonicalDocId);

        // Broadcast to any concurrent listeners on canonical channel
        try {
          const canonicalChannel = supabase.channel(`canonical_synthesis:${canonicalDocId}`);
          await canonicalChannel.send({
            type: "broadcast",
            event: "synthesis_completed",
            payload: {
              canonicalDocId,
              deckId,
              totalCards: generatedCards.length,
              timestamp: nowIso,
            },
          });
          await supabase.removeChannel(canonicalChannel);
        } catch (_) {}
      }
    }

    // 1. Create User Deck Record in public.decks
    const deckRecord = {
      id: deckId,
      user_id: userId,
      canonical_deck_id: canonicalDeckId,
      title: cleanDeckTitle,
      subject: courseTitle || courseCode,
      category: "Academic",
      total_cards: generatedCards.length,
      due_cards: generatedCards.length,
      mastery_rate: 0.0,
      retention_rate: 0.0,
      estimated_minutes: Math.max(5, Math.ceil(generatedCards.length * 1.5)),
      course_id: courseId || null,
      course_code: courseCode || null,
      created_at: nowIso,
      updated_at: nowIso,
    };

    const { error: deckInsertErr } = await supabase
      .from("decks")
      .insert(deckRecord);

    if (deckInsertErr) {
      console.warn("[parse-stem-ocr] Deck insert notice:", deckInsertErr.message);
    }

    // 2. Insert Flashcards in public.flashcards
    const flashcardInserts = generatedCards.map((c, idx) => ({
      id: c.id,
      deck_id: deckId,
      front: c.front,
      back: c.back,
      back_latex: c.back_latex || null,
      explanation: c.explanation || null,
      image_url: c.image_url || null,
      state: "new",
      difficulty: "medium",
      next_due_date: nowIso,
      created_at: nowIso,
      updated_at: nowIso,
    }));

    if (flashcardInserts.length > 0) {
      const { error: cardsInsertErr } = await supabase
        .from("flashcards")
        .insert(flashcardInserts);

      if (cardsInsertErr) {
        console.warn("[parse-stem-ocr] Flashcards insert notice:", cardsInsertErr.message);
      }
    }

    // 3. Insert into extracted_snippets for compatibility
    const snippetInserts = generatedCards.map((c) => ({
      id: c.id,
      document_id: documentId,
      user_id: userId,
      raw_text: c.back,
      latex_content: c.back_latex || null,
      topic: c.front,
      confidence_score: 0.98,
      created_at: nowIso,
    }));

    try {
      await supabase.from("extracted_snippets").insert(snippetInserts);
    } catch (_) {}

    // 4. Update Document Status to Completed
    await supabase
      .from("documents")
      .update({
        processing_status: "completed",
        updated_at: nowIso,
      })
      .eq("id", documentId);

    // Stage 6: Completion (100%)
    await broadcastProgress(supabase, documentId, {
      status: "completed",
      progress: 1.0,
      stageMessage: `✨ Deck ready with ${generatedCards.length} cards!`,
      deckId,
    });

    const responseSnippets = generatedCards.map((c) => ({
      id: c.id,
      document_id: documentId,
      topic: c.front,
      raw_text: c.back,
      latex_content: c.back_latex || null,
      image_url: c.image_url || null,
      confidence_score: 0.98,
    }));

    return new Response(
      JSON.stringify({
        success: true,
        document_id: documentId,
        deck_id: deckId,
        deck: deckRecord,
        cards: flashcardInserts,
        snippets: responseSnippets,
        model: luna.modelName,
        images_count: parsedDoc.images.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("[parse-stem-ocr] Fatal error:", error);

    // If canonical doc exists, mark it failed to allow clean retries
    try {
      const payload: OcrRequestPayload = await req.clone().json().catch(() => ({}));
      if (payload.documentId) {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        const { data: doc } = await supabase
          .from("documents")
          .select("content_hash")
          .eq("id", payload.documentId)
          .maybeSingle();
        if (doc?.content_hash) {
          await supabase
            .from("canonical_documents")
            .update({ processing_status: "failed", updated_at: new Date().toISOString() })
            .eq("content_hash", doc.content_hash);
        }
      }
    } catch (_) {}

    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
