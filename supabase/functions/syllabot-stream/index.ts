import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";
import { LunaClient } from "../_shared/luna_client.ts";
import { corsHeaders } from "./_shared/cors.ts";
import {
  Message,
  selectModelAndParams,
} from "./_shared/router.ts";

interface RequestPayload {
  prompt?: string;
  messages?: Message[];
  forceModel?: string;
  taskType?: string;
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

    let userId = "anon-guest";
    if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
      const token = authHeader.replace(/^Bearer\s+/i, "").trim();
      if (token === supabaseAnonKey || token === supabaseServiceKey) {
        userId = "anon-guest";
      } else {
        const authClient = createClient(supabaseUrl, supabaseAnonKey);
        const {
          data: { user },
        } = await authClient.auth.getUser(token).catch(() => ({ data: { user: null } }));
        if (user) {
          userId = user.id;
        }
      }
    }

    const dbClient = createClient(
      supabaseUrl,
      supabaseServiceKey || supabaseAnonKey
    );

    const body: RequestPayload = await req.json().catch(() => ({}));
    const socraticMode = body.socraticMode ?? "stepByStep";
    const courseCode = body.courseCode;
    const sessionId = body.sessionId;

    const { messages, rawPrompt } = buildMessages(body, socraticMode, courseCode);

    if (!rawPrompt && (!messages || messages.length === 0)) {
      return new Response(
        JSON.stringify({ error: "Missing required prompt or messages" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const routing = selectModelAndParams(messages, {
      forceModel: body.forceModel,
    });
    const selectedModel = routing.model;
    const reasoningEffort = routing.reasoning_effort;

    const cachePrompt = buildCacheKey(selectedModel, socraticMode, messages);
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      dbClient,
      cachePrompt,
      { courseCode }
    );

    const isCacheHit = Boolean(
      cacheResult.hit &&
      cacheResult.data?.tokens &&
      Array.isArray(cacheResult.data.tokens) &&
      cacheResult.data.tokens.length > 0
    );
    const cachedTokens = isCacheHit
      ? (cacheResult.data?.tokens as string[])
      : null;

    const luna = new LunaClient();

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
          model: luna.modelName,
          reasoning_effort: reasoningEffort,
          reasoningDetected: routing.reasoningDetected,
          matchedCriteria: routing.matchedCriteria,
          socraticMode,
          cacheHit: isCacheHit,
        });

        let fullResponse = "";
        const recordedTokens: string[] = [];
        let providerSuccess = false;
        const providerErrors: string[] = [];

        if (isCacheHit && cachedTokens) {
          for (const token of cachedTokens) {
            fullResponse += token;
            recordedTokens.push(token);
            sendEvent("token", { text: token });
            await new Promise((r) => setTimeout(r, 10));
          }
          providerSuccess = true;
        } else if (luna.isConfigured()) {
          try {
            console.log(
              `[syllabot-stream] Streaming response from Luna (${luna.modelName})...`
            );

            const bodyStream = await luna.stream({
              messages,
              temperature: 0.6,
            });

            const reader = bodyStream.getReader();
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
                      parsed.content ??
                      parsed.text ??
                      "";

                    if (deltaText) {
                      fullResponse += deltaText;
                      recordedTokens.push(deltaText);
                      sendEvent("token", { text: deltaText });
                    }
                  } catch {
                  }
                }
              }
            }

            if (fullResponse.trim().length > 0) {
              providerSuccess = true;
              console.log(
                `[syllabot-stream] Stream successfully completed from Luna (${luna.modelName})`
              );
            }
          } catch (lunaError: any) {
            const errMsg = lunaError.message ?? String(lunaError);
            providerErrors.push(errMsg);
            console.warn(`[syllabot-stream] Luna stream error: ${errMsg}`);
          }
        }

        if (!providerSuccess) {
          console.error(
            `[syllabot-stream] All AI providers failed (${providerErrors.join("; ")}). Emitting error event to client.`
          );
          sendEvent("error", {
            error:
              "AI services are temporarily busy across all providers. Please check your connection and try again.",
            code: "AI_PROVIDERS_UNAVAILABLE",
            details: providerErrors,
          });
          controller.close();
          return;
        }

        if (!isCacheHit && recordedTokens.length > 0 && providerSuccess) {
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

        const isUuid = (str?: string) =>
          Boolean(
            str &&
            /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
              str
            )
          );

        if (
          userId &&
          userId !== "anon-guest" &&
          isUuid(userId) &&
          sessionId &&
          isUuid(sessionId) &&
          fullResponse
        ) {
          try {
            await dbClient.from("chat_sessions").upsert(
              {
                id: sessionId,
                user_id: userId,
                title:
                  rawPrompt.length > 60
                    ? rawPrompt.slice(0, 57) + "..."
                    : rawPrompt || "Study Session",
                socratic_mode: socraticMode,
                updated_at: new Date().toISOString(),
              },
              { onConflict: "id", ignoreDuplicates: true }
            );

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
            console.error("Chat message persistence error:", dbErr);
          }
        }

        sendEvent("done", {
          fullText: fullResponse,
          model: selectedModel,
          reasoning_effort: reasoningEffort,
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

function getSystemPrompt(mode: string, courseCode?: string): string {
  const baseInstruction = `You are Syllabot, a standard-grade, context-aware AI tutor and academic study copilot powered by Kotexify.${
    courseCode ? ` Active Course Context: ${courseCode}.` : ""
  }`;

  const formattingRules = `
Formatting & Communication Guidelines:
1. Always maintain full conversation context across all user messages in this chat session.
2. Format all mathematical expressions using single dollar signs ($...$) for inline equations and double dollar signs ($$...$$) for block equations.
3. Use GitHub-flavored markdown with clean headings, bold text, and bulleted/numbered lists for high readability.
4. When writing code or algorithmic solutions, use syntax-highlighted code blocks with clear inline annotations.
`;

  switch (mode) {
    case "examSim":
      return `${baseInstruction}
Mode: Exam Simulator & Rubric Evaluator.
Your goal is to test the user's conceptual mastery with exam-level analytical questions, multiple-choice questions, or problem sets. Score their reasoning, point out subtle traps or mistakes, and provide structured rubrics.
${formattingRules}`;

    case "directAnswer":
      return `${baseInstruction}
Mode: Direct Solution & Mastery.
Provide concise, direct mathematical solutions, derivations, and explanations without unnecessary conversational filler. Formulate complete step-by-step LaTeX solutions.
${formattingRules}`;

    case "deepResearch":
      return `${baseInstruction}
Mode: Deep Research Assistant.
Provide rigorous academic explanations, formal derivations, historical context, underlying mechanisms, and conceptual citations.
${formattingRules}`;

    case "stepByStep":
    default:
      return `${baseInstruction}
Mode: Socratic & Pedagogical Tutor.
Guide the user step-by-step using the Socratic method. Lead them to discover solutions through key questions, hints, and structured breakdowns rather than revealing final answers prematurely.
${formattingRules}`;
  }
}

function buildMessages(
  body: RequestPayload,
  socraticMode: string,
  courseCode?: string
): { messages: Message[]; rawPrompt: string } {
  let messages: Message[] = [];
  let rawPrompt = body.prompt ?? "";

  if (body.messages && Array.isArray(body.messages) && body.messages.length > 0) {
    messages = [...body.messages];
    const lastUserMsg = [...messages].reverse().find((m) => m.role === "user");
    rawPrompt = lastUserMsg?.content ?? rawPrompt;

    const hasSystem = messages.some((m) => m.role === "system");
    if (!hasSystem) {
      messages.unshift({
        role: "system",
        content: getSystemPrompt(socraticMode, courseCode),
      });
    }
  } else {
    const systemInstruction = getSystemPrompt(socraticMode, courseCode);
    const historyMessages: Message[] = (body.contextHistory ?? []).map((c) => ({
      role: (c.sender === "user" || c.sender === "human" ? "user" : "assistant") as
        | "user"
        | "assistant",
      content: c.text,
    }));

    messages = [
      { role: "system", content: systemInstruction },
      ...historyMessages,
    ];

    if (rawPrompt.trim()) {
      messages.push({ role: "user", content: rawPrompt });
    }
  }

  return { messages, rawPrompt };
}

function buildCacheKey(
  selectedModel: string,
  socraticMode: string,
  messages: Message[]
): string {
  const contextSignature = messages
    .filter((m) => m.role !== "system")
    .map((m) => `${m.role}:${m.content}`)
    .join("||")
    .trim()
    .toLowerCase();

  return `syllabot:${selectedModel}:${socraticMode}:${contextSignature}`;
}

