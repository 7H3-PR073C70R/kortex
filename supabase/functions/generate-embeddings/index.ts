import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";
import { getBatchEmbeddings } from "../_shared/embedding_service.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ChunkItem {
  content: string;
  chunk_index?: number;
  page_number?: number;
  paragraph_number?: number;
  metadata?: Record<string, unknown>;
}

interface EmbedRequest {
  documentId: string;
  rawText?: string;
  chunks?: ChunkItem[];
  metadata?: Record<string, unknown>;
  userId?: string;
  courseCode?: string;
}

/**
 * Memory-efficient text chunker using streaming regex word scanning.
 * Avoids allocating massive arrays of words (`text.split(/\s+/)`),
 * preventing V8 isolate memory spikes on large texts/textbooks.
 */
function chunkText(text: string, chunkSize = 500, overlap = 50): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];

  // Short-circuit for short texts (approx 6 chars per word)
  if (trimmed.length < chunkSize * 6) {
    return [trimmed];
  }

  const chunks: string[] = [];
  const wordRegex = /\S+/g;
  let wordCount = 0;
  let chunkStartIndex = 0;
  let nextChunkStartIndex = 0;
  let match: RegExpExecArray | null;

  const stepWords = Math.max(1, chunkSize - overlap);

  while ((match = wordRegex.exec(trimmed)) !== null) {
    wordCount++;

    if (wordCount === stepWords) {
      nextChunkStartIndex = match.index;
    }

    if (wordCount >= chunkSize) {
      const chunkEndIndex = wordRegex.lastIndex;
      chunks.push(trimmed.slice(chunkStartIndex, chunkEndIndex).trim());

      // Overlap: restart word counting from nextChunkStartIndex
      wordRegex.lastIndex = nextChunkStartIndex;
      chunkStartIndex = nextChunkStartIndex;
      wordCount = 0;
    }
  }

  if (chunkStartIndex < trimmed.length) {
    const remainder = trimmed.slice(chunkStartIndex).trim();
    if (remainder.length > 0) {
      chunks.push(remainder);
    }
  }

  return chunks.length > 0 ? chunks : [trimmed];
}

