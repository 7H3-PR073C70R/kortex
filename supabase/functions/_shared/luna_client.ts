/**
 * Luna LLM Client & Distributed AI Gateway
 * ========================================
 * High-reliability multi-provider AI routing infrastructure for Kortex.
 *
 * Distributes workload across free tier providers according to capacity:
 * 1. Groq Free Tier (1,000 requests/day, weight: 10)
 * 2. OpenRouter Free Tier (1,000 requests/day, weight: 10)
 * 3. Gemini Free Tier (1,500 requests/day, weight: 15)
 *
 * Implements "always-routing" failover cascade:
 * If the primary provider hits a rate limit (429) or fails, the router
 * automatically fails over to the remaining providers before giving up.
 * Never generates fake dummy responses — reports true errors when unavailable.
 */

export type AiProviderId = "groq" | "openrouter" | "gemini";

export interface LunaMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface LunaRequestOptions {
  messages: LunaMessage[];
  temperature?: number;
  maxTokens?: number;
  responseFormat?: { type: "json_object" };
  stream?: boolean;
  preferredProvider?: AiProviderId;
}

export interface LunaCardOutput {
  front: string;
  back: string;
  latex_content?: string | null;
  explanation?: string | null;
  hints?: string | null;
  tags?: string[];
  image_url?: string | null;
  confidence_score?: number;
}

export interface AiProviderConfig {
  id: AiProviderId;
  name: string;
  weight: number;
  dailyCapacity: number;
  apiKey: string;
  model: string;
  endpoint: string;
  type: "openai" | "gemini-interactions";
  timeoutMs: number;
}

interface ProviderRuntimeState {
  cooldownUntil: number;
  failureCount: number;
  successCount: number;
  lastError?: string;
}

function getEnv(key: string): string | undefined {
  if (typeof Deno !== "undefined" && Deno.env?.get) {
    return Deno.env.get(key);
  }
  if (typeof process !== "undefined" && process.env) {
    return process.env[key];
  }
  return undefined;
}

// In-memory runtime state per execution context
const providerStates: Record<AiProviderId, ProviderRuntimeState> = {
  groq: { cooldownUntil: 0, failureCount: 0, successCount: 0 },
  openrouter: { cooldownUntil: 0, failureCount: 0, successCount: 0 },
  gemini: { cooldownUntil: 0, failureCount: 0, successCount: 0 },
};

export class LunaClient {
  private activeProviderName = "Luna Gateway (Multi-Provider)";
  private activeModelName = "gpt-oss / gemini-3.8-flash";
  public lastAttemptErrors: string[] = [];

  constructor() {
    this.refreshActiveNames();
  }

  private refreshActiveNames(): void {
    const providers = this.getAvailableProviders();
    if (providers.length > 0) {
      this.activeProviderName = providers.map((p) => p.name).join(" / ");
      this.activeModelName = providers.map((p) => p.model).join(" | ");
    }
  }

  /**
   * Returns whether at least one AI provider is configured with credentials.
   */
  isConfigured(): boolean {
    return this.getAvailableProviders().length > 0;
  }

  get modelName(): string {
    return this.activeModelName;
  }

  get providerName(): string {
    return this.activeProviderName;
  }

  /**
   * Returns all provider configurations with resolved keys and endpoints.
   */
  private getAvailableProviders(): AiProviderConfig[] {
    const groqKey = getEnv("GROQ_API_KEY") || "";
    const openRouterKey = getEnv("OPENROUTER_API_KEY") || "";
    const geminiKey = getEnv("GEMINI_API_KEY") || "";

    const configs: AiProviderConfig[] = [
      {
        id: "groq",
        name: "Groq Cloud (Free Tier)",
        weight: 10, // ~1,000 requests/day
        dailyCapacity: 1000,
        apiKey: groqKey,
        model: getEnv("GROQ_MODEL") || "openai/gpt-oss-20b",
        endpoint:
          getEnv("GROQ_BASE_URL") ||
          "https://api.groq.com/openai/v1/chat/completions",
        type: "openai",
        timeoutMs: 30000,
      },
      {
        id: "openrouter",
        name: "OpenRouter (Free Tier)",
        weight: 10, // ~1,000 requests/day
        dailyCapacity: 1000,
        apiKey: openRouterKey,
        model: getEnv("OPENROUTER_MODEL") || "openrouter/free",
        endpoint:
          getEnv("OPENROUTER_BASE_URL") ||
          "https://openrouter.ai/api/v1/chat/completions",
        type: "openai",
        timeoutMs: 35000,
      },
      {
        id: "gemini",
        name: "Google Gemini Studio (Free Tier)",
        weight: 15, // ~1,500 requests/day
        dailyCapacity: 1500,
        apiKey: geminiKey,
        model: getEnv("GEMINI_MODEL") || "gemini-3.1-flash-lite",
        endpoint:
          getEnv("GEMINI_BASE_URL") ||
          "https://generativelanguage.googleapis.com/v1beta/interactions",
        type: "gemini-interactions",
        timeoutMs: 30000,
      },
    ];

    // Filter to only configured providers
    return configs.filter((c) => Boolean(c.apiKey && c.apiKey.trim().length > 0));
  }

