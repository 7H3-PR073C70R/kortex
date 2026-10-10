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
      if (
        parsedFromFile.fullText &&
        !parsedFromFile.fullText.startsWith("[Scanned") &&
        !parsedFromFile.fullText.startsWith("[Visual") &&
        parsedFromFile.fullText.length > (extractedText?.length ?? 0)
      ) {
        parsedDoc.fullText = parsedFromFile.fullText;
        parsedDoc.sections = parsedFromFile.sections;
      }
    }

    const hasClientText = Boolean(extractedText && extractedText.trim().length > 0);
    if (hasClientText && (!parsedDoc.fullText || parsedDoc.fullText.trim().length === 0 || extractedText!.length >= parsedDoc.fullText.length)) {
      parsedDoc.fullText = extractedText!;
      parsedDoc.sections = parser.segmentIntoSections(parsedDoc.fullText, cleanDeckTitle);
    }

    if (parsedDoc.sections.length === 0 && parsedDoc.fullText.trim().length > 0 && !parsedDoc.fullText.startsWith("[Scanned") && !parsedDoc.fullText.startsWith("[Visual")) {
      parsedDoc.sections = parser.segmentIntoSections(parsedDoc.fullText, cleanDeckTitle);
    }

    if (
      (parsedDoc.sections.length === 0 || parsedDoc.fullText.startsWith("[Visual") || parsedDoc.fullText.startsWith("[Scanned")) &&
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

    // Group document sections into logical chunks (~6,000 characters per chunk)
    // to ensure fast AI response times (< 4 seconds per chunk) well within timeout limits
    const sectionChunks: Array<{ title: string; content: string }> = [];
    if (parsedDoc.sections.length > 0) {
      let currentTitle = parsedDoc.sections[0].title || cleanDeckTitle;
      let currentText = "";
      for (const sec of parsedDoc.sections) {
        if (currentText.length + sec.text.length > 6000 && currentText.length > 0) {
          sectionChunks.push({ title: currentTitle, content: currentText });
          currentTitle = sec.title || cleanDeckTitle;
          currentText = sec.text;
        } else {
          currentText = currentText ? `${currentText}\n\n${sec.text}` : sec.text;
        }
      }
      if (currentText.trim().length > 0) {
        sectionChunks.push({ title: currentTitle, content: currentText });
      }
    } else if (parsedDoc.fullText.trim().length > 0 && !parsedDoc.fullText.startsWith("[Scanned")) {
      const fullStr = parsedDoc.fullText.trim();
      for (let offset = 0; offset < fullStr.length; offset += 6000) {
        sectionChunks.push({
          title: `${cleanDeckTitle} (Part ${Math.floor(offset / 6000) + 1})`,
          content: fullStr.slice(offset, offset + 6000),
        });
      }
    }

    if (sectionChunks.length > 0) {
      console.log(`[parse-stem-ocr] Found ${sectionChunks.length} section chunks across document "${cleanDeckTitle}"...`);
      const MAX_CHUNKS = 15;
      let chunksToProcess: Array<{ title: string; content: string }>;

      if (sectionChunks.length <= MAX_CHUNKS) {
        chunksToProcess = sectionChunks;
      } else {
        const step = sectionChunks.length / MAX_CHUNKS;
        chunksToProcess = [];
        for (let i = 0; i < MAX_CHUNKS; i++) {
          const idx = Math.floor(i * step);
          chunksToProcess.push(sectionChunks[idx]);
        }
      }

      const seenPrompts = new Set<string>();

      for (let i = 0; i < chunksToProcess.length; i++) {
        if (generatedCards.length >= 150) break; // High-yield upper limit to prevent memory bloat/duplicate flood

        const chunk = chunksToProcess[i];
        try {
          const targetCards = Math.max(5, Math.min(12, Math.round(chunk.content.length / 600)));
          const cards = await luna.generateFlashcardsFromSemanticMapping({
            content: chunk.content,
            topic: chunk.title,
            courseCode,
            availableImages: parsedDoc.images,
            cardCountHint: targetCards,
          });

          for (const c of cards) {
            const normPrompt = c.front.toLowerCase().replace(/[^a-z0-9]/g, "");
            if (normPrompt.length > 5 && seenPrompts.has(normPrompt)) continue;
            if (normPrompt.length > 5) seenPrompts.add(normPrompt);

            generatedCards.push({
              id: crypto.randomUUID(),
              front: c.front,
              back: c.back,
              back_latex: c.latex_content,
              explanation: c.explanation || c.hints,
              image_url: c.image_url,
              tags: c.tags || [chunk.title, cleanDeckTitle, courseCode].filter(Boolean),
            });

            if (generatedCards.length >= 150) break;
          }
        } catch (lunaErr) {
          console.error(`[parse-stem-ocr] Chunk ${i + 1} Luna error:`, lunaErr);
        }
      }
      console.log(`[parse-stem-ocr] Multi-chunk synthesis produced ${generatedCards.length} high-yield cards spanning full document.`);
    }

    if (generatedCards.length === 0 && parsedDoc.sections.length > 0) {
      console.warn("[parse-stem-ocr] Luna returned 0 cards; generating structured fallback cards from extracted sections...");

      for (const sec of parsedDoc.sections) {
        const isDescriptorSection = sec.text.startsWith("[Scanned") || sec.text.startsWith("[Visual");

        const items = sec.text
          .split(/\n+/)
          .map((p) => p.replace(/\b(?:Practice Next step|Next step|Practice|JetBrains Academy)\b/gi, "").trim())
          .filter((p) => {
            const lower = p.toLowerCase();
            return (
              p.length >= 15 &&
              !p.startsWith("[") &&
              lower !== "intermediate" &&
              lower !== "objects" &&
              lower !== "properties" &&
              lower !== "basics" &&
              lower !== "overview" &&
              !lower.includes("practice next step")
            );
          });

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

    const nowIso = new Date().toISOString();

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

    if (snippetInserts.length > 0) {
      try {
        await supabase.from("extracted_snippets").insert(snippetInserts);
      } catch (_) {}
    }

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
      stageMessage: `✨ Extracted ${generatedCards.length} cards from document!`,
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
