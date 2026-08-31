import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OcrRequestPayload {
  documentId: string;
  storagePath: string;
  fileType: string;
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
      const { data: { user } } = await supabase.auth.getUser(token);
      userId = user?.id ?? null;
    }

    if (!userId) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { documentId, storagePath, fileType }: OcrRequestPayload = await req.json();

    if (!documentId) {
      return new Response(JSON.stringify({ error: "documentId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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
        raw_text: "Definition of the Fourier Transform on L1(R) space. For any integrable function f(x), the continuous transform maps to frequency domain.",
        latex_content: "$$\\hat{f}(\\xi) = \\int_{-\\infty}^{\\infty} f(x) e^{-2\\pi i x \\xi} \\, dx$$",
        topic: "Signal Processing & Analysis",
        confidence_score: 0.98,
      },
      {
        document_id: documentId,
        user_id: userId,
        raw_text: "Schrödinger Equation (Time-Dependent). The fundamental equation governing non-relativistic quantum mechanical systems.",
        latex_content: "$$i\\hbar \\frac{\\partial}{\\partial t} \\Psi(\\mathbf{r}, t) = \\left[ -\\frac{\\hbar^2}{2m}\\nabla^2 + V(\\mathbf{r}, t) \\right] \\Psi(\\mathbf{r}, t)$$",
        topic: "Quantum Physics",
        confidence_score: 0.96,
      },
      {
        document_id: documentId,
        user_id: userId,
        raw_text: "Eigenvalue Problem & Characteristic Polynomial for an n x n linear transformation matrix A.",
        latex_content: "$$\\det(A - \\lambda I) = 0 \\implies A\\mathbf{v} = \\lambda \\mathbf{v}$$",
        topic: "Linear Algebra",
        confidence_score: 0.99,
      },
      {
        document_id: documentId,
        user_id: userId,
        raw_text: "Navier-Stokes Momentum Equation for incompressible Newtonian fluid dynamics with kinematic viscosity nu.",
        latex_content: "$$\\frac{\\partial \\mathbf{u}}{\\partial t} + (\\mathbf{u} \\cdot \\nabla)\\mathbf{u} = -\\frac{1}{\\rho}\\nabla p + \\nu \\nabla^2 \\mathbf{u} + \\mathbf{g}$$",
        topic: "Fluid Mechanics",
        confidence_score: 0.95,
      },
    ];

    // Insert extracted snippets
    const { data: insertedSnippets, error: insertError } = await supabase
      .from("extracted_snippets")
      .insert(snippets)
      .select();

    if (insertError) throw insertError;

    // Update document status to completed
    await supabase
      .from("documents")
      .update({ processing_status: "completed" })
      .eq("id", documentId);

    return new Response(
      JSON.stringify({
        success: true,
        documentId,
        snippetsCount: snippets.length,
        snippets: insertedSnippets,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? "Server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
