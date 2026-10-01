import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { LunaClient } from "../_shared/luna_client.ts";
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

    const luna = new LunaClient();
    let generatedQuestions: RawQuizQuestion[] | null = null;

    const systemPrompt = `You are Luna, an expert academic examiner and professor.
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
- If code snippets, programming questions, or algorithms are involved, format them cleanly using standard markdown code fences (e.g. ```dart\n...\n```, ```python\n...\n```) in question, options, or explanation. Preserve proper line breaks and indentation.
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

    try {
      console.log(`[generate-quiz-questions] Requesting quiz from Luna (${luna.modelName})...`);
      const lunaResponse = await luna.complete({
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: `Generate ${finalQuestionCount} ${difficulty}-level quiz questions in structured JSON format now.`,
          },
        ],
        responseFormat: { type: "json_object" },
        temperature: 0.3,
      });

      const parsed = JSON.parse(
        lunaResponse
          .replace(/^```json\s*/i, "")
          .replace(/^```\s*/, "")
          .replace(/```$/, "")
          .trim()
      );
      if (Array.isArray(parsed.questions) && parsed.questions.length > 0) {
        generatedQuestions = parsed.questions;
        if (parsed.quiz_title) deckTitle = parsed.quiz_title;
      }
    } catch (err) {
      console.warn("[generate-quiz-questions] Luna call failed:", err);
    }

    if (!generatedQuestions || generatedQuestions.length === 0) {
      console.error(
        "[generate-quiz-questions] Quiz generation failed across all AI providers."
      );
      return new Response(
        JSON.stringify({
          error:
            "Quiz generation failed across all cloud AI providers. Please check your connection and try again.",
          code: "AI_PROVIDERS_UNAVAILABLE",
          details: luna.lastAttemptErrors,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 503,
        }
      );
    }

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

