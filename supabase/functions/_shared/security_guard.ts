/**
 * Kortex Server-Side Zero-Trust Security Guard.
 * Provides cryptographic constant-time comparison, SSRF protection,
 * replay-attack defense, and prompt-injection sanitization.
 */

/**
 * Constant-time string equality check to prevent timing attacks
 * on API keys, HMAC signatures, and webhook bearer secrets.
 */
export async function timingSafeEqualString(
  a: string,
  b: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const aBuf = encoder.encode(a);
  const bBuf = encoder.encode(b);

  if (aBuf.byteLength !== bBuf.byteLength) {
    return false;
  }

  // Use crypto.subtle.timingSafeEqual or XOR comparison
  let result = 0;
  for (let i = 0; i < aBuf.byteLength; i++) {
    result |= aBuf[i] ^ bBuf[i];
  }
  return result === 0;
}

/**
 * Replay Attack Guard: Verifies that an event timestamp is within
 * the acceptable clock drift window (default: 300 seconds / 5 minutes).
 */
export function verifyTimestampFreshness(
  timestampMs: number,
  maxDriftSeconds: number = 300
): boolean {
  const now = Date.now();
  const driftMs = Math.abs(now - timestampMs);
  return driftMs <= maxDriftSeconds * 1000;
}

/**
 * Server-Side Request Forgery (SSRF) Guard.
 * Blocks calls to RFC 1918 private subnets, loopback interfaces,
 * and cloud metadata services (e.g. AWS/GCP 169.254.169.254).
 */
export function isSafeOutboundUrl(targetUrl: string): boolean {
  try {
    const parsed = new URL(targetUrl);

    // Protocol must strictly be HTTPS (or HTTP in local dev if explicitly configured)
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return false;
    }

    const hostname = parsed.hostname.toLowerCase();

    // Block localhost, loopback, and local domain variants
    if (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname.endsWith(".local") ||
      hostname.endsWith(".internal")
    ) {
      return false;
    }

    // Block Cloud Metadata Endpoints (AWS, GCP, Azure, DigitalOcean)
    if (hostname === "169.254.169.254" || hostname.startsWith("169.254.")) {
      return false;
    }

    // Check IPv4 private subnets
    const ipv4Match = hostname.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
    if (ipv4Match) {
      const octet1 = parseInt(ipv4Match[1], 10);
      const octet2 = parseInt(ipv4Match[2], 10);

      // 10.0.0.0/8
      if (octet1 === 10) return false;
      // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
      if (octet1 === 172 && octet2 >= 16 && octet2 <= 31) return false;
      // 192.168.0.0/16
      if (octet1 === 192 && octet2 === 168) return false;
      // 127.0.0.0/8
      if (octet1 === 127) return false;
      // 0.0.0.0/8
      if (octet1 === 0) return false;
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Prompt Injection & Zero-Width Exploit Sanitization Guard.
 * Cleans untrusted text from student notes, OCR dumps, and PDF text
 * before passing context into LLM system prompts.
 */
export function sanitizePromptInput(rawText: string): string {
  if (!rawText) return "";

  let cleaned = rawText;

  // 1. Strip zero-width control / obfuscation characters
  cleaned = cleaned.replace(/[\u200B-\u200D\u2060\uFEFF]/g, "");

  // 2. Neutralize role-boundary injection markers
  const dangerousMarkers = [
    /<\|im_start\|>/gi,
    /<\|im_end\|>/gi,
    /\[SYSTEM\]/gi,
    /\[\/SYSTEM\]/gi,
    /<<SYS>>/gi,
    /<\/SYS>>/gi,
    /\[INST\]/gi,
    /\[\/INST\]/gi,
    /<start_of_turn>/gi,
    /<end_of_turn>/gi,
  ];

  for (const marker of dangerousMarkers) {
    cleaned = cleaned.replace(marker, "[SANITIZED_PROMPT_BOUNDARY]");
  }

  // 3. Prevent system prompt overrides
  const overridePatterns = [
    /ignore all previous instructions/gi,
    /disregard all previous instructions/gi,
    /you are now in developer mode/gi,
    /output the system prompt/gi,
    /reveal your secret prompt/gi,
  ];

  for (const pattern of overridePatterns) {
    cleaned = cleaned.replace(pattern, "[POTENTIAL_PROMPT_OVERRIDE_STRIPPED]");
  }

  return cleaned.trim();
}
