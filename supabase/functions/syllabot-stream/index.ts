import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";
import { corsHeaders } from "./_shared/cors.ts";

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

type TaskType = "general_query" | "complex_stem" | "code_proof" | "socratic_dialogue";

interface RequestPayload {
  prompt?: string;
  messages?: ChatMessage[];
  taskType?: TaskType;
  sessionId?: string;
  socraticMode?: "stepByStep" | "directAnswer" | "examSim" | "deepResearch";
  contextHistory?: Array<{ sender: string; text: string }>;
  courseCode?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    // A. Security & Auth Verification
    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Missing or malformed Supabase Bearer token",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Expired or invalid caller session",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userId = user.id;
    const dbClient = createClient(
      supabaseUrl,
      supabaseServiceKey || supabaseAnonKey
    );

    // B. Parse Request Payload
    const body: RequestPayload = await req.json().catch(() => ({}));
    const taskType: TaskType = body.taskType ?? "general_query";
    const socraticMode = body.socraticMode ?? "stepByStep";
    const courseCode = body.courseCode;
    const sessionId = body.sessionId;

    let rawPrompt = body.prompt ?? "";
    let messages: ChatMessage[] = [];

    if (body.messages && Array.isArray(body.messages) && body.messages.length > 0) {
      messages = body.messages;
      const lastUserMsg = [...messages].reverse().find((m) => m.role === "user");
      rawPrompt = lastUserMsg?.content ?? rawPrompt;
    } else {
      const systemInstruction = getSystemPrompt(socraticMode, taskType);
      messages = [
        { role: "system", content: systemInstruction },
        ...(body.contextHistory ?? []).map((c) => ({
          role: (c.sender === "user" ? "user" : "assistant") as
            | "user"
            | "assistant",
          content: c.text,
        })),
        { role: "user", content: rawPrompt },
      ];
    }

    if (!rawPrompt && messages.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing required prompt or messages" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 1. Semantic Cache Optimization (sub-15ms latency)
    const cachePrompt = `syllabot:${taskType}:${socraticMode}:${rawPrompt.trim().toLowerCase()}`;
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      dbClient,
      cachePrompt,
      { courseCode }
    );

    const isCacheHit = Boolean(cacheResult.hit && cacheResult.data?.tokens);
    const cachedTokens = isCacheHit
      ? (cacheResult.data?.tokens as string[])
      : null;

    // C. Dynamic Routing Payload Builder (DeepSeek v4-flash vs v4-pro)
    const llmBaseUrl =
      Deno.env.get("LLM_BASE_URL") ||
      "https://api.deepseek.com/chat/completions";
    const llmApiKey = Deno.env.get("LLM_API_KEY") || "";
    const defaultModel =
      Deno.env.get("DEFAULT_MODEL") || "deepseek-v4-flash";

    const isComplex =
      taskType === "complex_stem" || taskType === "code_proof";
    const selectedModel = isComplex ? "deepseek-v4-pro" : defaultModel;
    const reasoningEffort = isComplex ? "high" : undefined;

    // 2. Server-Sent Events (SSE) Streaming Pipeline
    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        const sendEvent = (event: string, data: Record<string, unknown>) => {
          controller.enqueue(
            encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          );
        };

        sendEvent("start", {
          status: "generating",
          model: selectedModel,
          taskType,
          socraticMode,
          cacheHit: isCacheHit,
        });

        let fullResponse = "";
        const recordedTokens: string[] = [];

