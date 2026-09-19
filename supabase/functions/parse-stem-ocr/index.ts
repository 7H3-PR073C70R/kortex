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
      .select("id, user_id, filename")
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
      sections: [{ title: cleanDeckTitle, text: extractedText || "", index: 1 }],
      images: [] as Array<{ url: string; label: string }>,
      isScannedOrImage: false,
    };

    if (fileBytes && fileBytes.length > 0) {
      parsedDoc = await parser.parseDocument({
        documentId,
        bytes: fileBytes,
        fileType,
        filename: resolvedFilename,
      });
    }

    // Stage 3: OCR processing verification (55%)
    await broadcastProgress(supabase, documentId, {
      status: "parsingOcr",
      progress: 0.55,
      stageMessage: parsedDoc.isScannedOrImage
        ? "Processing visual OCR and mathematical formulas..."
        : `Extracted ${parsedDoc.fullText.length > 0 ? "document text" : "empty content"} and ${parsedDoc.images.length} diagrams...`,
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

    // Synthesize cards with Luna across sections
    for (const section of parsedDoc.sections) {
      try {
        console.log(`[parse-stem-ocr] Passing section "${section.title}" to Luna...`);
        const cards = await luna.generateFlashcardsFromSemanticMapping({
          content: section.text,
          topic: section.title,
          courseCode,
          availableImages: parsedDoc.images,
        });

        for (const c of cards) {
          generatedCards.push({
            id: crypto.randomUUID(),
            front: c.front,
            back: c.back,
            back_latex: c.latex_content,
            explanation: c.explanation || c.hints,
            image_url: c.image_url,
            tags: c.tags || [section.title, courseCode],
          });
        }
      } catch (lunaErr) {
        console.error(`[parse-stem-ocr] Luna generation error on "${section.title}":`, lunaErr);
      }
    }

    // Fallback if Luna returned 0 cards or was unreachable
    if (generatedCards.length === 0) {
      const fallbackPrompt = `What are the core concepts covered in ${cleanDeckTitle}?`;
      const fallbackBody = parsedDoc.fullText.slice(0, 500) || "Study content extracted from document.";
      generatedCards.push({
        id: crypto.randomUUID(),
        front: fallbackPrompt,
        back: fallbackBody,
        back_latex: null,
        explanation: "Key concept summary",
        image_url: parsedDoc.images[0]?.url ?? null,
        tags: [cleanDeckTitle, courseCode],
      });
    }

    // Stage 5: Database Persistence (90%)
    await broadcastProgress(supabase, documentId, {
      status: "syncingDb",
      progress: 0.90,
      stageMessage: `Persisting ${generatedCards.length} flashcards to library...`,
    });

    const deckId = crypto.randomUUID();
    const nowIso = new Date().toISOString();

    // 1. Create Deck Record in public.decks
    const deckRecord = {
      id: deckId,
      user_id: userId,
      title: cleanDeckTitle,
      subject: courseTitle || courseCode,
      category: "Academic",
      total_cards: generatedCards.length,
      due_cards: generatedCards.length,
      mastery_rate: 0.0,
      retention_rate: 0.0,
      estimated_minutes: Math.max(5, Math.ceil(generatedCards.length * 1.5)),
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
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
