/**
 * Luna LLM Client
 * ===============
 * The unified, sole LLM client for Kortex backend services.
 * Connects to Luna endpoint to perform semantic mapping,
 * flashcard generation, tutoring, and quiz synthesis.
 */

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

export class LunaClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly model: string;

  constructor() {
    this.apiKey =
      Deno.env.get("LUNA_API_KEY") ||
      Deno.env.get("OPENAI_API_KEY") ||
      "";
    this.baseUrl =
      Deno.env.get("LUNA_BASE_URL") || "https://api.openai.com/v1/responses";
    this.model = Deno.env.get("LUNA_MODEL") || "gpt-5.6-luna";
  }

  /**
   * Returns whether Luna credentials/endpoints are configured.
   */
  isConfigured(): boolean {
    return Boolean(this.apiKey && this.baseUrl);
  }

  get modelName(): string {
    return this.model;
  }

  /**
   * Resolves the full URL for responses endpoint.
   */
  private getEndpointUrl(): string {
    return this.baseUrl.replace(/\/+$/, "");
  }

  /**
   * Executes a completion request with Luna (gpt-5.6-luna on /v1/responses).
   */
  async complete(options: LunaRequestOptions): Promise<string> {
    const url = this.getEndpointUrl();

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${this.apiKey}`,
    };

    const payload: Record<string, unknown> = {
      model: this.model,
      input: options.messages.map((m) => ({
        role: m.role,
        content: m.content,
      })),
      store: true,
    };

    // Note: gpt-5.6-luna reasoning models reject the 'temperature' parameter.
    if (options.temperature !== undefined && !this.model.includes("gpt-5")) {
      payload["temperature"] = options.temperature;
    }

    console.log(`[LunaClient] Requesting completion from ${url} (model: ${this.model})...`);

    const response = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      throw new Error(
        `Luna API error (${response.status} ${response.statusText}): ${errText || "No error details returned"}`
      );
    }

    const json = await response.json();

    let content = "";
    if (Array.isArray(json.output)) {
      const messageItem = json.output.find((item: any) => item.type === "message");
      if (messageItem && Array.isArray(messageItem.content)) {
        const textPart = messageItem.content.find(
          (c: any) => c.type === "output_text" || typeof c.text === "string"
        );
        content = textPart?.text ?? "";
      }
    }

    if (!content) {
      content =
        json.choices?.[0]?.message?.content ??
        json.choices?.[0]?.text ??
        json.content ??
        "";
    }

    if (!content) {
      throw new Error("Luna returned an empty response");
    }

    return content;
  }

  /**
   * Initiates an SSE streaming completion request with Luna.
   */
  async stream(options: LunaRequestOptions): Promise<ReadableStream<Uint8Array>> {
    const url = this.getEndpointUrl();

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    if (this.apiKey) {
      headers["Authorization"] = `Bearer ${this.apiKey}`;
      headers["x-api-key"] = this.apiKey;
    }

    const payload: Record<string, unknown> = {
      model: this.model,
      input: options.messages.map((m) => ({
        role: m.role,
        content: m.content,
      })),
      stream: true,
      store: true,
    };

    if (options.temperature !== undefined && !this.model.includes("gpt-5")) {
      payload["temperature"] = options.temperature;
    }

    console.log(`[LunaClient] Initiating stream from ${url} (model: ${this.model})...`);

    const response = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok || !response.body) {
      const errText = await response.text().catch(() => "");
      throw new Error(
        `Luna stream error (${response.status} ${response.statusText}): ${errText || "No body returned"}`
      );
    }

    return response.body;
  }

  /**
   * Higher-level helper to generate structured flashcard arrays from content.
   */
  async generateFlashcardsFromSemanticMapping(params: {
    content: string;
    topic: string;
    courseCode?: string;
    availableImages?: Array<{ url: string; label: string }>;
    cardCountHint?: number;
  }): Promise<LunaCardOutput[]> {
    const { content, topic, courseCode, availableImages = [], cardCountHint } = params;

    const imageContext = availableImages.length > 0
      ? `AVAILABLE VISUAL DIAGRAMS / FIGURES IN THIS DOCUMENT:
${availableImages.map((img, i) => `- Diagram [${i + 1}]: URL: "${img.url}" | Context/Label: "${img.label}"`).join("\n")}

CRITICAL MULTIMODAL INSTRUCTION:
This document contains ${availableImages.length} visual diagrams/figures. For EVERY diagram in this list, you MUST create at least one dedicated active-recall card whose concept, question, or explanation directly analyzes that visual figure, and assign its exact URL to the "image_url" field! Ensure all ${availableImages.length} diagrams are utilized across the flashcard set.`
      : "No embedded diagrams available. Set 'image_url' to null for all cards.";

    const systemPrompt = `You are Luna, an advanced pedagogical AI tutor specializing in synthesizing rigorous, high-yield flashcards for students.
Your task is to analyze the provided study document content and perform deep semantic mapping into active-recall flashcards.

PEDAGOGICAL & FORMATTING RULES:
1. FRONT: Clear, specific active-recall question, concept query, or rule prompt. Do not ask vague questions.
2. BACK: Comprehensive, precise definition, explanation, step-by-step mechanism, or complete answer.
3. LATEX_CONTENT: If the card involves mathematical formulas, equations, limits, fractions, or physics/chemistry formulas, provide valid LaTeX notation (e.g., "$$E = mc^2$$" or "\\(\\frac{a}{b}\\)"). If none, set to null.
4. EXPLANATION / HINTS: A concise mnemonic, key takeaway, or memory hint.
5. TAGS: Array of 1-3 strings categorizing this card (e.g. ["${topic}", "${courseCode || "General"}"]).
6. IMAGE_URL: When a card describes, explains, or references a visual diagram from the available figures, assign its EXACT URL string. Ensure every provided diagram is assigned to its relevant card. If a card does not use a diagram, set to null.
7. COMPREHENSIVE COVERAGE: ${cardCountHint ? `Target roughly ${cardCountHint} high-yield cards.` : "Cover every key concept, formula, rule, and definition without omitting important sections."}

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
${content.length > 60000 ? content.slice(0, 60000) : content}

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
            tags: Array.isArray(item.tags) && item.tags.length > 0
              ? item.tags.map(String)
              : [fallbackTopic],
            image_url: item.image_url ?? null,
            confidence_score: typeof item.confidence_score === "number" ? item.confidence_score : 0.98,
          });
        }
      }

      return cards;
    } catch (err) {
      console.warn("[LunaClient] Direct JSON parse failed, attempting line-by-line extraction:", err);
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
