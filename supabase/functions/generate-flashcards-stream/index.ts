import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { enforceDailyQuota } from "../_shared/quota_limiter.ts";
import { LunaClient } from "../_shared/luna_client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface GenerateFlashcardsRequest {
  topic?: string;
  sourceText?: string;
  deckId?: string;
  courseCode?: string;
  count?: number;
  difficulty?: "beginner" | "intermediate" | "advanced";
}

interface ParsedCard {
  front: string;
  back: string;
  tags?: string[];
  hints?: string;
  explanation?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Bearer token" }),
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
        JSON.stringify({ error: "Unauthorized: Invalid or expired token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userId = user.id;

    const body: GenerateFlashcardsRequest = await req.json().catch(() => ({}));
    const rawTopic = body.topic?.trim() || "Academic Foundations";
    const rawSourceText = body.sourceText?.trim();

    const quotaCheck = await enforceDailyQuota(
      userId,
      "ai_question",
      "free",
      corsHeaders
    );

    if (!quotaCheck.allowed && quotaCheck.errorResponse) {
      return quotaCheck.errorResponse;
    }

    const requestedCount = body.count;
    const dynamicCount =
      rawSourceText && rawSourceText.length > 5000
        ? Math.max(10, Math.ceil(rawSourceText.length / 2000))
        : 10;
    const totalCount =
      requestedCount && requestedCount > 0
        ? Math.max(requestedCount, 3)
        : dynamicCount;
    const deckId = body.deckId || `deck_${Date.now()}`;
    const difficulty = body.difficulty || "intermediate";
    const topic = rawTopic;
    const sourceText = rawSourceText;

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        const sendEvent = (event: string, data: Record<string, unknown>) => {
          controller.enqueue(
            encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          );
        };

        sendEvent("start", {
          status: "streaming",
          deckId,
          topic,
          targetCount: totalCount,
          immediateThreshold: 3,
        });

        const generatedCards: Record<string, unknown>[] = [];
        const remainingCount = totalCount;
        if (remainingCount > 0) {
          const luna = new LunaClient();
          let streamSuccess = false;

          const systemPrompt = `You are Luna, a world-class academic tutor and flashcard specialist.
Generate high-quality, rigorous flashcards for the student.
Topic: "${topic}"
Difficulty: ${difficulty}
${sourceText ? `Source Material:\n${sourceText.length > 50000 ? sourceText.slice(0, 50000) : sourceText}` : ""}

CRITICAL OUTPUT INSTRUCTIONS:
- You must output exactly ${remainingCount} unique academic flashcards.
- Output each flashcard on its OWN line as a standalone valid JSON object (Newline-Delimited JSON / NDJSON format).
- Do NOT wrap the output in markdown codeblocks (no \`\`\` or \`\`\`json).
- Do NOT output an outer array or commas between lines.
- Each line MUST be a complete, parsable JSON object with the following schema:
{"front": "Concept or Question", "back": "Mathematical definition, line-by-line checklist/steps, and LaTeX formulas", "tags": ["${topic}", "${difficulty}"], "hints": "Brief mnemonic or hint"}`;

          try {
            console.log(`[generate-flashcards-stream] Streaming from Luna (${luna.modelName})...`);
            const bodyStream = await luna.stream({
              messages: [
                { role: "system", content: systemPrompt },
                {
                  role: "user",
                  content: `Generate ${remainingCount} flashcards in NDJSON format now.`,
                },
              ],
              temperature: 0.3,
            });

            const reader = bodyStream.getReader();
            const decoder = new TextDecoder("utf-8");
            let sseBuffer = "";
            let cardJsonBuffer = "";

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              sseBuffer += decoder.decode(value, { stream: true });
              const lines = sseBuffer.split("\n");
              sseBuffer = lines.pop() ?? "";

              for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed || trimmed.startsWith(":")) continue;
                if (trimmed === "data: [DONE]") break;

                if (trimmed.startsWith("data:")) {
                  const jsonStr = trimmed.replace(/^data:\s*/, "");
                  try {
                    const parsed = JSON.parse(jsonStr);
                    const deltaText =
                      parsed.choices?.[0]?.delta?.content ??
                      parsed.choices?.[0]?.delta?.text ??
                      "";

                    if (deltaText) {
                      cardJsonBuffer += deltaText;

                      while (cardJsonBuffer.includes("\n")) {
                        const newlineIdx = cardJsonBuffer.indexOf("\n");
                        const rawLine = cardJsonBuffer.slice(0, newlineIdx).trim();
                        cardJsonBuffer = cardJsonBuffer.slice(newlineIdx + 1);

                        if (!rawLine) continue;

                        const cleanedLine = rawLine
                          .replace(/^```json\s*/i, "")
                          .replace(/^```\s*/, "")
                          .replace(/```$/, "")
                          .replace(/^,\s*/, "")
                          .trim();

                        if (!cleanedLine.startsWith("{")) continue;

                        try {
                          const parsedCard: ParsedCard = JSON.parse(cleanedLine);
                          if (parsedCard.front && parsedCard.back) {
                            const cardIndex = generatedCards.length + 1;
                            const card = {
                              id: `card_${deckId}_${cardIndex}`,
                              deckId,
                              index: cardIndex,
                              front: parsedCard.front,
                              back: parsedCard.back,
                              explanation:
                                parsedCard.hints || parsedCard.explanation || "",
                              hints:
                                parsedCard.hints || parsedCard.explanation || "",
                              tags:
                                Array.isArray(parsedCard.tags) &&
                                parsedCard.tags.length > 0
                                  ? parsedCard.tags
                                  : [topic, difficulty],
                              createdAt: new Date().toISOString(),
                              isImmediate: false,
                            };
                            generatedCards.push(card);

                            sendEvent("card", {
                              card,
                              isInitialBatch: false,
                              currentCount: generatedCards.length,
                              targetCount: totalCount,
                            });

                            if (generatedCards.length >= totalCount) {
                              break;
                            }
                          }
                        } catch {
                        }
                      }
                    }
                  } catch {
                  }
                }
              }

              if (generatedCards.length >= totalCount) {
                break;
              }
            }

            if (cardJsonBuffer.trim() && generatedCards.length < totalCount) {
              const cleanedTrailing = cardJsonBuffer
                .trim()
                .replace(/^```json\s*/i, "")
                .replace(/^```\s*/, "")
                .replace(/```$/, "")
                .trim();
              try {
                const parsedCard: ParsedCard = JSON.parse(cleanedTrailing);
                if (parsedCard.front && parsedCard.back) {
                  const cardIndex = generatedCards.length + 1;
                  const card = {
                    id: `card_${deckId}_${cardIndex}`,
                    deckId,
                    index: cardIndex,
                    front: parsedCard.front,
                    back: parsedCard.back,
                    explanation:
                      parsedCard.hints || parsedCard.explanation || "",
                    hints:
                      parsedCard.hints || parsedCard.explanation || "",
                    tags:
                      Array.isArray(parsedCard.tags) && parsedCard.tags.length > 0
                        ? parsedCard.tags
                        : [topic, difficulty],
                    createdAt: new Date().toISOString(),
                    isImmediate: false,
                  };
                  generatedCards.push(card);

                  sendEvent("card", {
                    card,
                    isInitialBatch: false,
                    currentCount: generatedCards.length,
                    targetCount: totalCount,
                  });
                }
              } catch {
              }
            }

            if (generatedCards.length > 0) {
              streamSuccess = true;
            }
          } catch (err) {
            console.warn("[generate-flashcards-stream] Luna stream error:", err);
          }

          if (!streamSuccess || generatedCards.length === 0) {
            console.error(
              "[generate-flashcards-stream] AI stream failed across all providers and produced no cards."
            );
            sendEvent("error", {
              error:
                "AI flashcard generation failed across all providers. Please check your connection and try again.",
              code: "AI_GENERATION_FAILED",
            });
            controller.close();
            return;
          }
        }

        sendEvent("done", {
          status: "completed",
          deckId,
          totalCards: generatedCards.length,
          timestamp: new Date().toISOString(),
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
  } catch (error: any) {
    console.error("[generate-flashcards-stream] Handler error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "Flashcard generation error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