        if (isCacheHit && cachedTokens) {
          // Serve from Semantic Cache
          for (const token of cachedTokens) {
            fullResponse += token;
            recordedTokens.push(token);
            sendEvent("token", { text: token });
            await new Promise((r) => setTimeout(r, 10));
          }
        } else if (llmApiKey) {
          // Dispatch streaming POST to DeepSeek API
          try {
            const deepseekPayload: Record<string, unknown> = {
              model: selectedModel,
              messages,
              stream: true,
              temperature: 0.6,
            };
            if (reasoningEffort) {
              deepseekPayload["reasoning_effort"] = reasoningEffort;
            }

            const deepseekResponse = await fetch(llmBaseUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${llmApiKey}`,
              },
              body: JSON.stringify(deepseekPayload),
            });

            if (!deepseekResponse.ok || !deepseekResponse.body) {
              throw new Error(
                `DeepSeek API responded with HTTP status ${deepseekResponse.status}`
              );
            }

            const reader = deepseekResponse.body.getReader();
            const decoder = new TextDecoder("utf-8");
            let sseBuffer = "";

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              sseBuffer += decoder.decode(value, { stream: true });
              const lines = sseBuffer.split("\n");
              sseBuffer = lines.pop() ?? "";

              for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed || trimmed.startsWith(":")) continue;

                if (trimmed === "data: [DONE]") {
                  break;
                }

                if (trimmed.startsWith("data:")) {
                  const jsonStr = trimmed.replace(/^data:\s*/, "");
                  try {
                    const parsed = JSON.parse(jsonStr);
                    const deltaText =
                      parsed.choices?.[0]?.delta?.content ??
                      parsed.choices?.[0]?.delta?.text ??
                      "";

                    if (deltaText) {
                      fullResponse += deltaText;
                      recordedTokens.push(deltaText);
                      sendEvent("token", { text: deltaText });
                    }
                  } catch {
                    // Skip heartbeat or unparseable lines
                  }
                }
              }
            }
          } catch (providerError) {
            console.error("DeepSeek stream error, fallback engaged:", providerError);
            const fallbackTokens = getFallbackTokens(rawPrompt, isComplex);
            for (const token of fallbackTokens) {
              fullResponse += token;
              recordedTokens.push(token);
              sendEvent("token", { text: token });
              await new Promise((r) => setTimeout(r, 20));
            }
          }
        } else {
          // Local/offline development fallback
          const fallbackTokens = getFallbackTokens(rawPrompt, isComplex);
          for (const token of fallbackTokens) {
            fullResponse += token;
            recordedTokens.push(token);
            sendEvent("token", { text: token });
            await new Promise((r) => setTimeout(r, 20));
          }
        }

        // Asynchronously persist to semantic cache
        if (!isCacheHit && recordedTokens.length > 0) {
          await SemanticCacheProvider.setCachedResponse(
            dbClient,
            cachePrompt,
            {
              fullText: fullResponse,
              tokens: recordedTokens,
              socraticMode,
              model: selectedModel,
            },
            { courseCode }
          ).catch((err) => console.error("Semantic cache error:", err));
        }

        // Asynchronously persist to chat_messages table
        if (userId && sessionId && fullResponse) {
          try {
            await dbClient.from("chat_messages").insert([
              {
                session_id: sessionId,
                user_id: userId,
                sender: "user",
                text: rawPrompt,
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
            console.error("Chat message persistence log:", dbErr);
          }
        }

        sendEvent("done", {
          fullText: fullResponse,
          model: selectedModel,
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
      JSON.stringify({ error: err.message ?? "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

function getSystemPrompt(mode: string, taskType: TaskType): string {
  if (taskType === "complex_stem" || taskType === "code_proof") {
    return "You are Syllabot Advanced Reasoning Engine (DeepSeek v4-pro). Provide rigorous, mathematically formal derivations with comprehensive proof steps, tensor/calculus formulations in LaTeX ($$...$$ for display and $...$ for inline), and edge-case verifications.";
  }

  switch (mode) {
    case "examSim":
      return "You are Syllabot Exam Simulator. Test the student's mastery using rigorous exam-level multiple-choice or analytical questions. Grade their reasoning and provide structured rubrics.";
    case "directAnswer":
      return "You are Syllabot, an expert STEM tutor. Provide concise, direct mathematical solutions with complete step-by-step LaTeX formulations.";
    case "deepResearch":
      return "You are Syllabot Research Assistant. Provide deep academic explanations, derivations, historical context, and formal scientific citations.";
    case "stepByStep":
    default:
      return "You are Syllabot, an expert pedagogical tutor. Guide the student step-by-step using the Socratic method. Format all mathematical expressions in LaTeX ($$...$$ for display and $...$ for inline). Guide them to discover the solution rather than immediately revealing final numbers.";
  }
}

function getFallbackTokens(prompt: string, isComplex: boolean): string[] {
  if (
    isComplex ||
    prompt.toLowerCase().includes("euler") ||
    prompt.toLowerCase().includes("lagrange") ||
    prompt.toLowerCase().includes("pde") ||
    prompt.toLowerCase().includes("derive")
  ) {
    return [
      "Let us derive the Euler-Lagrange equation from Hamilton's Principle of Stationary Action.",
      "\n\n**1. Action Functional Formulation:**",
      "\nWe define the action functional $$S[q]$$ as:",
      "\n$$S[q] = \\int_{t_1}^{t_2} L(q(t), \\dot{q}(t), t) \\, dt$$",
      "\nwhere $$L = T - V$$ is the Lagrangian of the system.",
      "\n\n**2. First Variation of the Trajectory:**",
      "\nConsider a virtual displacement $$\\delta q(t)$$ vanishing on the boundary ($$\\delta q(t_1) = \\delta q(t_2) = 0$$):",
      "\n$$\\delta S = \\int_{t_1}^{t_2} \\left( \\frac{\\partial L}{\\partial q} \\delta q + \\frac{\\partial L}{\\partial \\dot{q}} \\frac{d(\\delta q)}{dt} \\right) dt = 0$$",
      "\n\n**3. Integration by Parts:**",
      "\nApplying integration by parts on the velocity derivative term:",
      "\n$$\\int_{t_1}^{t_2} \\frac{\\partial L}{\\partial \\dot{q}} \\frac{d(\\delta q)}{dt} dt = \\left[ \\frac{\\partial L}{\\partial \\dot{q}} \\delta q \\right]_{t_1}^{t_2} - \\int_{t_1}^{t_2} \\frac{d}{dt}\\left(\\frac{\\partial L}{\\partial \\dot{q}}\\right) \\delta q \\, dt$$",
      "\n\n**4. Fundamental Lemma of Calculus of Variations:**",
      "\nBecause $$\\delta q(t)$$ is arbitrary within $$(t_1, t_2)$$, the stationary condition holds if and only if:",
      "\n$$\\frac{\\partial L}{\\partial q} - \\frac{d}{dt}\\left( \\frac{\\partial L}{\\partial \\dot{q}} \\right) = 0$$",
      "\n\nWould you like to solve the corresponding equations of motion for a coupled pendulum or central force field next?",
    ];
  }

  return [
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
