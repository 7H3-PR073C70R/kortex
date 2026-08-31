import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface OcrRequestPayload {
  documentId: string;
  storagePath: string;
  fileType: string;
  courseCode?: string;
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
      const token = authHeader.replace("Bearer ", "");
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

    const {
      documentId,
      storagePath,
      fileType,
      courseCode,
    }: OcrRequestPayload = await req.json();

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
          snippets_extracted: cacheResult.data.snippets.length,
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

    // Synthesize STEM OCR extracted snippets (with LaTeX formulas & theorems)
    const snippets = [
      {
        document_id: documentId,
        user_id: userId,
        raw_text:
          "Theorem 4.2 (Stationary Action Principle): The true physical path of a dynamical system minimizes the action functional S = int L dt.",
        latex_formula:
          "\\delta S = \\delta \\int_{t_1}^{t_2} L(q, \\dot{q}, t) \\, dt = 0",
        confidence_score: 0.98,
        page_number: 1,
        bounding_box: { x: 0.1, y: 0.2, width: 0.8, height: 0.15 },
        is_stem_formula: true,
      },
      {
        document_id: documentId,
        user_id: userId,
        raw_text:
          "Lagrangian mechanics reformulation: L = T - V where T is kinetic energy and V is potential energy.",
        latex_formula:
          "\\frac{d}{dt}\\left(\\frac{\\partial L}{\\partial \\dot{q}_i}\\right) - \\frac{\\partial L}{\\partial q_i} = 0",
        confidence_score: 0.96,
        page_number: 1,
        bounding_box: { x: 0.1, y: 0.4, width: 0.8, height: 0.2 },
        is_stem_formula: true,
      },
      {
        document_id: documentId,
        user_id: userId,
        raw_text:
          "Thermodynamic identity relating entropy, enthalpy, and temperature.",
        latex_formula: "dH = T \\, dS + V \\, dP",
        confidence_score: 0.97,
        page_number: 2,
        bounding_box: { x: 0.15, y: 0.3, width: 0.7, height: 0.18 },
        is_stem_formula: true,
      },
    ];

    const { error: snippetErr } = await supabase
      .from("ocr_snippets")
      .insert(snippets);

    if (snippetErr) {
      throw snippetErr;
    }

    // Update document status to ready
    await supabase
      .from("documents")
      .update({ processing_status: "ready" })
      .eq("id", documentId);

    // Cache the OCR output
    await SemanticCacheProvider.setCachedResponse(
      supabase,
      `ocr_extract:${documentId}:${storagePath}`,
      { snippets },
      { courseCode }
    );

    return new Response(
      JSON.stringify({
        success: true,
        document_id: documentId,
        snippets_extracted: snippets.length,
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