  /**
   * Selects the ordered candidate list of providers for a request.
   * Workload is distributed across providers based on their capacity ratio.
   * If a provider is cooling down, healthy providers take precedence.
   */
  private getOrderedProviders(preferredProvider?: AiProviderId): AiProviderConfig[] {
    const configured = this.getAvailableProviders();
    if (configured.length === 0) {
      throw new Error(
        "No AI cloud providers configured. Please set GROQ_API_KEY, OPENROUTER_API_KEY, or GEMINI_API_KEY."
      );
    }

    if (preferredProvider) {
      const preferred = configured.find((p) => p.id === preferredProvider);
      if (preferred) {
        const others = configured.filter((p) => p.id !== preferredProvider);
        return [preferred, ...others];
      }
    }

    const now = Date.now();
    const healthy = configured.filter(
      (p) => (providerStates[p.id]?.cooldownUntil ?? 0) <= now
    );
    const candidatePool = healthy.length > 0 ? healthy : configured;

    // Weighted random selection based on daily capacity
    const totalWeight = candidatePool.reduce((acc, p) => acc + p.weight, 0);
    let randomRoll = Math.random() * totalWeight;
    let primaryIndex = 0;
    for (let i = 0; i < candidatePool.length; i++) {
      if (randomRoll < candidatePool[i].weight) {
        primaryIndex = i;
        break;
      }
      randomRoll -= candidatePool[i].weight;
    }

    const primary = candidatePool[primaryIndex];
    // Remaining providers ordered by weight descending for failover
    const remaining = configured
      .filter((p) => p.id !== primary.id)
      .sort((a, b) => b.weight - a.weight);

    return [primary, ...remaining];
  }

  private recordSuccess(provider: AiProviderConfig): void {
    const state = providerStates[provider.id];
    if (state) {
      state.failureCount = 0;
      state.successCount++;
      state.cooldownUntil = 0;
    }
  }

  private recordFailure(
    provider: AiProviderConfig,
    error: any,
    statusCode?: number
  ): void {
    const state = providerStates[provider.id];
    const errMsg = error?.message ?? String(error);
    if (state) {
      state.failureCount++;
      state.lastError = errMsg;
      // If 429 (rate limit / quota exceeded), cooldown for 60 seconds
      if (statusCode === 429 || errMsg.includes("429") || errMsg.includes("quota")) {
        state.cooldownUntil = Date.now() + 60000;
        console.warn(
          `[LunaGateway] Provider ${provider.name} rate-limited (429). Setting 60s cooldown.`
        );
      } else if (statusCode === 503 || statusCode === 504 || errMsg.includes("timeout")) {
        state.cooldownUntil = Date.now() + 30000;
        console.warn(
          `[LunaGateway] Provider ${provider.name} unavailable (${statusCode || "timeout"}). Setting 30s cooldown.`
        );
      } else {
        state.cooldownUntil = Date.now() + 15000;
      }
    }
  }

  /**
   * Executes completion with distributed routing and automatic failover cascade.
   */
  async complete(options: LunaRequestOptions): Promise<string> {
    const providers = this.getOrderedProviders(options.preferredProvider);
    const errors: string[] = [];

    for (const provider of providers) {
      try {
        console.log(
          `[LunaGateway] Routing completion to ${provider.name} (${provider.model})...`
        );
        const result = await this.executeProviderCompletion(provider, options);
        if (result && result.trim().length > 0) {
          this.recordSuccess(provider);
          this.activeModelName = provider.model;
          this.activeProviderName = provider.name;
          return result;
        }
        throw new Error(`${provider.name} returned an empty response`);
      } catch (err: any) {
        const errMsg = err?.message ?? String(err);
        this.recordFailure(provider, err, err?.status);
        errors.push(`${provider.name}: ${errMsg}`);
        console.warn(
          `[LunaGateway] ${provider.name} failed: ${errMsg}. Always-routing to next provider...`
        );
      }
    }

    this.lastAttemptErrors = errors;
    throw new Error(
      `All cloud AI providers failed to generate response: [${errors.join("; ")}]`
    );
  }

