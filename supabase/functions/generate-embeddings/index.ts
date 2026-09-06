import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

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

function chunkText(text: string, chunkSize = 500, overlap = 50): string[] {
  const words = text.split(/\s+/);
  const chunks: string[] = [];

  if (words.length <= chunkSize) {
    return [text];
  }

  let start = 0;
  while (start < words.length) {
    const end = Math.min(start + chunkSize, words.length);
    const chunk = words.slice(start, end).join(" ");
    chunks.push(chunk);
    if (end === words.length) break;
    start += chunkSize - overlap;
  }

  return chunks;
}

function generateDeterministicVector(text: string, dim = 1536): number[] {
  const vector = new Array(dim).fill(0);
  for (let i = 0; i < text.length; i++) {
    const charCode = text.charCodeAt(i);
    const index = (charCode * (i + 1)) % dim;
    vector[index] = (vector[index] + charCode / 255.0) / 2.0;
  }
  const magnitude =
    Math.sqrt(vector.reduce((acc, val) => acc + val * val, 0)) || 1;
  return vector.map((v) => v / magnitude);
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

    let effectiveUserId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const {
        data: { user },
      } = await supabase.auth.getUser(token);
      effectiveUserId = user?.id ?? null;
    }

    const payload: EmbedRequest = await req.json();
    const { documentId, rawText, chunks, metadata = {}, courseCode } = payload;
    const userId = payload.userId || effectiveUserId;

    if (!documentId || (!rawText && (!chunks || chunks.length === 0))) {
      return new Response(
        JSON.stringify({ error: "documentId and either rawText or chunks are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const cacheKey = `doc_embeddings:${documentId}:${rawText?.length ?? chunks?.length ?? 0}`;
    // 1. Check Semantic Cache for pre-computed document embeddings
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabase,
      cacheKey,
      { courseCode }
    );

    if (cacheResult.hit && cacheResult.data?.records) {
      return new Response(
        JSON.stringify({
          success: true,
          document_id: documentId,
          chunks_created: cacheResult.data.records.length,
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

    const recordsToInsert = [];

    if (chunks && chunks.length > 0) {
      for (let i = 0; i < chunks.length; i++) {
        const item = chunks[i];
        const content = item.content.trim();
        if (!content) continue;
        const embedding = generateDeterministicVector(content, 1536);

        recordsToInsert.push({
          document_id: documentId,
          user_id: userId,
          content,
          metadata: {
            ...metadata,
            ...item.metadata,
            chunk_index: item.chunk_index ?? i,
            total_chunks: chunks.length,
            if_page: item.page_number,
            page_number: item.page_number ?? item.metadata?.page_number,
            paragraph_number: item.paragraph_number ?? item.metadata?.paragraph_number,
            document_title: metadata.filename ?? metadata.documentTitle,
          },
          embedding: JSON.stringify(embedding),
        });
      }
    } else if (rawText) {
      const textChunks = chunkText(rawText);
      for (let i = 0; i < textChunks.length; i++) {
        const chunk = textChunks[i];
        const embedding = generateDeterministicVector(chunk, 1536);

        recordsToInsert.push({
          document_id: documentId,
          user_id: userId,
          content: chunk,
          metadata: {
            ...metadata,
            chunk_index: i,
            total_chunks: textChunks.length,
            document_title: metadata.filename ?? metadata.documentTitle,
          },
          embedding: JSON.stringify(embedding),
        });
      }
    }

    if (recordsToInsert.length > 0) {
      const { error: insertError } = await supabase
        .from("document_chunks")
        .insert(recordsToInsert);

      if (insertError) {
        throw insertError;
      }
    }

    // Cache precomputed embedding records
    await SemanticCacheProvider.setCachedResponse(
      supabase,
      `doc_embeddings:${documentId}:${rawText.length}`,
      { records: recordsToInsert },
      { courseCode }
    );

    return new Response(
      JSON.stringify({
        success: true,
        document_id: documentId,
        chunks_created: recordsToInsert.length,
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
