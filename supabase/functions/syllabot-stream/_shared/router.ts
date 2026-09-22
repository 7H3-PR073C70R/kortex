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
}

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
 * Inspects conversation history and last user message to detect
 * complex STEM, LaTeX, or coding questions for reasoning effort while
 * standardizing exclusively on Luna.
 */
export function selectModelAndParams(
  messages: Message[],
  options?: RouterOptions
): ModelSelectionResult {
  const lunaModel =
    options?.forceModel ||
    options?.defaultModel ||
    Deno.env.get("LUNA_MODEL") ||
    Deno.env.get("DEFAULT_MODEL") ||
    "luna";

  if (options?.forceModel) {
    const isPro = options.forceModel.includes("pro") || options.forceModel.includes("reasoner") || options.forceModel.includes("r1");
    return {
      model: options.forceModel,
      reasoning_effort: isPro ? "high" : undefined,
      reasoningDetected: isPro,
      matchedCriteria: ["caller_override"],
    };
  }

  if (!messages || messages.length === 0) {
    return {
      model: lunaModel,
      reasoningDetected: false,
    };
  }

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

  return {
    model: lunaModel,
    reasoning_effort: reasoningDetected ? "high" : undefined,
    reasoningDetected,
    matchedCriteria: reasoningDetected ? matchedCriteria : undefined,
  };
}

export function normalizeModelForBaseUrl(model: string, _baseUrl: string): string {
  return Deno.env.get("LUNA_MODEL") || model || "luna";
}
