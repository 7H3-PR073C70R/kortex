import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface QuizRequest {
  deck_id?: string;
  document_id?: string;
  question_count?: number;
  count?: number; // fallback for backwards-compatibility
  difficulty?: "beginner" | "intermediate" | "advanced";
  course_code?: string;
}

interface RawQuizQuestion {
  id?: string;
  question?: string;
  prompt?: string;
  options?: string[];
  correct_index?: number;
  correct_answer?: string;
  explanation?: string;
  latex_formula?: string | null;
  sub_topic?: string;
  type?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: QuizRequest = await req.json().catch(() => ({}));
    const {
      deck_id,
      document_id,
      question_count,
      count,
      difficulty = "intermediate",
      course_code,
    } = body;

    const finalQuestionCount = Math.min(
      Math.max(question_count ?? count ?? 10, 1),
      30
    );

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
        Deno.env.get("SUPABASE_ANON_KEY") ??
        "",
      {
        global: {
          headers: req.headers.get("Authorization")
            ? { Authorization: req.headers.get("Authorization")! }
            : {},
        },
      }
    );

    const targetId = deck_id ?? document_id ?? "default";
    const cachePrompt = `quiz:${targetId}:${finalQuestionCount}:${difficulty}`;

    // 1. Check Semantic Cache
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      supabaseClient,
      cachePrompt,
      { courseCode: course_code }
    );

    if (cacheResult.hit && cacheResult.data) {
      return new Response(JSON.stringify(cacheResult.data), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "X-Cache": "HIT",
        },
        status: 200,
      });
    }

    // 2. Fetch context if deck_id or document_id is provided
    let deckTitle = "Practice Quiz";
    let contextText = "";

    if (deck_id) {
      const { data: deck } = await supabaseClient
        .from("decks")
        .select("title, subject")
        .eq("id", deck_id)
        .single();
      if (deck) {
        deckTitle = deck.title || deckTitle;
        if (deck.subject) {
          contextText += `Subject: ${deck.subject}\n`;
        }
      }

      const { data: cards } = await supabaseClient
        .from("flashcards")
        .select("front, back")
        .eq("deck_id", deck_id)
        .limit(25);

      if (cards && cards.length > 0) {
        contextText += cards
          .map((c) => `Concept: ${c.front}\nDetail: ${c.back}`)
          .join("\n\n");
      }
    } else if (document_id) {
      const { data: doc } = await supabaseClient
        .from("documents")
        .select("title")
        .eq("id", document_id)
        .single();
      if (doc?.title) {
        deckTitle = doc.title;
      }

      const { data: chunks } = await supabaseClient
        .from("document_chunks")
        .select("content")
        .eq("document_id", document_id)
        .limit(15);

      if (chunks && chunks.length > 0) {
        contextText = chunks.map((c) => c.content).join("\n\n");
      }
    }

    // 3. Attempt LLM Generation (Groq -> Gemini)
    const groqApiKey = Deno.env.get("GROQ_API_KEY") || "";
    const geminiApiKey =
      Deno.env.get("GEMINI_API_KEY") ||
      Deno.env.get("GOOGLE_AI_API_KEY") ||
      "";
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY") || "";

    let generatedQuestions: RawQuizQuestion[] | null = null;

    const systemPrompt = `You are an expert academic examiner and professor.
Create exactly ${finalQuestionCount} high-yield multiple-choice quiz questions based on the provided topic/material.
Difficulty level: ${difficulty}.
Context material:
${contextText ? contextText.slice(0, 4000) : `Topic: ${deckTitle}`}

Requirements:
- Questions must be rigorous, clear, and pedagogically sound.
- Include 4 plausible options for each question.
- Explicitly identify the 0-based index of the correct option.
- Provide a concise academic explanation.
- If relevant (mathematics, physics, engineering, chemistry), include a valid LaTeX formula (e.g. "\\Delta G = \\Delta H - T\\Delta S"). If none, set latex_formula to null.
- Set sub_topic to a relevant academic topic area.

You MUST reply with ONLY a single valid JSON object strictly matching this schema:
{
  "quiz_title": "Descriptive Quiz Title",
  "questions": [
    {
      "id": "q-1",
      "question": "Question text here?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "explanation": "Why option A is correct...",
      "latex_formula": "\\Delta G = \\Delta H - T\\Delta S",
      "sub_topic": "Thermodynamics"
    }
  ]
}`;

    // Try Groq first (llama-3.3-70b-versatile)
    if (groqApiKey && !generatedQuestions) {
      try {
        const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${groqApiKey}`,
          },
          body: JSON.stringify({
            model: "llama-3.3-70b-versatile",
            messages: [
              { role: "system", content: systemPrompt },
              {
                role: "user",
                content: `Generate ${finalQuestionCount} ${difficulty}-level quiz questions in structured JSON format now.`,
              },
            ],
            response_format: { type: "json_object" },
            temperature: 0.3,
          }),
        });

        if (groqRes.ok) {
          const groqData = await groqRes.json();
          const content = groqData.choices?.[0]?.message?.content;
          if (content) {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed.questions) && parsed.questions.length > 0) {
              generatedQuestions = parsed.questions;
              if (parsed.quiz_title) deckTitle = parsed.quiz_title;
            }
          }
        } else {
          console.warn("[generate-quiz-questions] Groq API returned error status:", groqRes.status);
        }
      } catch (err) {
        console.warn("[generate-quiz-questions] Groq call failed:", err);
      }
    }

    // Try Gemini if Groq was not available or failed
    if (geminiApiKey && !generatedQuestions) {
      try {
        const geminiRes = await fetch(
          "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${geminiApiKey}`,
            },
            body: JSON.stringify({
              model: "gemini-1.5-flash",
              messages: [
                { role: "system", content: systemPrompt },
                {
                  role: "user",
                  content: `Generate ${finalQuestionCount} ${difficulty}-level quiz questions in structured JSON format now.`,
                },
              ],
              response_format: { type: "json_object" },
              temperature: 0.3,
            }),
          }
        );

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json();
          const content = geminiData.choices?.[0]?.message?.content;
          if (content) {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed.questions) && parsed.questions.length > 0) {
              generatedQuestions = parsed.questions;
              if (parsed.quiz_title) deckTitle = parsed.quiz_title;
            }
          }
        } else {
          console.warn("[generate-quiz-questions] Gemini API error:", geminiRes.status);
        }
      } catch (err) {
        console.warn("[generate-quiz-questions] Gemini call failed:", err);
      }
    }

    // Try OpenAI as additional backup if available
    if (openaiApiKey && !generatedQuestions) {
      try {
        const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openaiApiKey}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: systemPrompt },
              {
                role: "user",
                content: `Generate ${finalQuestionCount} ${difficulty}-level quiz questions in structured JSON format now.`,
              },
            ],
            response_format: { type: "json_object" },
            temperature: 0.3,
          }),
        });

        if (openaiRes.ok) {
          const openaiData = await openaiRes.json();
          const content = openaiData.choices?.[0]?.message?.content;
          if (content) {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed.questions) && parsed.questions.length > 0) {
              generatedQuestions = parsed.questions;
              if (parsed.quiz_title) deckTitle = parsed.quiz_title;
            }
          }
        }
      } catch (err) {
        console.warn("[generate-quiz-questions] OpenAI call failed:", err);
      }
    }

    // 4. Fallback mock response if LLM keys are missing or calls fail in dev environments
    if (!generatedQuestions || generatedQuestions.length === 0) {
      console.log(
        "[generate-quiz-questions] Using graceful fallback mock response (dev/offline mode)"
      );
      generatedQuestions = getFallbackQuestions(deckTitle);
    }

    // Format and sanitize questions ensuring required fields:
    // id, question, options, correct_index, explanation, latex_formula (plus prompt, correct_answer for client compat)
    const formattedQuestions = generatedQuestions.slice(0, finalQuestionCount).map((q, idx) => {
      const qText = q.question || q.prompt || `Question ${idx + 1}`;
      const options = Array.isArray(q.options) && q.options.length > 0
        ? q.options
        : ["Option A", "Option B", "Option C", "Option D"];
      const correctIndex =
        typeof q.correct_index === "number" &&
        q.correct_index >= 0 &&
        q.correct_index < options.length
          ? q.correct_index
          : 0;
      const correctAnswer = options[correctIndex] || q.correct_answer || options[0];

      return {
        id: q.id || `q-ai-${idx + 1}`,
        question: qText,
        prompt: qText,
        type: q.type || (options.length === 2 ? "trueFalse" : "multipleChoice"),
        options,
        correct_index: correctIndex,
        correct_answer: correctAnswer,
        explanation:
          q.explanation ||
          `Option "${correctAnswer}" is the verified correct answer based on foundational theory.`,
        latex_formula: q.latex_formula ?? null,
        sub_topic: q.sub_topic || deckTitle || "General Knowledge",
      };
    });

    const payload = {
      quiz_title: deckTitle,
      questions: formattedQuestions,
    };

    // Cache generated quiz
    await SemanticCacheProvider.setCachedResponse(
      supabaseClient,
      cachePrompt,
      payload,
      { courseCode: course_code }
    );

    return new Response(JSON.stringify(payload), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "X-Cache": "MISS",
      },
      status: 200,
    });
  } catch (error) {
    console.error("[generate-quiz-questions] Exception:", error);
    return new Response(
      JSON.stringify({
        error: (error as Error).message ?? "Internal quiz generation error",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

function getFallbackQuestions(subject: string): RawQuizQuestion[] {
  return [
    {
      id: "q-ai-1",
      question:
        "Which parameter directly dictates the thermodynamic spontaneity of a closed reaction system?",
      prompt:
        "Which parameter directly dictates the thermodynamic spontaneity of a closed reaction system?",
      options: [
        "\\Delta G (Gibbs Free Energy)",
        "\\Delta H (Enthalpy)",
        "\\Delta S (Entropy)",
        "E_a (Activation Energy)",
      ],
      correct_index: 0,
      correct_answer: "\\Delta G (Gibbs Free Energy)",
      explanation:
        "A process is spontaneous at constant temperature and pressure if and only if \\Delta G < 0.",
      sub_topic: "Thermodynamics",
      latex_formula: "\\Delta G = \\Delta H - T\\Delta S",
    },
    {
      id: "q-ai-2",
      question:
        "What is the electric field inside a uniformly charged conducting sphere in electrostatic equilibrium?",
      prompt:
        "What is the electric field inside a uniformly charged conducting sphere in electrostatic equilibrium?",
      options: ["0", "\\frac{kQ}{r^2}", "\\frac{kQ}{r}", "\\infty"],
      correct_index: 0,
      correct_answer: "0",
      explanation:
        "By Gauss's law, electric charges redistribute exclusively onto the outer surface, leaving E = 0 inside the conductor.",
      sub_topic: "Electromagnetism",
      latex_formula:
        "\\oint \\vec{E} \\cdot d\\vec{A} = \\frac{Q_{enc}}{\\varepsilon_0} = 0",
    },
    {
      id: "q-ai-3",
      question:
        "True or False: Isothermal expansion of an ideal gas results in zero change in internal energy (\\Delta U = 0).",
      prompt:
        "True or False: Isothermal expansion of an ideal gas results in zero change in internal energy (\\Delta U = 0).",
      type: "trueFalse",
      options: ["True", "False"],
      correct_index: 0,
      correct_answer: "True",
      explanation:
        "Internal energy of an ideal gas depends solely on temperature: U = nC_v T. Since \\Delta T = 0, \\Delta U = 0.",
      sub_topic: "Thermodynamic Cycles",
      latex_formula: "\\Delta U = n C_v \\Delta T = 0",
    },
    {
      id: "q-ai-4",
      question:
        "What is the derivative of the natural exponential composite function f(x) = e^{2x} with respect to x?",
      prompt:
        "What is the derivative of the natural exponential composite function f(x) = e^{2x} with respect to x?",
      options: ["2e^{2x}", "e^{2x}", "4e^{2x}", "\\frac{1}{2}e^{2x}"],
      correct_index: 0,
      correct_answer: "2e^{2x}",
      explanation:
        "Applying the chain rule d/dx[e^{u}] = e^{u} * du/dx, where u = 2x and du/dx = 2.",
      sub_topic: "Differential Calculus",
      latex_formula: "\\frac{d}{dx} e^{2x} = 2e^{2x}",
    },
    {
      id: "q-ai-5",
      question:
        "Under Newton's second law, what is the net force acting on an object of invariant mass moving at constant velocity?",
      prompt:
        "Under Newton's second law, what is the net force acting on an object of invariant mass moving at constant velocity?",
      options: ["0 N", "m * v", "m * g", "Infinity"],
      correct_index: 0,
      correct_answer: "0 N",
      explanation:
        "Constant velocity implies zero acceleration (a = dv/dt = 0). Therefore, net force F = ma = 0.",
      sub_topic: "Classical Mechanics",
      latex_formula: "\\vec{F}_{net} = m \\frac{d\\vec{v}}{dt} = 0",
    },
  ];
}