  /**
   * Dispatches completion request to specific provider implementation.
   */
  private async executeProviderCompletion(
    provider: AiProviderConfig,
    options: LunaRequestOptions
  ): Promise<string> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), provider.timeoutMs);

    try {
      if (provider.type === "openai") {
        const payload: Record<string, unknown> = {
          model: provider.model,
          messages: options.messages.map((m) => ({
            role: m.role,
            content: m.content,
          })),
          temperature: options.temperature ?? 0.3,
        };

        if (options.maxTokens) {
          payload.max_tokens = options.maxTokens;
        }

        if (options.responseFormat?.type === "json_object") {
          // OpenRouter free models vary; to ensure 100% reliability, only attach OpenAI
          // json_object schema when supported, relying on prompt structuring for all
          if (provider.id !== "openrouter") {
            payload.response_format = { type: "json_object" };
          }
        }

        const headers: Record<string, string> = {
          "Content-Type": "application/json",
          Authorization: `Bearer ${provider.apiKey}`,
        };

        if (provider.id === "openrouter") {
          headers["HTTP-Referer"] = "https://kortex.app";
          headers["X-Title"] = "Kortex Education";
        }

        const response = await fetch(provider.endpoint, {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          const error: any = new Error(
            `HTTP ${response.status} ${response.statusText}: ${errText.slice(0, 300)}`
          );
          error.status = response.status;
          throw error;
        }

        const json = await response.json();
        const content =
          json.choices?.[0]?.message?.content ??
          json.choices?.[0]?.text ??
          "";

        return content;
      } else {
        // Gemini Interactions API format
        let promptText = options.messages
          .map((m) => {
            if (m.role === "system") return `[System Instructions]\n${m.content}`;
            if (m.role === "user") return `User: ${m.content}`;
            return `Assistant: ${m.content}`;
          })
          .join("\n\n");

        if (options.responseFormat?.type === "json_object") {
          promptText +=
            "\n\nCRITICAL: You must output ONLY a single valid raw JSON object. Do not wrap in markdown or include conversational text.";
        }

        const payload = {
          model: provider.model,
          input: promptText,
          stream: false,
        };

        let response = await fetch(provider.endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": provider.apiKey,
            "Api-Revision": "2026-05-20",
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        // If Gemini is experiencing temporary high demand (503) or per-model rate limit (429), attempt immediate fallback model
        if (
          !response.ok &&
          (response.status === 503 || response.status === 429) &&
          payload.model === "gemini-3.8-flash"
        ) {
          console.warn(
            `[LunaGateway] gemini-3.8-flash returned ${response.status}. Retrying with alternate model gemini-3.7-flash...`
          );
          payload.model = "gemini-3.7-flash";
          response = await fetch(provider.endpoint, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": provider.apiKey,
              "Api-Revision": "2026-05-20",
            },
            body: JSON.stringify(payload),
            signal: controller.signal,
          });
        }

        if (!response.ok) {
          const errText = await response.text().catch(() => "");
          const error: any = new Error(
            `HTTP ${response.status} ${response.statusText}: ${errText.slice(0, 300)}`
          );
          error.status = response.status;
          throw error;
        }

        const json = await response.json();
        let content = "";

        if (Array.isArray(json.steps)) {
          for (const step of json.steps) {
            if (step.type === "model_output" && Array.isArray(step.content)) {
              for (const item of step.content) {
                if (item.type === "text" && typeof item.text === "string") {
                  content += item.text;
                }
              }
            }
          }
        }

        if (!content && json.output) {
          if (typeof json.output === "string") content = json.output;
          else if (Array.isArray(json.output)) {
            const msg = json.output.find((i: any) => i.type === "message");
            content = msg?.content?.[0]?.text ?? "";
          }
        }

        return content;
      }
    } finally {
      clearTimeout(timeoutId);
    }
  }

  /**
   * Initiates an SSE streaming connection with distributed routing and failover.
   * Returns a standard OpenAI SSE stream (`data: {"choices":[{"delta":{"content":"..."}}]}`)
   * regardless of which underlying provider is serving the request.
   */
  async stream(options: LunaRequestOptions): Promise<ReadableStream<Uint8Array>> {
    const providers = this.getOrderedProviders(options.preferredProvider);
    const errors: string[] = [];

    for (const provider of providers) {
      try {
        console.log(
          `[LunaGateway] Routing stream to ${provider.name} (${provider.model})...`
        );
        const stream = await this.executeProviderStream(provider, options);
        this.recordSuccess(provider);
        this.activeModelName = provider.model;
        this.activeProviderName = provider.name;
        return stream;
      } catch (err: any) {
        const errMsg = err?.message ?? String(err);
        this.recordFailure(provider, err, err?.status);
        errors.push(`${provider.name}: ${errMsg}`);
        console.warn(
          `[LunaGateway] Stream connection failed on ${provider.name}: ${errMsg}. Always-routing to next provider...`
        );
      }
    }

    this.lastAttemptErrors = errors;
    throw new Error(
      `All cloud AI providers failed to initiate stream: [${errors.join("; ")}]`
    );
  }

  /**
   * Opens raw stream from provider and normalizes it to standard OpenAI SSE.
   */
  private async executeProviderStream(
    provider: AiProviderConfig,
    options: LunaRequestOptions
  ): Promise<ReadableStream<Uint8Array>> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 20000); // 20s connection timeout

    try {
      if (provider.type === "openai") {
        const payload: Record<string, unknown> = {
          model: provider.model,
          messages: options.messages.map((m) => ({
            role: m.role,
            content: m.content,
          })),
          temperature: options.temperature ?? 0.6,
          stream: true,
        };

        const headers: Record<string, string> = {
          "Content-Type": "application/json",
          Authorization: `Bearer ${provider.apiKey}`,
        };

        if (provider.id === "openrouter") {
          headers["HTTP-Referer"] = "https://kortex.app";
          headers["X-Title"] = "Kortex Education";
        }

        const response = await fetch(provider.endpoint, {
          method: "POST",
          headers,
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        if (!response.ok || !response.body) {
          const errText = await response.text().catch(() => "");
          const error: any = new Error(
            `HTTP ${response.status} ${response.statusText}: ${errText.slice(0, 300)}`
          );
          error.status = response.status;
          throw error;
        }

        clearTimeout(timeoutId);
        return response.body;
      } else {
        // Gemini Interactions API Streaming
        let promptText = options.messages
          .map((m) => {
            if (m.role === "system") return `[System Instructions]\n${m.content}`;
            if (m.role === "user") return `User: ${m.content}`;
            return `Assistant: ${m.content}`;
          })
          .join("\n\n");

        const payload = {
          model: provider.model,
          input: promptText,
          stream: true,
        };

        let response = await fetch(provider.endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": provider.apiKey,
            "Api-Revision": "2026-05-20",
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        // If Gemini returns 503 or 429 during stream setup, retry with gemini-3.7-flash
        if (
          !response.ok &&
          (response.status === 503 || response.status === 429) &&
          payload.model === "gemini-3.8-flash"
        ) {
          console.warn(
            `[LunaGateway] gemini-3.8-flash returned ${response.status} on stream init. Retrying with gemini-3.7-flash...`
          );
          payload.model = "gemini-3.7-flash";
          response = await fetch(provider.endpoint, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": provider.apiKey,
              "Api-Revision": "2026-05-20",
            },
            body: JSON.stringify(payload),
            signal: controller.signal,
          });
        }

        if (!response.ok || !response.body) {
          const errText = await response.text().catch(() => "");
          const error: any = new Error(
            `HTTP ${response.status} ${response.statusText}: ${errText.slice(0, 300)}`
          );
          error.status = response.status;
          throw error;
        }

        clearTimeout(timeoutId);

        // Normalize Gemini SSE into standard OpenAI SSE format
        return this.normalizeGeminiStreamToOpenAi(response.body);
      }
    } catch (e) {
      clearTimeout(timeoutId);
      throw e;
    }
  }

  /**
   * Adapts Gemini interaction SSE events (`step.delta` -> text) to OpenAI format:
   * `data: {"choices":[{"delta":{"content":"..."}}]}\n\n`
   */
  private normalizeGeminiStreamToOpenAi(
    geminiBody: ReadableStream<Uint8Array>
  ): ReadableStream<Uint8Array> {
    const reader = geminiBody.getReader();
    const decoder = new TextDecoder();
    const encoder = new TextEncoder();
    let buffer = "";

    return new ReadableStream<Uint8Array>({
      async pull(controller) {
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) {
              controller.enqueue(encoder.encode("data: [DONE]\n\n"));
              controller.close();
              return;
            }

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed || trimmed.startsWith(":")) continue;

              if (
                trimmed === "data: [DONE]" ||
                trimmed === "event: interaction.completed" ||
                trimmed === "event: done" ||
                trimmed.includes('"status":"completed"') ||
                trimmed.includes('"event_type":"interaction.completed"')
              ) {
                controller.enqueue(encoder.encode("data: [DONE]\n\n"));
                controller.close();
                return;
              }

              if (trimmed.startsWith("data:")) {
                const jsonStr = trimmed.replace(/^data:\s*/, "");
                try {
                  const parsed = JSON.parse(jsonStr);
                  if (
                    parsed.status === "completed" ||
                    parsed.event_type === "interaction.completed"
                  ) {
                    controller.enqueue(encoder.encode("data: [DONE]\n\n"));
                    controller.close();
                    return;
                  }

                  const deltaText =
                    parsed.delta?.text ??
                    parsed.text ??
                    "";

                  if (deltaText) {
                    const openAiChunk = `data: ${JSON.stringify({
                      choices: [
                        {
                          delta: { content: deltaText },
                          index: 0,
                          finish_reason: null,
                        },
                      ],
                    })}\n\n`;
                    controller.enqueue(encoder.encode(openAiChunk));
                  }
                } catch {
                  // Skip non-JSON heartbeats
                }
              }
            }
          }
        } catch (err) {
          controller.error(err);
        }
      },
      cancel() {
        reader.cancel();
      },
    });
  }

  /**
   * Higher-level helper to generate structured flashcard arrays from content.
   * Leverages multi-provider distributed routing.
   */
  async generateFlashcardsFromSemanticMapping(params: {
    content: string;
    topic: string;
    courseCode?: string;
    availableImages?: Array<{ url: string; label: string }>;
    cardCountHint?: number;
  }): Promise<LunaCardOutput[]> {
    const { content, topic, courseCode, availableImages = [], cardCountHint } = params;

    const imageContext =
      availableImages.length > 0
        ? `AVAILABLE VISUAL DIAGRAMS / FIGURES IN THIS DOCUMENT:
${availableImages.map((img, i) => `- Diagram [${i + 1}]: URL: "${img.url}" | Context/Label: "${img.label}"`).join("\n")}

MULTIMODAL DIAGRAM INSTRUCTION:
Only assign an image URL to a flashcard if the card directly discusses, questions, or visually explains that specific diagram. For all general conceptual, architectural, mathematical, code, or definition cards that do not require this diagram, you MUST set "image_url" to null. Never arbitrarily attach diagrams to unrelated cards.`
        : "No embedded diagrams available. Set 'image_url' to null for all cards.";

    const systemPrompt = `You are an advanced pedagogical AI tutor specializing in synthesizing rigorous, high-yield flashcards for students.
Your task is to analyze the provided study document content and perform deep semantic mapping into active-recall flashcards.

PEDAGOGICAL & FORMATTING RULES:
1. FRONT: Clear, specific active-recall question, concept query, or rule prompt. Do not ask vague questions.
2. BACK: Comprehensive, precise definition, explanation, step-by-step mechanism, or complete answer. When presenting multi-step procedures, checklists, criteria, or lists of points (e.g. 1 to 8), format each point on its own new line with clear numbering (1., 2., etc.) or bullet points. NEVER squash multiple numbered points into a single run-on paragraph.
3. LATEX_CONTENT: If the card involves mathematical formulas, equations, limits, fractions, or physics/chemistry formulas, provide valid raw LaTeX notation without enclosing $$ or \\(\\) delimiters (e.g., "\\text{RR} = \\frac{\\text{Potential Reward}}{\\text{Potential Risk}}" or "E = mc^2"). If none, set to null.
4. EXPLANATION / HINTS: A concise mnemonic, key takeaway, or memory hint.
5. TAGS: Array of 1-3 strings categorizing this card (e.g. ["${topic}", "${courseCode || "General"}"]).
6. IMAGE_URL: Only assign an image URL if the card directly questions, explains, or interprets that specific visual diagram. For all other conceptual, textual, code, or definition cards, you MUST set 'image_url' to null. Do NOT arbitrarily attach images to unrelated cards.
7. CODE BLOCKS: Whenever code, syntax, algorithms, or programming snippets are queried or explained (in either FRONT or BACK), format them cleanly using standard markdown code fences with language identifiers (e.g., \`\`\`dart\nvoid main() {\n  runApp(const MyApp());\n}\n\`\`\`, \`\`\`python\n...\n\`\`\`). Preserve standard indentation and line breaks. Never collapse code snippets into a single unbroken line.
8. COMPREHENSIVE COVERAGE: ${cardCountHint ? `Target roughly ${cardCountHint} high-yield cards.` : "Cover every key concept, formula, rule, and definition without omitting important sections."}

${imageContext}

OUTPUT FORMAT:
Return a valid JSON object containing a "cards" array with the flashcard objects:
{
  "cards": [
    {
      "front": "string",
      "back": "string",
      "latex_content": "string or null",
      "explanation": "string or null",
      "hints": "string or null",
      "tags": ["string"],
      "image_url": "string or null",
      "confidence_score": 0.98
    }
  ]
}`;

    const userPrompt = `DOCUMENT TOPIC: ${topic}
COURSE: ${courseCode || "General"}

DOCUMENT BODY:
${content.length > 50000 ? content.slice(0, 50000) : content}

Generate the JSON object with the "cards" array now:`;

    const rawResponse = await this.complete({
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.2,
      responseFormat: { type: "json_object" },
    });

    return this.parseCardsFromJson(rawResponse, topic);
  }

  /**
   * Safely parses JSON array of flashcards from model response.
   */
  parseCardsFromJson(rawText: string, fallbackTopic: string): LunaCardOutput[] {
    const cleaned = rawText
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/, "")
      .replace(/```$/, "")
      .trim();

    try {
      const parsed = JSON.parse(cleaned);
      const rawList = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed.cards)
        ? parsed.cards
        : Array.isArray(parsed.flashcards)
        ? parsed.flashcards
        : Array.isArray(parsed.items)
        ? parsed.items
        : [];

      const cards: LunaCardOutput[] = [];
      for (const item of rawList) {
        const front = item.front || item.question || item.topic;
        const back = item.back || item.answer || item.raw_text;
        if (front && back && String(front).trim().length > 3) {
          cards.push({
            front: String(front).trim(),
            back: String(back).trim(),
            latex_content: item.latex_content ?? item.latex ?? null,
            explanation: item.explanation ?? item.hints ?? null,
            hints: item.hints ?? item.explanation ?? null,
            tags:
              Array.isArray(item.tags) && item.tags.length > 0
                ? item.tags.map(String)
                : [fallbackTopic],
            image_url: item.image_url ?? null,
            confidence_score:
              typeof item.confidence_score === "number"
                ? item.confidence_score
                : 0.98,
          });
        }
      }

      return cards;
    } catch (err) {
      console.warn(
        "[LunaGateway] Direct JSON parse failed, attempting line-by-line extraction:",
        err
      );
      return this.parseNdjsonFallback(cleaned, fallbackTopic);
    }
  }

  private parseNdjsonFallback(text: string, fallbackTopic: string): LunaCardOutput[] {
    const cards: LunaCardOutput[] = [];
    const lines = text.split("\n");

    for (const line of lines) {
      const trimmed = line.trim().replace(/^,\s*/, "");
      if (!trimmed.startsWith("{")) continue;
      try {
        const item = JSON.parse(trimmed);
        const front = item.front || item.question || item.topic;
        const back = item.back || item.answer || item.raw_text;
        if (front && back) {
          cards.push({
            front: String(front).trim(),
            back: String(back).trim(),
            latex_content: item.latex_content ?? null,
            explanation: item.explanation ?? item.hints ?? null,
            hints: item.hints ?? null,
            tags: Array.isArray(item.tags) ? item.tags : [fallbackTopic],
            image_url: item.image_url ?? null,
            confidence_score: 0.95,
          });
        }
      } catch (_) {}
    }

    return cards;
  }
}