const SUB_BATCH_SIZE = 25;
const MAX_CHUNKS_PER_REQUEST = 100;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let effectiveUserId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "").trim();
      const isServiceRole = supabaseServiceKey && token === supabaseServiceKey;
      if (!isServiceRole) {
        const {
          data: { user },
        } = await supabase.auth.getUser(token);
        effectiveUserId = user?.id ?? null;
      }
    }

    const payload: EmbedRequest = await req.json();
    const { documentId, rawText, chunks, metadata = {}, courseCode } = payload;
    const userId = effectiveUserId || payload.userId;

    const hasChunks = Array.isArray(chunks) && chunks.length > 0;
    const hasRawText = typeof rawText === "string" && rawText.trim().length > 0;

    if (!documentId || (!hasRawText && !hasChunks)) {
      return new Response(
        JSON.stringify({ error: "documentId and either rawText or chunks are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (effectiveUserId) {
      const { data: existingDocRecord } = await supabase
        .from("documents")
        .select("id, user_id")
        .eq("id", documentId)
        .maybeSingle();

      if (existingDocRecord && existingDocRecord.user_id !== effectiveUserId) {
        return new Response(
          JSON.stringify({ error: "Forbidden: You do not own this document" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Clients send a large document as several batches of chunks, so the key
    // must identify the batch, not just its size, or every batch after the
    // first would be answered from the cache without being stored.
    const batchKey = hasChunks
      ? `${chunks![0]?.chunk_index ?? 0}-${chunks![chunks!.length - 1]?.chunk_index ?? chunks!.length - 1}:${chunks!.length}`
      : `raw:${rawText?.length ?? 0}`;
    const cacheKey = `doc_embeddings:${documentId}:${batchKey}`;
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabase,
      cacheKey,
      { courseCode }
    );

    if (cacheResult.hit && cacheResult.data) {
      const chunksCount =
        cacheResult.data.chunks_created ??
        cacheResult.data.records?.length ??
        0;

      if (chunksCount > 0) {
        return new Response(
          JSON.stringify({
            success: true,
            document_id: documentId,
            chunks_created: chunksCount,
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
    }

    let validDocumentId: string | null = null;
    const isUuid =
      documentId &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        documentId
      );

    if (isUuid) {
      const { data: existingDoc } = await supabase
        .from("documents")
        .select("id")
        .eq("id", documentId)
        .maybeSingle();

      if (existingDoc) {
        validDocumentId = existingDoc.id;
      } else if (userId) {
        const docTitle =
          (metadata.filename as string) ||
          (metadata.documentTitle as string) ||
          "Study Document";
        const { data: createdDoc } = await supabase
          .from("documents")
          .upsert(
            {
              id: documentId,
              user_id: userId,
              filename: docTitle,
              file_type: (metadata.fileType as string) || "pdf",
              file_size_bytes: (metadata.fileSizeBytes as number) || 0,
              storage_path:
                (metadata.storagePath as string) || `${documentId}.pdf`,
              content_hash:
                (metadata.contentHash as string) || `hash_${documentId}`,
              processing_status: "completed",
            },
            { onConflict: "id", ignoreDuplicates: true }
          )
          .select("id")
          .maybeSingle();

        validDocumentId = createdDoc?.id ?? documentId;
      }
    }

    // Prepare normalized chunks for processing
    type NormalizedItem = {
      content: string;
      chunk_index: number;
      page_number?: number;
      paragraph_number?: number;
      metadata?: Record<string, unknown>;
    };

    let itemsToProcess: NormalizedItem[] = [];

    if (hasChunks) {
      const validItems = chunks!.filter(
        (c) => c && typeof c.content === "string" && c.content.trim().length > 0
      );
      itemsToProcess = validItems.map((c, i) => ({
        content: c.content.trim(),
        chunk_index: c.chunk_index ?? i,
        page_number: c.page_number ?? (c.metadata?.page_number as number | undefined),
        paragraph_number:
          c.paragraph_number ?? (c.metadata?.paragraph_number as number | undefined),
        metadata: c.metadata,
      }));
    } else if (hasRawText) {
      const textChunks = chunkText(rawText!);
      itemsToProcess = textChunks.map((chunk, i) => ({
        content: chunk,
        chunk_index: i,
      }));
    }

    // One invocation embeds a bounded amount of text; a whole textbook in a
    // single request exceeds the worker's CPU and memory limits.
    if (itemsToProcess.length > MAX_CHUNKS_PER_REQUEST) {
      return new Response(
        JSON.stringify({
          error: `Too many chunks in one request (${itemsToProcess.length}). Send at most ${MAX_CHUNKS_PER_REQUEST} chunks per call.`,
          code: "PAYLOAD_TOO_LARGE",
          max_chunks: MAX_CHUNKS_PER_REQUEST,
        }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Process in sub-batches of SUB_BATCH_SIZE (25) to avoid WORKER_RESOURCE_LIMIT
    // and keep Deno V8 isolate memory usage completely flat (O(1) relative to total items).
    let totalChunksInserted = 0;

    for (let i = 0; i < itemsToProcess.length; i += SUB_BATCH_SIZE) {
      const subBatch = itemsToProcess.slice(i, i + SUB_BATCH_SIZE);
      const textList = subBatch.map((item) => item.content);
      const embeddings = await getBatchEmbeddings(textList);

      const recordsToInsert = [];
      for (let j = 0; j < subBatch.length; j++) {
        const item = subBatch[j];
        const embedding = embeddings ? embeddings[j] : null;

        recordsToInsert.push({
          document_id: validDocumentId,
          user_id: userId,
          content: item.content,
          metadata: {
            ...metadata,
            document_id: documentId,
            client_document_id: documentId,
            ...item.metadata,
            chunk_index: item.chunk_index,
            total_chunks: itemsToProcess.length,
            if_page: item.page_number,
            page_number: item.page_number,
            paragraph_number: item.paragraph_number,
            document_title: metadata.filename ?? metadata.documentTitle,
          },
          embedding: embedding ? JSON.stringify(embedding) : null,
        });
      }

      if (recordsToInsert.length > 0) {
        const { error: insertError } = await supabase
          .from("document_chunks")
          .insert(recordsToInsert);

        if (insertError) {
          console.error("[generate-embeddings] DB insert error:", insertError);
          throw insertError;
        }
        totalChunksInserted += recordsToInsert.length;
      }
    }

    // Cache lightweight metadata (count only) to avoid blowing up semantic cache table and memory
    await SemanticCacheProvider.setCachedResponse(
      supabase,
      cacheKey,
      { chunks_created: totalChunksInserted },
      { courseCode }
    );

    return new Response(
      JSON.stringify({
        success: true,
        document_id: documentId,
        chunks_created: totalChunksInserted,
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
    console.error("Error in generate-embeddings:", error);
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
