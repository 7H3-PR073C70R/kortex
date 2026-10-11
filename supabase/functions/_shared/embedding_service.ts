/**
 * Kortex Vector Embedding Service
 * ===============================
 * Generates genuine 1536-dimensional semantic embeddings for study document chunks
 * and RAG semantic search.
 *
 * Supported Providers (in priority order):
 * 1. OpenAI (text-embedding-3-small, 1536 dimensions) via OPENAI_API_KEY
 * 2. OpenRouter (openai/text-embedding-3-small, 1536 dimensions) via OPENROUTER_API_KEY
 * 3. Gemini (text-embedding-004 with 1536 outputDimensionality) via GEMINI_API_KEY
 *
 * Graceful Degradation:
 * If no provider API key is configured or the embedding network request fails,
 * this service returns `null`. It NEVER produces pseudo-random character hashes,
 * ensuring pgvector cosine indexes are never contaminated with garbage data.
 */

// Helper to access Deno.env safely in both Deno and Node test environments
function getEnv(key: string): string | undefined {
  if (typeof Deno !== "undefined" && Deno.env) {
    return Deno.env.get(key) || undefined;
  }
  if (typeof process !== "undefined" && process.env) {
    return process.env[key] || undefined;
  }
  return undefined;
}

export const EMBEDDING_DIMENSION = 1536;
const MAX_BATCH_SIZE = 64;

interface OpenAIEmbeddingResponse {
  data?: Array<{
    embedding: number[];
    index: number;
  }>;
  error?: {
    message: string;
  };
}

interface GeminiBatchEmbeddingResponse {
  embeddings?: Array<{
    values: number[];
  }>;
  error?: {
    message: string;
  };
}

/**
 * Computes semantic vector embeddings for a list of text strings.
 * Returns an array of 1536-dim vector arrays, or null if embeddings are unavailable.
 */
export async function getBatchEmbeddings(
  texts: string[]
): Promise<Array<number[] | null> | null> {
  if (!texts || texts.length === 0) {
    return [];
  }

  const openaiKey = getEnv("OPENAI_API_KEY");
  const openRouterKey = getEnv("OPENROUTER_API_KEY");
  const geminiKey = getEnv("GEMINI_API_KEY");

  // 1. Try OpenAI text-embedding-3-small
  if (openaiKey) {
    const result = await fetchOpenAIEmbeddings(texts, openaiKey, "https://api.openai.com/v1/embeddings");
    if (result) return result;
  }

  // 2. Try OpenRouter text-embedding-3-small
  if (openRouterKey) {
    const result = await fetchOpenAIEmbeddings(
      texts,
      openRouterKey,
      "https://openrouter.ai/api/v1/embeddings",
      "openai/text-embedding-3-small"
    );
    if (result) return result;
  }

  // 3. Try Gemini text-embedding-004
  if (geminiKey) {
    const result = await fetchGeminiEmbeddings(texts, geminiKey);
    if (result) return result;
  }

  console.warn(
    "[EmbeddingService] No active embedding provider configured (OPENAI_API_KEY, OPENROUTER_API_KEY, or GEMINI_API_KEY). " +
      "Returning null embeddings to avoid contaminating pgvector with pseudo-random vectors."
  );
  return null;
}

/**
 * Computes a single semantic embedding for a query text.
 */
export async function getSingleEmbedding(text: string): Promise<number[] | null> {
  const trimmed = text.trim();
  if (!trimmed) return null;

  const batch = await getBatchEmbeddings([trimmed]);
  if (!batch || batch.length === 0) return null;
  return batch[0];
}

async function fetchOpenAIEmbeddings(
  texts: string[],
  apiKey: string,
  endpoint: string,
  model = "text-embedding-3-small"
): Promise<Array<number[] | null> | null> {
  try {
    const sanitizedTexts = texts.map((t) => t.trim().slice(0, 8000));
    const allEmbeddings: Array<number[] | null> = [];

    // Chunk requests into batches of MAX_BATCH_SIZE to avoid payload limits
    for (let i = 0; i < sanitizedTexts.length; i += MAX_BATCH_SIZE) {
      const chunk = sanitizedTexts.slice(i, i + MAX_BATCH_SIZE);

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 20000);

      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          input: chunk,
          dimensions: EMBEDDING_DIMENSION,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.warn(`[EmbeddingService] ${model} request failed with ${response.status}: ${errText}`);
        return null;
      }

      const json: OpenAIEmbeddingResponse = await response.json();
      if (!json.data || !Array.isArray(json.data)) {
        console.warn(`[EmbeddingService] Malformed response from ${endpoint}:`, json.error?.message);
        return null;
      }

      // Sort by index to preserve input ordering
      const sorted = json.data.sort((a, b) => a.index - b.index);
      for (const item of sorted) {
        allEmbeddings.push(item.embedding);
      }
    }

    return allEmbeddings;
  } catch (err) {
    console.warn(`[EmbeddingService] Error fetching embeddings from ${endpoint}:`, err);
    return null;
  }
}

async function fetchGeminiEmbeddings(
  texts: string[],
  apiKey: string
): Promise<Array<number[] | null> | null> {
  try {
    const sanitizedTexts = texts.map((t) => t.trim().slice(0, 8000));
    const allEmbeddings: Array<number[] | null> = [];

    for (let i = 0; i < sanitizedTexts.length; i += MAX_BATCH_SIZE) {
      const chunk = sanitizedTexts.slice(i, i + MAX_BATCH_SIZE);

      const requests = chunk.map((text) => ({
        model: "models/text-embedding-004",
        content: {
          parts: [{ text }],
        },
        outputDimensionality: EMBEDDING_DIMENSION,
      }));

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 20000);

      const url = `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:batchEmbedContents?key=${apiKey}`;
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ requests }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.warn(`[EmbeddingService] Gemini embedding request failed: ${errText}`);
        return null;
      }

      const json: GeminiBatchEmbeddingResponse = await response.json();
      if (!json.embeddings || !Array.isArray(json.embeddings)) {
        return null;
      }

      for (const item of json.embeddings) {
        let values = item.values;
        // If Gemini returns 768-dim, pad/normalize to 1536
        if (values.length < EMBEDDING_DIMENSION) {
          const padded = new Array(EMBEDDING_DIMENSION).fill(0);
          for (let k = 0; k < values.length; k++) {
            padded[k] = values[k];
          }
          values = padded;
        } else if (values.length > EMBEDDING_DIMENSION) {
          values = values.slice(0, EMBEDDING_DIMENSION);
        }
        allEmbeddings.push(values);
      }
    }

    return allEmbeddings;
  } catch (err) {
    console.warn("[EmbeddingService] Error fetching Gemini embeddings:", err);
    return null;
  }
}
