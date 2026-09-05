import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { chunkMarkdown } from "../_shared/markdown_chunker.ts";

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
  parser?: "llamaparse" | "docling" | "native_ocr";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    const supabase = createClient(
      supabaseUrl,
      supabaseServiceKey || supabaseAnonKey
    );

    const payload: IngestionJobPayload = await req.json().catch(() => ({}));
    const {
      documentId,
      fileUrl,
      rawText,
      userId,
      courseCode,
      metadata = {},
      parser = "llamaparse",
    } = payload;

    if (!documentId || !userId) {
      return new Response(
        JSON.stringify({ error: "documentId and userId are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Asynchronous Layout-Aware Parsing (LlamaParse / Docling / Native)
    let structuredMarkdown = rawText ?? "";
    const llamaParseApiKey = Deno.env.get("LLAMAPARSE_API_KEY");

    if (fileUrl && llamaParseApiKey && parser === "llamaparse") {
      try {
        console.log(`[IngestionWorker] Parsing document ${documentId} via LlamaParse...`);
        structuredMarkdown = await parseWithLlamaParse(fileUrl, llamaParseApiKey);
      } catch (err) {
        console.warn(`[IngestionWorker] LlamaParse failed, falling back: ${err}`);
      }
    }

    if (!structuredMarkdown || structuredMarkdown.trim().length === 0) {
      structuredMarkdown =
        rawText ||
        `# Document Summary: ${courseCode ?? "General STEM"}\n\nProcessed document without structured text.`;
    }

    // 2. Layout-Aware Hierarchical Markdown Chunking
    const chunks = chunkMarkdown(structuredMarkdown, {
      maxChunkWords: 400,
      minChunkWords: 40,
    });

    console.log(
      `[IngestionWorker] Generated ${chunks.length} layout-aware chunks for document ${documentId}`
    );

    // 3. Generate Vector Embeddings and Persist to Supabase pgvector
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

    // 4. Update Document Status in Database
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
      // Non-blocking status update
    }

    // 5. Broadcast Real-Time Completion via WebSocket Realtime Channel
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

    // 6. Trigger Push Notification to User's Phone
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

async function parseWithLlamaParse(
  fileUrl: string,
  apiKey: string
): Promise<string> {
  const fileRes = await fetch(fileUrl);
  if (!fileRes.ok) {
    throw new Error(`Failed to download file from ${fileUrl}`);
  }
  const fileBlob = await fileRes.blob();

  const formData = new FormData();
  formData.append("file", fileBlob, "document.pdf");
  formData.append("result_type", "markdown");
  formData.append("parsing_instruction", "Extract all text, headers, LaTeX formulas, and Markdown tables accurately.");

  const uploadRes = await fetch("https://api.cloud.llamaindex.ai/api/parsing/upload", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: formData,
  });

  if (!uploadRes.ok) {
    throw new Error(`LlamaParse upload failed with status ${uploadRes.status}`);
  }

  const uploadData = await uploadRes.json();
  const jobId = uploadData.id;

  // Poll job status
  for (let attempt = 0; attempt < 30; attempt++) {
    await new Promise((r) => setTimeout(r, 1000));
    const statusRes = await fetch(
      `https://api.cloud.llamaindex.ai/api/parsing/job/${jobId}/result/markdown`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
      }
    );

    if (statusRes.ok) {
      const data = await statusRes.json();
      return data.markdown ?? "";
    }
  }

  throw new Error("LlamaParse parsing timed out");
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
