import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface EmbedRequest {
  documentId: string;
  rawText: string;
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
    const { documentId, rawText, metadata = {}, courseCode } = payload;
    const userId = payload.userId || effectiveUserId;

    if (!documentId || !rawText) {
      return new Response(
        JSON.stringify({ error: "documentId and rawText are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Check Semantic Cache for pre-computed document embeddings
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabase,
      `doc_embeddings:${documentId}:${rawText.length}`,
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

    const textChunks = chunkText(rawText);
    const recordsToInsert = [];

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
        },
        embedding: JSON.stringify(embedding),
      });
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
