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
 * Initializes and subscribes to a Supabase Realtime channel once for the request lifecycle.
 */
async function initBroadcastChannel(supabase: any, documentId: string): Promise<any> {
  try {
    const channel = supabase.channel(`document_ingestion:${documentId}`);
    await new Promise<void>((resolve) => {
      const timer = setTimeout(() => resolve(), 1200);
      channel.subscribe((status: string) => {
        if (status === "SUBSCRIBED" || status === "TIMED_OUT" || status === "CHANNEL_ERROR") {
          clearTimeout(timer);
          resolve();
        }
      });
    });
    return channel;
  } catch (err) {
    console.warn("[parse-stem-ocr] Failed to subscribe broadcast channel:", err);
    return null;
  }
}

/**
 * Broadcasts progress updates to client via Supabase Realtime channel.
 */
async function broadcastProgress(
  channel: any,
  documentId: string,
  data: {
    status: string;
    progress: number;
    stageMessage: string;
    deckId?: string;
    error?: string;
  }
) {
  if (!channel) return;
  try {
    await channel.send({
      type: "broadcast",
      event: "ingestion_progress",
      payload: {
        documentId,
        ...data,
        timestamp: new Date().toISOString(),
      },
    });
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

    const broadcastChannel = await initBroadcastChannel(supabase, documentId);

    try {
      await broadcastProgress(broadcastChannel, documentId, {
        status: "parsingOcr",
        progress: 0.20,
        stageMessage: "Loading document on server compute...",
      });

      await supabase
        .from("documents")
        .update({ processing_status: "parsingOcr" })
        .eq("id", documentId);

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

      await broadcastProgress(broadcastChannel, documentId, {
        status: "parsingOcr",
        progress: 0.40,
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
      if (parsedFromFile.fullText && !parsedFromFile.fullText.startsWith("[Scanned") && parsedFromFile.fullText.length > (extractedText?.length ?? 0)) {
        parsedDoc.fullText = parsedFromFile.fullText;
        parsedDoc.sections = parsedFromFile.sections;
      }
    }

    const hasClientText = Boolean(extractedText && extractedText.trim().length > 0);
    if (hasClientText && (!parsedDoc.fullText || parsedDoc.fullText.trim().length === 0 || extractedText!.length >= parsedDoc.fullText.length)) {
      parsedDoc.fullText = extractedText!;
      parsedDoc.sections = parser.segmentIntoSections(parsedDoc.fullText, cleanDeckTitle);
    }

    if (parsedDoc.sections.length === 0 && parsedDoc.fullText.trim().length > 0 && !parsedDoc.fullText.startsWith("[Scanned")) {
      parsedDoc.sections = parser.segmentIntoSections(parsedDoc.fullText, cleanDeckTitle);
    }

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

    await broadcastProgress(broadcastChannel, documentId, {
      status: "parsingOcr",
      progress: 0.60,
      stageMessage: parsedDoc.isScannedOrImage
        ? "Processing visual OCR and diagram assets..."
        : `Extracted ${parsedDoc.fullText.length > 0 ? `${parsedDoc.sections.length} document sections` : "empty content"} and ${parsedDoc.images.length} diagrams...`,
    });

    await broadcastProgress(broadcastChannel, documentId, {
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

    const textForSynthesis =
      parsedDoc.fullText.trim().length > 0 && !parsedDoc.fullText.startsWith("[Scanned")
        ? (parsedDoc.fullText.length > 45000
            ? parsedDoc.fullText.slice(0, 45000)
            : parsedDoc.fullText)
        : "";

    if (textForSynthesis.length > 0) {
      try {
        console.log(
          `[parse-stem-ocr] Synthesizing unified deck for "${cleanDeckTitle}" (${textForSynthesis.length} chars, ${parsedDoc.images.length} images) with Luna...`
        );
        const cards = await luna.generateFlashcardsFromSemanticMapping({
          content: textForSynthesis,
          topic: cleanDeckTitle,
          courseCode,
          availableImages: parsedDoc.images,
          cardCountHint: Math.min(30, Math.max(12, Math.round(textForSynthesis.length / 350))),
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

    if (generatedCards.length === 0 && parsedDoc.sections.length > 0) {
      console.log(`[parse-stem-ocr] Synthesizing across key sections without blowing rate limits...`);
      const topSections = parsedDoc.sections.slice(0, 3);
      for (const section of topSections) {
        try {
          const secCards = await luna.generateFlashcardsFromSemanticMapping({
            content: section.text,
            topic: section.title,
            courseCode,
            availableImages: parsedDoc.images,
            cardCountHint: 6,
          });
          for (const c of secCards) {
            generatedCards.push({
              id: crypto.randomUUID(),
              front: c.front,
              back: c.back,
              back_latex: c.latex_content,
              explanation: c.explanation || c.hints,
              image_url: c.image_url,
              tags: c.tags || [section.title || cleanDeckTitle, courseCode],
            });
          }
          if (generatedCards.length >= 15) break;
        } catch (secErr) {
          console.error(`[parse-stem-ocr] Section "${section.title}" Luna error:`, secErr);
        }
      }
    }

    if (generatedCards.length === 0 && parsedDoc.sections.length > 0) {
      console.warn("[parse-stem-ocr] Luna returned 0 cards; generating structured fallback cards from extracted sections...");

      for (const sec of parsedDoc.sections) {
        const isDescriptorSection = sec.text.startsWith("[Scanned") || sec.text.startsWith("[Visual");

        const items = sec.text
          .split(/\n+/)
          .map((p) => p.trim())
          .filter((p) => p.length >= 10 && !p.startsWith("["));

        if (items.length > 0 && !isDescriptorSection) {
          for (let pIdx = 0; pIdx < Math.min(25, items.length); pIdx++) {
            const item = items[pIdx];
            const isSentence = item.includes(".") || item.length > 60;
            const front = isSentence
              ? `What are the key concepts covered in: "${item.slice(0, 70).trim()}"?`
              : item.endsWith("?")
              ? item
              : `Explain: ${item}`;

            const back = item;
            const hasDiagramRef = /\b(?:figure|fig\.?|diagram|chart|illustration|schematic|flowchart|table)\b/i.test(`${sec.title} ${item}`);
            const matchedImageUrl = hasDiagramRef
              ? (parsedDoc.images[pIdx % parsedDoc.images.length]?.url ?? null)
              : null;

            generatedCards.push({
              id: crypto.randomUUID(),
              front,
              back,
              back_latex: null,
              explanation: `Extracted from: ${sec.title}`,
              image_url: matchedImageUrl,
              tags: [sec.title, cleanDeckTitle, courseCode].filter(Boolean),
            });
          }
        } else if (isDescriptorSection && parsedDoc.images.length > 0) {
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

    // Ultimate Safety Net: If generatedCards is STILL empty, build fallback study cards from deckTitle and filename
    if (generatedCards.length === 0) {
      const summaryText = parsedDoc.fullText.trim().length > 0
        ? parsedDoc.fullText.trim().slice(0, 500)
        : `Study material for ${cleanDeckTitle}`;

      generatedCards.push({
        id: crypto.randomUUID(),
        front: `What are the primary study topics and objectives covered in ${cleanDeckTitle}?`,
        back: summaryText,
        back_latex: null,
        explanation: `Key study guide for ${cleanDeckTitle}`,
        image_url: parsedDoc.images[0]?.url ?? null,
        tags: [cleanDeckTitle, courseCode].filter(Boolean),
      });
    }

    await broadcastProgress(broadcastChannel, documentId, {
      status: "syncingDb",
      progress: 0.90,
      stageMessage: `Persisting ${generatedCards.length} flashcards to library...`,
    });

    const deckId = crypto.randomUUID();
    const nowIso = new Date().toISOString();

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

        await supabase
          .from("canonical_documents")
          .update({
            processing_status: "completed",
            updated_at: nowIso,
          })
          .eq("id", canonicalDocId);

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

    await supabase
      .from("documents")
      .update({
        processing_status: "completed",
        updated_at: nowIso,
      })
      .eq("id", documentId);

    await broadcastProgress(broadcastChannel, documentId, {
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
    } finally {
      if (broadcastChannel) {
        try {
          await supabase.removeChannel(broadcastChannel);
        } catch (_) {}
      }
    }
  } catch (error: any) {
    console.error("[parse-stem-ocr] Fatal error:", error);

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
