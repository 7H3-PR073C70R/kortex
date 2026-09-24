import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { SemanticCacheProvider } from "../_shared/semantic_cache_provider.ts";
import { LunaClient } from "../_shared/luna_client.ts";
import { corsHeaders } from "./_shared/cors.ts";
import {
  Message,
  normalizeModelForBaseUrl,
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

    let rawPrompt = body.prompt ?? "";
    let messages: Message[] = [];

    if (body.messages && Array.isArray(body.messages) && body.messages.length > 0) {
      messages = body.messages;
      const lastUserMsg = [...messages].reverse().find((m) => m.role === "user");
      rawPrompt = lastUserMsg?.content ?? rawPrompt;
    } else {
      const systemInstruction = getSystemPrompt(socraticMode);
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

    const routing = selectModelAndParams(messages, {
      forceModel: body.forceModel,
    });
    const selectedModel = routing.model;
    const reasoningEffort = routing.reasoning_effort;

    const cachePrompt = `syllabot:${selectedModel}:${socraticMode}:${rawPrompt.trim().toLowerCase()}`;
    const cacheResult = await SemanticCacheProvider.getCachedResponse(
      dbClient,
      cachePrompt,
      { courseCode }
    );

    const isCacheHit = Boolean(
      cacheResult.hit &&
      cacheResult.data?.tokens &&
      !isCorruptedOrMismatchCache(rawPrompt, cacheResult.data.tokens as string[])
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
          const detailMsg =
            providerErrors.length > 0
              ? providerErrors.join("; ")
              : "Unable to complete AI response from Luna provider.";
          console.error(
            `[syllabot-stream] Provider stream failed: ${detailMsg}`
          );
          sendEvent("error", {
            error: "PROVIDER_STREAM_ERROR",
            message: detailMsg,
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
                    : rawPrompt,
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

function getSystemPrompt(mode: string): string {
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

function isCorruptedOrMismatchCache(rawPrompt: string, cachedTokens: string[]): boolean {
  const fullCached = cachedTokens.join(" ").toLowerCase();
  const lowerPrompt = rawPrompt.toLowerCase();

  if (
    (fullCached.includes("noether") || fullCached.includes("hamiltonian") || fullCached.includes("\\mathcal{h}")) &&
    !lowerPrompt.includes("noether") &&
    !lowerPrompt.includes("hamiltonian") &&
    !lowerPrompt.includes("lagrangian")
  ) {
    return true;
  }

  if (
    fullCached.includes("a **noun** is a fundamental part of speech") &&
    (lowerPrompt.includes("adverb") ||
      lowerPrompt.includes("adjective") ||
      lowerPrompt.includes("verb") ||
      lowerPrompt.includes("conjunction") ||
      lowerPrompt.includes("preposition"))
  ) {
    return true;
  }

  if (
    fullCached.includes("represents a foundational concept in its respective domain") ||
    fullCached.includes("curiosity led the researcher to a breakthrough")
  ) {
    return true;
  }

  return false;
}

function getFallbackTokens(
  prompt: string,
  isComplex: boolean,
  contextHistory?: Array<{ sender: string; text: string }>
): string[] {
  const cleanPrompt = prompt.replace(/[?!.]+$/, "").trim();
  const lower = cleanPrompt.toLowerCase();
  const previousText = (contextHistory ?? [])
    .map((c) => c.text.toLowerCase())
    .join(" ");

  if (
    lower.includes("all 8") ||
    lower.includes("8 of them") ||
    lower.includes("example of all 8") ||
    lower.includes("8 parts of speech") ||
    (lower.includes("examples") && lower.includes("parts of speech")) ||
    ((lower.includes("example") || lower.includes("explain") || lower.includes("details")) &&
      previousText.includes("parts of speech"))
  ) {
    return [
      "Here is a comprehensive breakdown of all **8 Parts of Speech** with clear definitions, categories, and detailed sentence examples:",
      "\n\n### 1. Noun (Naming Word)",
      "\n• **Definition:** Names a person, place, thing, or abstract idea.",
      '\n• **Example in context:** *"**Marie Curie** conducted pioneering **research** in a modest **laboratory** in **Paris**."*',
      "\n• **Breakdown:** *Marie Curie* (Proper Noun), *research* (Abstract Noun), *laboratory* (Concrete Noun), *Paris* (Proper Noun).",
      "\n\n### 2. Pronoun (Noun Substitute)",
      "\n• **Definition:** Replaces a noun to avoid awkward repetition.",
      '\n• **Example in context:** *"When the **engineer** finished the simulation, **she** verified that **it** converged without errors."*',
      "\n• **Breakdown:** *she* refers back to *engineer*; *it* refers back to *simulation*.",
      "\n\n### 3. Verb (Action or State)",
      "\n• **Definition:** Expresses a physical action, a mental process, or a state of being.",
      '\n• **Example in context:** *"The catalyst **accelerates** the chemical reaction while the temperature **remains** constant."*',
      "\n• **Breakdown:** *accelerates* (Action Verb, Transitive), *remains* (Linking/State Verb).",
      "\n\n### 4. Adjective (Noun Descriptor)",
      "\n• **Definition:** Modifies, qualifies, or describes a noun or pronoun, specifying qualities, quantities, or degrees.",
      '\n• **Example in context:** *"The **autonomous** rover captured **high-resolution** spectra across **three** distinct craters."*',
      "\n• **Breakdown:** *autonomous* (Descriptive), *high-resolution* (Descriptive), *three* (Quantitative).",
      "\n\n### 5. Adverb (Modifier of Verbs/Adjectives/Adverbs)",
      "\n• **Definition:** Modifies a verb, an adjective, or another adverb by answering *How?*, *When?*, *Where?*, or *To what degree?*",
      '\n• **Example in context:** *"The neural network converged **exceptionally** **rapidly** yesterday."*',
      "\n• **Breakdown:** *rapidly* (Manner, modifies *converged*), *exceptionally* (Degree, modifies *rapidly*), *yesterday* (Time).",
      "\n\n### 6. Preposition (Relational Word)",
      "\n• **Definition:** Shows relationships of location, direction, time, or spatial orientation between nouns and other words.",
      '\n• **Example in context:** *"The current traveled **through** the superconductor **at** sub-zero temperatures."*',
      "\n• **Breakdown:** *through* (Spatial orientation), *at* (Condition/state).",
      "\n\n### 7. Conjunction (Connector)",
      "\n• **Definition:** Links words, phrases, or clauses together.",
      '\n• **Example in context:** *"The hypothesis was bold, **yet** the empirical evidence was undeniable **because** every trial reproduced the same result."*',
      "\n• **Breakdown:** *yet* (Coordinating conjunction), *because* (Subordinating conjunction).",
      "\n\n### 8. Interjection (Exclamatory Word)",
      "\n• **Definition:** Expresses sudden emotion, reaction, or exclamation; grammatically independent from the main clause.",
      '\n• **Example in context:** *"**Eureka!** The crystallographic pattern finally aligned."*',
      "\n• **Breakdown:** *Eureka!* (Expresses sudden discovery/triumph).",
      "\n\n---\n*Socratic Practice:* Can you compose a single sentence that successfully incorporates at least **five** of these eight parts of speech?",
    ];
  }

  if (
    lower.includes("parts of speech") ||
    lower.includes("part of speech") ||
    lower.includes("part of speach") ||
    lower.includes("parts of speach")
  ) {
    return [
      "The **parts of speech** are the primary grammatical categories of words based on their syntactic and semantic functions in a sentence.",
      "\n\n### The 8 Essential Parts of Speech:",
      "\n1. **Noun:** Names a person, place, thing, or concept (*laboratory*, *entropy*).",
      "\n2. **Pronoun:** Replaces a noun (*it*, *they*, *who*).",
      "\n3. **Verb:** Expresses an action or state of being (*synthesize*, *radiate*).",
      "\n4. **Adjective:** Modifies or describes a noun (*conductive*, *dense*).",
      "\n5. **Adverb:** Modifies a verb, adjective, or another adverb (*precisely*, *rapidly*).",
      "\n6. **Preposition:** Indicates spatial or temporal relationships (*across*, *within*).",
      "\n7. **Conjunction:** Connects clauses or words (*and*, *because*, *although*).",
      "\n8. **Interjection:** Expresses emotion or exclamation (*eureka!*, *indeed*).",
      "\n\n*Socratic Check:* Which specific part of speech would you like to explore deeper?",
    ];
  }

  if (lower.includes("adverb")) {
    return [
      "An **adverb** is a part of speech that modifies or qualifies a **verb**, an **adjective**, or **another adverb**.",
      "\n\n### 1. Categories of Adverbs:",
      "\n• **Manner (How?):** *accurately*, *smoothly*, *carefully*",
      "\n• **Time (When?):** *yesterday*, *already*, *simultaneously*",
      "\n• **Place (Where?):** *here*, *everywhere*, *downward*",
      "\n• **Degree (To what extent?):** *extremely*, *sufficiently*, *very*",
      "\n• **Frequency (How often?):** *frequently*, *periodically*, *never*",
      "\n\n### 2. Sentence Structure Examples:",
      '\n1. Modifying a verb: *"The algorithm executed **flawlessly**."*',
      '\n2. Modifying an adjective: *"The solution was **remarkably** simple."*',
      '\n3. Modifying another adverb: *"The particle moved **quite** rapidly."*',
      '\n\n*Socratic Check:* Can you identify the adverb in: *"The researcher examined the specimen carefully"*?',
    ];
  }

  if (lower.includes("adjective")) {
    return [
      "An **adjective** is a part of speech that modifies, describes, or quantifies a **noun** or **pronoun**.",
      "\n\n### 1. Types of Adjectives:",
      "\n• **Descriptive (Qualitative):** *efficient*, *turbulent*, *crystalline*",
      "\n• **Quantitative:** *three*, *several*, *abundant*, *zero*",
      "\n• **Demonstrative:** *this*, *that*, *these*, *those*",
      "\n• **Comparative & Superlative:** *faster / fastest*, *more stable / most stable*",
      "\n\n### 2. Syntactic Placement:",
      '\n• **Attributive (Before the noun):** *"A **magnetic** field..."*',
      '\n• **Predicative (After a linking verb):** *"The reaction is **exothermic**."*',
      '\n\n*Socratic Check:* What are the adjectives in: *"Two innovative scientists discovered a rare isotope."*?',
    ];
  }

  if (/\b(verbs?|action words?)\b/i.test(lower)) {
    return [
      "A **verb** is the essential grammatical part of speech that expresses an **action**, an **occurrence**, or a **state of being**.",
      "\n\n### 1. Primary Classifications:",
      "\n• **Action Verbs:** *accelerate*, *synthesize*, *radiate*",
      "\n• **Linking Verbs (State of Being):** *is*, *become*, *remain*, *seem*",
      "\n• **Auxiliary (Helping) Verbs:** *have*, *can*, *will*, *must*",
      '\n• **Transitive vs. Intransitive:** Transitive verbs take an object (*"She **proved** the theorem"*); intransitive verbs do not (*"The stars **glow**"*).',
      '\n\n*Socratic Check:* What is the verb in: *"The enzyme accelerates the biochemical reaction"*, and is it transitive or intransitive?',
    ];
  }

  if (/\b(nouns?)\b/i.test(lower)) {
    return [
      "A **noun** is a fundamental part of speech that names a **person**, **place**, **thing**, or **idea**.",
      "\n\n### 1. Categories of Nouns:",
      "\n• **Common Nouns:** General names for things (e.g., *student*, *city*, *book*).",
      "\n• **Proper Nouns:** Specific names, always capitalized (e.g., *Wuke Anjolaoluwa Omotoyosi*, *London*, *Kortex*).",
      "\n• **Abstract Nouns:** Intangible concepts, feelings, or qualities (e.g., *gravity*, *knowledge*, *courage*).",
      "\n• **Concrete Nouns:** Tangible objects perceptible by the senses (e.g., *apple*, *telescope*).",
      "\n• **Collective Nouns:** Groups of individuals or items (e.g., *team*, *flock*, *committee*).",
      "\n\n### 2. Syntactic Function in Sentences:",
      "\nIn a sentence, a noun typically functions as either:",
      '\n1. **The Subject:** Who or what performs the action (*"The **algorithm** converged quickly."*)',
      '\n2. **The Direct Object:** The entity receiving the action (*"The student solved the **equation**."*)',
      '\n3. **The Object of a Preposition:** (*"Inside the **laboratory**..."*)',
      '\n\n*Socratic Check:* Can you identify the nouns in this sentence: *"Curiosity led the researcher to a breakthrough"*?',
    ];
  }

  if (
    lower.includes("circle") ||
    lower.includes("angle at center") ||
    lower.includes("circumference") ||
    lower.includes("inscribed") ||
    lower.includes("chord") ||
    lower.includes("tangent")
  ) {
    return [
      "Let us prove the fundamental circle theorem from geometric first principles.",
      "\n\n**Theorem Statement:**",
      "\nThe angle subtended by an arc at the center is twice the angle subtended by it at any point on the circumference:",
      "\n$$\\mathbf{\\angle AOB = 2 \\times \\angle APB}$$",
      "\n\n**1. Geometric Construction:**",
      "\nLet $O$ be the center of the circle. Draw line $PO$ extending to point $C$ on the circle. Because $OA = OB = OP = r$ (radii of the circle), triangles $\\triangle APO$ and $\\triangle BPO$ are isosceles:",
      "\n$$\\angle OPA = \\angle OAP = \\alpha, \\quad \\angle OPB = \\angle OBP = \\beta$$",
      "\n\n**2. Exterior Angle Theorem:**",
      "\nThe exterior angle of a triangle equals the sum of its two opposite interior angles:",
      "\n$$\\angle AOC = \\alpha + \\alpha = 2\\alpha, \\quad \\angle BOC = \\beta + \\beta = 2\\beta$$",
      "\n\n**3. Angle Synthesis & Proof Completion:**",
      "\nSumming the adjacent angles at the center:",
      "\n$$\\angle AOB = \\angle AOC + \\angle BOC = 2\\alpha + 2\\beta = 2(\\alpha + \\beta)$$",
      "\nSince $\\angle APB = \\alpha + \\beta$:",
      "\n$$\\mathbf{\\angle AOB = 2 \\angle APB \\quad \\blacksquare}$$",
      "\n\nWould you like to solve a numerical practice problem or convert this theorem into flashcards?",
    ];
  }

  if (
    lower === "whoami" ||
    lower.includes("what is whoami") ||
    lower.includes("whoami command")
  ) {
    return [
      "In computing and POSIX-compliant operating systems (Linux, macOS, Unix), **`whoami`** is a standard core utility that prints the effective username associated with the current running process.",
      "\n\n### 1. Underlying Mechanics:",
      "\n• **Effective User ID (EUID):** Operating systems enforce file and process permissions based on the *effective user ID*. When you run `whoami`, the system invokes `geteuid()` and maps that numerical identifier to a username in `/etc/passwd` or the directory service.",
      "\n• **Privilege Boundaries:** If an unprivileged user executes `whoami`, it outputs their username (e.g., `student`). When run via `sudo whoami`, it outputs `root` because the execution context has been elevated to superuser privileges.",
      "\n\n### 2. Practical Applications:",
      '\n1. **Shell Script Automation:** Checking runtime privileges before critical tasks (*e.g., `if [ "$(whoami)" != "root" ]; then echo "Requires root"; exit 1; fi`*).',
      "\n2. **Remote SSH & Container Auditing:** Confirming the active user session in containerized (Docker/Kubernetes) or multi-tenant environments.",
      "\n\n*Socratic Check:* If a binary has the **SUID (Set User ID)** permission enabled and is owned by `root`, what will `whoami` return when executed by an unprivileged user?",
    ];
  }

  if (
    lower.includes("who are you") ||
    lower.includes("what are you") ||
    lower.includes("what is syllabot") ||
    lower.includes("tell me about yourself")
  ) {
    return [
      "I am **Syllabot**, your adaptive academic AI tutor and study copilot built directly into **Kortex**.",
      "\n\n### How I Support Your Learning:",
      "\n• **Socratic Problem Solving:** Guiding you through STEM derivations, proofs, and practice problems step-by-step.",
      "\n• **Exam Simulation & Rubrics:** Testing your knowledge with exam-level analytical questions and scoring your conceptual reasoning.",
      "\n• **Course-Integrated RAG:** Aligning explanations with your uploaded lecture notes, syllabus topics, and textbook chunks.",
      "\n• **Private Hybrid Intelligence:** Running either fast cloud inference or private on-device LLMs whenever you are offline.",
      "\n\n*What academic subject or exam topic would you like to master today?*",
    ];
  }

  return [
    `Let's break down **"${cleanPrompt}"** from first principles:`,
    "\n\n### 1. Definition & Core Meaning",
    `\n**"${cleanPrompt}"** represents a foundational concept in its respective domain. To understand it clearly, we examine its definition, primary characteristics, and operational context.`,
    "\n\n### 2. Key Components & Mechanics",
    "\n• **Primary Attributes:** Identify the core properties and distinguishing features.",
    "\n• **Contextual Relationship:** Understand how this concept connects to related principles.",
    "\n• **Practical Application:** Observe how it is used in problem-solving and real-world scenarios.",
    "\n\n### 3. Summary & Socratic Verification",
    "\nUnderstanding the fundamental definition allows us to apply this concept accurately across varied contexts.",
    `\n\n*Socratic Question:* How would you explain "${cleanPrompt}" in your own words?`,
  ];
}
