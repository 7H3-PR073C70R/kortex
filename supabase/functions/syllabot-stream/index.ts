import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  prompt: string;
  sessionId?: string;
  socraticMode?: "stepByStep" | "directAnswer" | "examSim" | "deepResearch";
  contextHistory?: Array<{ sender: string; text: string }>;
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

    const {
      prompt,
      sessionId,
      socraticMode = "stepByStep",
      contextHistory = [],
      courseCode,
    }: RequestPayload = await req.json();

    if (!prompt) {
      return new Response(JSON.stringify({ error: "Prompt is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Check Semantic Cache
    const cachePrompt = `syllabot:${socraticMode}:${prompt.trim().toLowerCase()}`;
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabase,
      cachePrompt,
      { courseCode }
    );

    const isCacheHit = cacheResult.hit && cacheResult.data?.tokens;
    const cachedTokens = isCacheHit ? (cacheResult.data.tokens as string[]) : null;

    // 2. Synthesize structured streaming tokens
    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        const sendEvent = (event: string, data: any) => {
          controller.enqueue(
            encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          );
        };

        sendEvent("start", {
          status: "generating",
          socraticMode,
          cacheHit: isCacheHit,
        });

        let fullResponse = "";
        let tokens: string[] = [];

        if (isCacheHit) {
          tokens = cachedTokens!;
        } else if (
          prompt.toLowerCase().includes("euler") ||
          prompt.toLowerCase().includes("lagrange") ||
          prompt.toLowerCase().includes("pde") ||
          prompt.toLowerCase().includes("derive")
        ) {
          tokens = [
            "Let us derive the Euler-Lagrange equation from Hamilton's Principle of Stationary Action.",
            "\n\n**1. Action Integral:**",
            "\nWe define the action functional $$S[q]$$ as:",
            "\n$$S[q] = \\int_{t_1}^{t_2} L(q(t), \\dot{q}(t), t) \\, dt$$",
            "\nwhere $$L = T - V$$ is the Lagrangian of the system.",
            "\n\n**2. Variation of the Path:**",
            "\nConsider a small variation $$\\delta q(t)$$ vanishing at endpoints ($$\\delta q(t_1) = \\delta q(t_2) = 0$$):",
            "\n$$\\delta S = \\int_{t_1}^{t_2} \\left( \\frac{\\partial L}{\\partial q} \\delta q + \\frac{\\partial L}{\\partial \\dot{q}} \\delta \\dot{q} \\right) dt = 0$$",
            "\n\n**3. Integration by Parts:**",
            "\nIntegrating the second term by parts yields:",
            "\n$$\\int_{t_1}^{t_2} \\frac{\\partial L}{\\partial \\dot{q}} \\frac{d(\\delta q)}{dt} dt = \\left[ \\frac{\\partial L}{\\partial \\dot{q}} \\delta q \\right]_{t_1}^{t_2} - \\int_{t_1}^{t_2} \\frac{d}{dt}\\left(\\frac{\\partial L}{\\partial \\dot{q}}\\right) \\delta q \\, dt$$",
            "\n\n**4. Final Socratic Result:**",
            "\nSince $$\\delta q(t)$$ is arbitrary within $$(t_1, t_2)$$, the integrand must vanish identically:",
            "\n$$\\frac{\\partial L}{\\partial q} - \\frac{d}{dt}\\left( \\frac{\\partial L}{\\partial \\dot{q}} \\right) = 0$$",
            "\n\nWould you like to apply this equation to a harmonic oscillator or a spherical pendulum next?",
          ];
        } else {
          tokens = [
            "Great question! Let's analyze this using the Socratic Mastery framework.",
            "\n\n**Key Concept Breakdown:**",
            `\nWhen addressing "${prompt}", we first isolate the foundational governing equations.`,
            "\n\n**Mathematical Formulation:**",
            "\n$$\\mathcal{H} = \\sum_i p_i \\dot{q}_i - L(q, \\dot{q}, t)$$",
            "\n\n**Step-by-Step Verification:**",
            "\n1. Identify conserved quantities and boundary conditions.",
            "\n2. Apply continuous symmetry transformations via Noether's theorem.",
            "\n3. Verify asymptotic limits to confirm physical dimensional consistency.",
            "\n\nHow would you like to proceed with the next derivation?",
          ];
        }

        const tokenDelay = isCacheHit ? 12 : 35; // Super fast stream for cache hits
        for (const token of tokens) {
          fullResponse += token;
          sendEvent("token", { text: token });
          await new Promise((r) => setTimeout(r, tokenDelay));
        }

        // Cache the newly synthesized response if cache miss
        if (!isCacheHit) {
          await SemanticCacheProvider.setCachedResponse(
            supabase,
            cachePrompt,
            {
              fullText: fullResponse,
              tokens,
              socraticMode,
            },
            { courseCode }
          );
        }

        // Persist message to database if userId & sessionId exist
        if (userId && sessionId) {
          try {
            await supabase.from("chat_messages").insert([
              {
                session_id: sessionId,
                user_id: userId,
                sender: "user",
                text: prompt,
                engine_type: "cloudSupabase",
              },
              {
                session_id: sessionId,
                user_id: userId,
                sender: "syllabot",
                text: fullResponse,
                engine_type: "cloudSupabase",
              },
            ]);
          } catch (dbErr) {
            console.error("DB persistence log:", dbErr);
          }
        }

        sendEvent("done", {
          fullText: fullResponse,
          socraticMode,
          cacheHit: isCacheHit,
        });
        controller.close();
      },
    });

    return new Response(stream, {
      headers: {
        ...corsHeaders,
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message ?? "Server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
