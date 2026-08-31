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

// 1. Math / LaTeX patterns
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

// 2. Programming / Code Syntax patterns
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
 * Inspects conversation history and last user message to automatically
 * determine whether to route to deep reasoning models (`deepseek-v4-pro`)
 * or low-latency flash models (`deepseek-v4-flash`).
 */
export function selectModelAndParams(
  messages: Message[],
  options?: RouterOptions
): ModelSelectionResult {
  const defaultModel =
    options?.defaultModel ||
    Deno.env.get("DEFAULT_MODEL") ||
    "deepseek-v4-flash";
  const proModel = options?.proModel || "deepseek-v4-pro";

  // 1. Check for manual/admin caller override
  if (options?.forceModel) {
    return {
      model: options.forceModel,
      reasoning_effort: options.forceModel.includes("pro") ? "high" : undefined,
      reasoningDetected: options.forceModel.includes("pro"),
      matchedCriteria: ["admin_forced_override"],
    };
  }

  if (!messages || messages.length === 0) {
    return {
      model: defaultModel,
      reasoningDetected: false,
    };
  }

  const lastUserMessage =
    [...messages].reverse().find((m) => m.role === "user")?.content ?? "";
  const fullContextText = messages.map((m) => m.content).join("\n");
  const lastLower = lastUserMessage.toLowerCase();
  const fullLower = fullContextText.toLowerCase();

  const matchedCriteria: string[] = [];

  // A. Check Math / LaTeX indicators
  for (const regex of LATEX_PATTERNS) {
    if (regex.test(lastUserMessage) || regex.test(fullContextText)) {
      matchedCriteria.push(`latex_pattern:${regex.source}`);
      break;
    }
  }

  for (const kw of STEM_KEYWORDS) {
    if (lastLower.includes(kw) || fullLower.includes(kw)) {
      matchedCriteria.push(`stem_keyword:${kw}`);
      break;
    }
  }

  // B. Check Code / Programming indicators
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

  // C. Check Word / Token scale (> 3,500 words or length > 18,000 chars)
  const totalWordCount = fullContextText.trim().split(/\s+/).length;
  if (totalWordCount > 3500 || fullContextText.length > 18000) {
    matchedCriteria.push(`high_token_volume:${totalWordCount}_words`);
  }

  // Determine routing
  const reasoningDetected = matchedCriteria.length > 0;

  if (reasoningDetected) {
    return {
      model: proModel,
      reasoning_effort: "high",
      reasoningDetected: true,
      matchedCriteria,
    };
  }

  return {
    model: defaultModel,
    reasoningDetected: false,
  };
}
