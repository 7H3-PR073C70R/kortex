import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { deck_id, document_id, count = 10 } = await req.json();

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    let deckTitle = "Practice Quiz";
    let cardsText = "";

    if (deck_id) {
      const { data: deck } = await supabaseClient
        .from("decks")
        .select("title, subject")
        .eq("id", deck_id)
        .single();
      if (deck) deckTitle = deck.title;

      const { data: cards } = await supabaseClient
        .from("flashcards")
        .select("front, back")
        .eq("deck_id", deck_id)
        .limit(20);

      if (cards && cards.length > 0) {
        cardsText = cards.map((c) => `Q: ${c.front}\nA: ${c.back}`).join("\n\n");
      }
    } else if (document_id) {
      const { data: chunks } = await supabaseClient
        .from("document_chunks")
        .select("content")
        .eq("document_id", document_id)
        .limit(10);

      if (chunks && chunks.length > 0) {
        cardsText = chunks.map((c) => c.content).join("\n\n");
      }
    }

    // Return structured generated questions
    const mockQuestions = [
      {
        id: "q-ai-1",
        prompt: "Which parameter directly dictates the thermodynamic spontaneity of a closed reaction system?",
        type: "multipleChoice",
        options: [
          "\\Delta G (Gibbs Free Energy)",
          "\\Delta H (Enthalpy)",
          "\\Delta S (Entropy)",
          "E_a (Activation Energy)"
        ],
        correct_answer: "\\Delta G (Gibbs Free Energy)",
        explanation: "A process is spontaneous at constant temperature and pressure if and only if \\Delta G < 0.",
        sub_topic: "Thermodynamics",
        latex_formula: "\\Delta G = \\Delta H - T\\Delta S"
      },
      {
        id: "q-ai-2",
        prompt: "What is the electric field inside a uniformly charged conducting sphere in electrostatic equilibrium?",
        type: "multipleChoice",
        options: [
          "0",
          "\\frac{kQ}{r^2}",
          "\\frac{kQ}{r}",
          "\\infty"
        ],
        correct_answer: "0",
        explanation: "By Gauss's law, electric charges redistribute exclusively onto the outer surface, leaving E = 0 inside the conductor.",
        sub_topic: "Electromagnetism",
        latex_formula: "\\oint \\vec{E} \\cdot d\\vec{A} = \\frac{Q_{enc}}{\\varepsilon_0} = 0"
      },
      {
        id: "q-ai-3",
        prompt: "True or False: Isothermal expansion of an ideal gas results in zero change in internal energy (\\Delta U = 0).",
        type: "trueFalse",
        options: ["True", "False"],
        correct_answer: "True",
        explanation: "Internal energy of an ideal gas depends solely on temperature: U = nC_v T. Since \\Delta T = 0, \\Delta U = 0.",
        sub_topic: "Thermodynamic Cycles"
      }
    ];

    return new Response(
      JSON.stringify({
        quiz_title: deckTitle,
        questions: mockQuestions.slice(0, count)
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
