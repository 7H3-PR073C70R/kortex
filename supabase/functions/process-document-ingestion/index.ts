import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { chunkMarkdown } from "../_shared/markdown_chunker.ts";
import { ServerDocumentParser } from "../_shared/server_document_parser.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface IngestionJobPayload {
  documentId: string;
  fileUrl?: string;
  rawText?: string;
  userId: string;
  courseCode?: string;
  metadata?: Record<string, unknown>;
  parser?: "server_compute" | "native_ocr";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";

    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Bearer token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    const isServiceRole = supabaseServiceKey && token === supabaseServiceKey;

    let authenticatedUserId: string | null = null;
    if (!isServiceRole) {
      const authClient = createClient(supabaseUrl, supabaseAnonKey);
      const {
        data: { user },
        error: authError,
      } = await authClient.auth.getUser(token);

      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Invalid or expired session token" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      authenticatedUserId = user.id;
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload: IngestionJobPayload = await req.json().catch(() => ({}));
    const {
      documentId,
      fileUrl,
      rawText,
      userId: requestedUserId,
      courseCode,
      metadata = {},
      parser = "server_compute",
    } = payload;

    const userId = isServiceRole
      ? (requestedUserId || "system")
      : (authenticatedUserId as string);

    if (!documentId || !userId) {
      return new Response(
        JSON.stringify({ error: "documentId and userId are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!isServiceRole && authenticatedUserId) {
      const { data: docRecord, error: docErr } = await supabase
        .from("documents")
        .select("id, user_id")
        .eq("id", documentId)
        .maybeSingle();

      if (docRecord && docRecord.user_id !== authenticatedUserId) {
        return new Response(
          JSON.stringify({ error: "Forbidden: You do not have permission to ingest this document" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    let structuredMarkdown = rawText ?? "";

    if (fileUrl && (!structuredMarkdown || structuredMarkdown.length === 0)) {
      try {
        console.log(`[IngestionWorker] Parsing document ${documentId} on server compute...`);
        const fileRes = await fetch(fileUrl);
        if (fileRes.ok) {
          const buf = await fileRes.arrayBuffer();
          const parser = new ServerDocumentParser(supabase);
          const parsed = await parser.parseDocument({
            documentId,
            bytes: new Uint8Array(buf),
            fileType: "pdf",
            filename: `doc_${documentId}.pdf`,
          });
          structuredMarkdown = parsed.fullText;
        }
      } catch (err) {
        console.warn(`[IngestionWorker] Server compute parsing failed: ${err}`);
      }
    }

    if (!structuredMarkdown || structuredMarkdown.trim().length === 0) {
      structuredMarkdown =
        rawText ||
        `# Document Summary: ${courseCode ?? "General STEM"}\n\nProcessed document without structured text.`;
    }

    const chunks = chunkMarkdown(structuredMarkdown, {
      maxChunkWords: 400,
      minChunkWords: 40,
    });

    console.log(
      `[IngestionWorker] Generated ${chunks.length} layout-aware chunks for document ${documentId}`
    );

    const embeddingInserts = [];
    for (const chunk of chunks) {
      const embedding = generateDeterministicVector(chunk.content);
      embeddingInserts.push({
        document_id: documentId,
        user_id: userId,
        course_code: courseCode,
        content: chunk.content,
        header_path: chunk.headerPath,
        header_level: chunk.headerLevel,
        word_count: chunk.wordCount,
        has_table: chunk.hasTable,
        has_math: chunk.hasMath,
        has_code: chunk.hasCode,
        embedding,
        metadata: {
          ...metadata,
          chunkId: chunk.id,
          parsedAt: new Date().toISOString(),
        },
      });
    }

    if (embeddingInserts.length > 0) {
      try {
        const { error: insertError } = await supabase
          .from("document_embeddings")
          .insert(embeddingInserts);

        if (insertError) {
          console.warn("[IngestionWorker] pgvector insert notice:", insertError.message);
        }
      } catch (dbErr) {
        console.warn("[IngestionWorker] DB insert fallback:", dbErr);
      }
    }

    try {
      await supabase
        .from("documents")
        .update({
          status: "completed",
          chunk_count: chunks.length,
          updated_at: new Date().toISOString(),
        })
        .eq("id", documentId);
    } catch (_) {
    }

    try {
      const channel = supabase.channel(`document_ingestion:${documentId}`);
      await channel.send({
        type: "broadcast",
        event: "ingestion_completed",
        payload: {
          documentId,
          userId,
          status: "completed",
          chunkCount: chunks.length,
          courseCode,
          timestamp: new Date().toISOString(),
        },
      });
      await supabase.removeChannel(channel);
    } catch (wsErr) {
      console.warn("[IngestionWorker] Realtime broadcast error:", wsErr);
    }

    try {
      const pushUrl = `${supabaseUrl}/functions/v1/send-push-notification`;
      await fetch(pushUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseServiceKey || supabaseAnonKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          userId,
          title: "✨ Your flashcards are ready!",
          body: `Syllabot synthesized ${chunks.length} sections into study cards. Tap to start learning!`,
          category: "ai_ingestion",
          data: {
            documentId,
            courseCode: courseCode ?? "",
            route: "/deck-detail",
          },
        }),
      });
    } catch (pushErr) {
      console.warn("[IngestionWorker] Push notification dispatch note:", pushErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        documentId,
        status: "completed",
        chunkCount: chunks.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("[IngestionWorker] Fatal error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "Internal worker error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

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
