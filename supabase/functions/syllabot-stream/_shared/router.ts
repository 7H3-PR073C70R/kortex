export interface Message {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface ModelSelectionResult {
  model: string;
  reasoning_effort?: "high" | "medium" | "low";
  reasoningDetected: boolean;
  matchedCriteria?: string[];
}

export interface RouterOptions {
  forceModel?: string;
  defaultModel?: string;
  proModel?: string;
  userTier?: "free" | "pro";
}

export const FREE_MODEL_WHITELIST = [
  "llama-3.3-70b-versatile",
  "gemini-2.0-flash",
  "gemini-3.1-flash-lite",
  "gpt-oss-20b",
  "openrouter/free",
  "luna",
];

export const PRO_REASONING_MODELS = [
  "deepseek/deepseek-r1",
  "deepseek-reasoner",
  "openai/o1",
  "openai/o3-mini",
  "gemini-2.0-pro-exp",
  "anthropic/claude-3.5-sonnet",
];

const LATEX_PATTERNS = [
  /\$\$/,
  /\\begin\{/,
  /\\frac\{/,
  /\\int(?:_|\s|\^)/,
  /\\sum(?:_|\s|\^)/,
  /\\partial/,
  /\\sqrt\{/,
  /\\lim(?:_|\s)/,
  /\\nabla/,
  /\\oint/,
  /\\left\[|\\right\]/,
  /\\left\(|\\right\)/,
];

const STEM_KEYWORDS = [
  "euler-lagrange",
  "hamiltonian",
  "lagrangian",
  "eigenvalue",
  "eigenvector",
  "differential equation",
  "partial derivative",
  "navier-stokes",
  "schrodinger",
  "fourier transform",
  "laplace transform",
  "taylor series",
  "matrix multiplication",
  "riemann",
  "vector calculus",
  "complex analysis",
  "group theory",
  "topology",
  "prove that",
  "formal proof",
  "derive the",
  "derivation of",
  "stationary action",
  "thermodynamics",
  "quantum mechanics",
];

const CODE_SNIPPET_PATTERNS = [
  /```[\s\S]*?```/,
  /\bdef\s+[a-zA-Z_]\w*\s*\(/,
  /\bfunction\s+[a-zA-Z_]\w*\s*\(/,
  /\bclass\s+[A-Z]\w*/,
  /\bpublic\s+static\s+void\s+main\b/,
  /\b(async|await)\b.*\b(function|Promise|fetch)\b/,
  /\bSELECT\b[\s\S]+\bFROM\b/i,
  /\b(NullPointerException|Segmentation fault|IndexOutOfBounds|TypeError|ReferenceError)\b/,
];

const CODE_KEYWORDS = [
  "debug this",
  "fix this bug",
  "stack trace",
  "big o notation",
  "time complexity",
  "space complexity",
  "dynamic programming",
  "binary search tree",
  "concurrency",
  "race condition",
  "memory leak",
  "deadlock",
];

/**
 * Inspects conversation history and subscription tier to select models securely.
 * Ignores client-provided forceModel for Free-tier users if it specifies a Pro/reasoning model.
 * Allocates deep reasoning compute exclusively to verified Pro users.
 */
export function selectModelAndParams(
  messages: Message[],
  options?: RouterOptions
): ModelSelectionResult {
  const isPro = options?.userTier === "pro";
  const defaultFreeModel =
    options?.defaultModel ||
    Deno.env.get("DEFAULT_MODEL") ||
    "llama-3.3-70b-versatile";

  let selectedModel = isPro
    ? options?.proModel || Deno.env.get("PRO_MODEL") || "deepseek/deepseek-r1"
    : defaultFreeModel;

  // Handle caller requested forceModel
  if (options?.forceModel) {
    const requested = options.forceModel.toLowerCase();
    const isRequestingPro =
      requested.includes("pro") ||
      requested.includes("reasoner") ||
      requested.includes("r1") ||
      requested.includes("o1") ||
      requested.includes("o3") ||
      requested.includes("sonnet");

    if (isPro) {
      // Pro users are authorized to force specific models including deep reasoners
      return {
        model: options.forceModel,
        reasoning_effort: isRequestingPro ? "high" : undefined,
        reasoningDetected: isRequestingPro,
        matchedCriteria: ["pro_caller_override"],
      };
    } else {
      // Free users: sanitize forceModel against free whitelist
      const isApprovedFreeModel = FREE_MODEL_WHITELIST.some((m) =>
        requested.includes(m.toLowerCase())
      );
      if (isApprovedFreeModel) {
        selectedModel = options.forceModel;
      } else {
        console.warn(
          `[Router] Free user requested unauthorized model "${options.forceModel}". Reverting to free default "${defaultFreeModel}".`
        );
        selectedModel = defaultFreeModel;
      }
    }
  }

  if (!messages || messages.length === 0) {
    return {
      model: selectedModel,
      reasoningDetected: false,
    };
  }

  // Detect complex STEM, LaTeX, or coding questions
  const nonSystemMessages = messages.filter((m) => m.role !== "system");
  const lastUserMessage =
    [...messages].reverse().find((m) => m.role === "user")?.content ?? "";
  const fullContextText = messages.map((m) => m.content).join("\n");
  const userContextText = nonSystemMessages.map((m) => m.content).join("\n");
  const lastLower = lastUserMessage.toLowerCase();
  const userLower = userContextText.toLowerCase();
  const fullLower = fullContextText.toLowerCase();

  const matchedCriteria: string[] = [];

  for (const regex of LATEX_PATTERNS) {
    if (regex.test(lastUserMessage) || regex.test(userContextText)) {
      matchedCriteria.push(`latex_pattern:${regex.source}`);
      break;
    }
  }

  for (const kw of STEM_KEYWORDS) {
    if (lastLower.includes(kw) || userLower.includes(kw)) {
      matchedCriteria.push(`stem_keyword:${kw}`);
      break;
    }
  }

  for (const regex of CODE_SNIPPET_PATTERNS) {
    if (regex.test(lastUserMessage) || regex.test(fullContextText)) {
      matchedCriteria.push(`code_syntax:${regex.source}`);
      break;
    }
  }

  for (const kw of CODE_KEYWORDS) {
    if (lastLower.includes(kw) || fullLower.includes(kw)) {
      matchedCriteria.push(`code_keyword:${kw}`);
      break;
    }
  }

  const totalWordCount = fullContextText.trim().split(/\s+/).length;
  if (totalWordCount > 3500 || fullContextText.length > 18000) {
    matchedCriteria.push(`high_token_volume:${totalWordCount}_words`);
  }

  const reasoningDetected = matchedCriteria.length > 0;

  // Deep reasoning effort is only granted to Pro users
  const effectiveReasoningEffort =
    isPro && reasoningDetected ? ("high" as const) : undefined;

  return {
    model: selectedModel,
    reasoning_effort: effectiveReasoningEffort,
    reasoningDetected: isPro && reasoningDetected,
    matchedCriteria: reasoningDetected ? matchedCriteria : undefined,
  };
}

export function normalizeModelForBaseUrl(model: string, _baseUrl: string): string {
  return Deno.env.get("LUNA_MODEL") || model || "luna";
}
