/**
 * Kortex Server-Side Zero-Trust Security Guard.
 * Provides cryptographic constant-time comparison, SSRF protection,
 * replay-attack defense, safe streaming fetch, and prompt-injection sanitization.
 */

// Declare Deno namespace for TypeScript when running outside Deno
declare const Deno: {
  resolveDns?: (query: string, recordType: string) => Promise<string[]>;
} | undefined;

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
 * Inspects an IPv4 string against private, reserved, loopback,
 * CGNAT, and link-local subnets (RFC 1918, RFC 6598, RFC 3927, RFC 5735).
 */
export function isForbiddenIpv4(ipStr: string): boolean {
  const parts = ipStr.split(".");
  if (parts.length !== 4) return false;

  const octets: number[] = [];
  for (const part of parts) {
    if (!/^\d+$/.test(part)) return false;
    const n = parseInt(part, 10);
    if (n < 0 || n > 255) return false;
    octets.push(n);
  }

  const [o1, o2, o3, _o4] = octets;

  // 0.0.0.0/8 (Current network)
  if (o1 === 0) return true;
  // 10.0.0.0/8 (Private)
  if (o1 === 10) return true;
  // 100.64.0.0/10 (Carrier-Grade NAT / Shared Address Space RFC 6598)
  if (o1 === 100 && o2 >= 64 && o2 <= 127) return true;
  // 127.0.0.0/8 (Loopback)
  if (o1 === 127) return true;
  // 169.254.0.0/16 (Link-Local / AWS/GCP/Azure Cloud Metadata)
  if (o1 === 169 && o2 === 254) return true;
  // 172.16.0.0/12 (Private)
  if (o1 === 172 && o2 >= 16 && o2 <= 31) return true;
  // 192.0.0.0/24 (IETF Protocol Assignments)
  if (o1 === 192 && o2 === 0 && o3 === 0) return true;
  // 192.0.2.0/24 (TEST-NET-1)
  if (o1 === 192 && o2 === 0 && o3 === 2) return true;
  // 192.88.99.0/24 (6to4 Relay)
  if (o1 === 192 && o2 === 88 && o3 === 99) return true;
  // 192.168.0.0/16 (Private)
  if (o1 === 192 && o2 === 168) return true;
  // 198.18.0.0/15 (Benchmarking)
  if (o1 === 198 && (o2 === 18 || o2 === 19)) return true;
  // 198.51.100.0/24 (TEST-NET-2)
  if (o1 === 198 && o2 === 51 && o3 === 100) return true;
  // 203.0.113.0/24 (TEST-NET-3)
  if (o1 === 203 && o2 === 0 && o3 === 113) return true;
  // 224.0.0.0/4 (Multicast) & 240.0.0.0/4 (Reserved / Broadcast)
  if (o1 >= 224) return true;

  return false;
}

/**
 * Inspects an IPv6 string against private, loopback, link-local,
 * unique-local (ULA), and IPv4-mapped IPv6 subnets (RFC 4291, RFC 4193).
 */
export function isForbiddenIpv6(ipStr: string): boolean {
  const s = ipStr.toLowerCase().replace(/^\[|\]$/g, "").trim();

  // Loopback (::1) and Unspecified (::)
  if (
    s === "::1" ||
    s === "0:0:0:0:0:0:0:1" ||
    s === "::" ||
    s === "0:0:0:0:0:0:0:0"
  ) {
    return true;
  }

  // IPv4-mapped IPv6 (::ffff:0:0/96 or ::ffff:a.b.c.d)
  if (s.startsWith("::ffff:") || s.includes(":ffff:")) {
    const trailing = s.split(":").pop() ?? "";
    if (trailing.includes(".")) {
      return isForbiddenIpv4(trailing);
    }
    // Block raw hex-mapped IPv4 in IPv6 (e.g. ::ffff:7f00:1)
    return true;
  }

  // Unique Local Address (fc00::/7 -> fc00... to fdff...)
  if (s.startsWith("fc") || s.startsWith("fd")) {
    return true;
  }

  // Link-Local Unicast (fe80::/10 -> fe80... to febf...)
  if (
    s.startsWith("fe8") ||
    s.startsWith("fe9") ||
    s.startsWith("fea") ||
    s.startsWith("feb")
  ) {
    return true;
  }

  // Multicast (ff00::/8)
  if (s.startsWith("ff")) {
    return true;
  }

  // Documentation (2001:db8::/32) and Discard (100::/64)
  if (s.startsWith("2001:db8") || s.startsWith("100:")) {
    return true;
  }

  return false;
}

/**
 * Checks forbidden hostname patterns and wildcard DNS rebinding domains.
 */
export function isForbiddenHostname(hostname: string): boolean {
  const h = hostname.toLowerCase().trim();

  // Helper: matches exact domain or any subdomain (e.g. "localtest.me" or "foo.localtest.me")
  const matchesDomainOrSubdomain = (domain: string, base: string): boolean =>
    domain === base || domain.endsWith("." + base);

  // Localhost aliases & internal network names
  if (
    matchesDomainOrSubdomain(h, "localhost") ||
    h.endsWith(".local") ||
    h.endsWith(".internal") ||
    h.endsWith(".lan") ||
    h.endsWith(".home") ||
    h.endsWith(".corp")
  ) {
    return true;
  }

  // Cloud metadata services
  if (
    h === "169.254.169.254" ||
    h.startsWith("169.254.") ||
    matchesDomainOrSubdomain(h, "metadata.google.internal") ||
    h === "instance-data"
  ) {
    return true;
  }

  // Wildcard DNS rebinding domain providers
  if (
    matchesDomainOrSubdomain(h, "nip.io") ||
    matchesDomainOrSubdomain(h, "sslip.io") ||
    matchesDomainOrSubdomain(h, "localtest.me") ||
    matchesDomainOrSubdomain(h, "lvh.me") ||
    matchesDomainOrSubdomain(h, "vcap.me") ||
    matchesDomainOrSubdomain(h, "cirros.local")
  ) {
    return true;
  }

  return false;
}

/**
 * Comprehensive Server-Side Request Forgery (SSRF) Guard.
 * Blocks calls to:
 * - Private RFC 1918 subnets (10/8, 172.16/12, 192.168/16)
 * - Loopback interfaces (127/8, ::1)
 * - CGNAT (100.64/10)
 * - Cloud metadata (169.254.169.254, metadata.google.internal)
 * - IPv4-mapped IPv6 (::ffff:0:0/96)
 * - ULA & Link-local IPv6 (fd00::/8, fe80::/10)
 * - Wildcard DNS rebinding providers (*.nip.io, *.sslip.io, *.localtest.me)
 * - Asynchronously resolves DNS to prevent DNS rebinding in Deno runtime
 */
export async function isSafeOutboundUrl(targetUrl: string): Promise<boolean> {
  try {
    const parsed = new URL(targetUrl);

    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return false;
    }

    const hostname = parsed.hostname.toLowerCase();

    // 1. Static Hostname & Rebinding Provider Checks
    if (isForbiddenHostname(hostname)) {
      return false;
    }

    // 2. Direct IPv4 Literal Check
    if (/^\d+\.\d+\.\d+\.\d+$/.test(hostname)) {
      if (isForbiddenIpv4(hostname)) {
        return false;
      }
      return true;
    }

    // 3. Direct IPv6 Literal Check
    if (hostname.includes(":")) {
      if (isForbiddenIpv6(hostname)) {
        return false;
      }
      return true;
    }

    // 4. Asynchronous DNS Resolution (Deno Runtime)
    if (typeof Deno !== "undefined" && typeof Deno.resolveDns === "function") {
      let resolvedCount = 0;

      try {
        const aRecords = await Deno.resolveDns(hostname, "A");
        for (const ip of aRecords) {
          resolvedCount++;
          if (isForbiddenIpv4(ip)) {
            return false;
          }
        }
      } catch {
        // A record query may fail if domain only has AAAA
      }

      try {
        const aaaaRecords = await Deno.resolveDns(hostname, "AAAA");
        for (const ip of aaaaRecords) {
          resolvedCount++;
          if (isForbiddenIpv6(ip)) {
            return false;
          }
        }
      } catch {
        // AAAA record query may fail if domain only has A
      }

      // If DNS resolution was executed and 0 records were found, fail-closed
      if (resolvedCount === 0) {
        return false;
      }
    }

    return true;
  } catch {
    return false;
  }
}

export interface SafeFetchOptions extends RequestInit {
  maxSizeBytes?: number;
  timeoutMs?: number;
  maxRedirects?: number;
}

/**
 * Production-hardened outbound HTTP client.
 * Enforces:
 * - Pre-flight and post-redirect SSRF validation via isSafeOutboundUrl
 * - Manual redirect handling (no blind redirect following)
 * - AbortController timeout execution
 * - Header-level Content-Length verification
 */
export async function safeFetch(
  targetUrl: string,
  options: SafeFetchOptions = {}
): Promise<Response> {
  const maxSizeBytes = options.maxSizeBytes ?? 30 * 1024 * 1024; // 30MB default
  const timeoutMs = options.timeoutMs ?? 15000; // 15s default
  const maxRedirects = options.maxRedirects ?? 3;

  let currentUrl = targetUrl;
  let redirectsRemaining = maxRedirects;

  while (true) {
    const isSafe = await isSafeOutboundUrl(currentUrl);
    if (!isSafe) {
      throw new Error(`SSRF Blocked: URL target is not allowed (${currentUrl})`);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    let response: Response;
    try {
      response = await fetch(currentUrl, {
        ...options,
        redirect: "manual",
        signal: controller.signal,
      });
    } catch (err: unknown) {
      if (err instanceof Error && err.name === "AbortError") {
        throw new Error(`Request Timeout: Outbound request exceeded ${timeoutMs}ms`);
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }

    // Handle redirects manually to re-verify the destination address
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get("location");
      if (!location) {
        throw new Error("Redirect response missing Location header");
      }
      if (redirectsRemaining <= 0) {
        throw new Error("Maximum redirect limit (3) exceeded");
      }
      redirectsRemaining--;

      // Resolve relative redirect against current target
      currentUrl = new URL(location, currentUrl).toString();
      continue;
    }

    // Header Content-Length ceiling check
    const contentLength = response.headers.get("content-length");
    if (contentLength && parseInt(contentLength, 10) > maxSizeBytes) {
      throw new Error(
        `Payload Too Large: Content-Length (${contentLength} bytes) exceeds limit (${maxSizeBytes} bytes)`
      );
    }

    return response;
  }
}

/**
 * Safely streams an HTTP response into an ArrayBuffer while enforcing
 * a hard byte ceiling, protecting against chunked transfer overflow attacks.
 */
export async function readCappedArrayBuffer(
  response: Response,
  maxSizeBytes: number = 30 * 1024 * 1024
): Promise<ArrayBuffer> {
  const contentLength = response.headers.get("content-length");
  if (contentLength && parseInt(contentLength, 10) > maxSizeBytes) {
    throw new Error(
      `Payload Too Large: Content-Length exceeds ceiling of ${maxSizeBytes} bytes`
    );
  }

  if (!response.body) {
    return new ArrayBuffer(0);
  }

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) {
        totalBytes += value.byteLength;
        if (totalBytes > maxSizeBytes) {
          await reader.cancel();
          throw new Error(
            `Payload Too Large: Stream exceeded ceiling of ${maxSizeBytes} bytes`
          );
        }
        chunks.push(value);
      }
    }
  } finally {
    reader.releaseLock?.();
  }

  const merged = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return merged.buffer;
}

/**
 * Prompt Injection & Zero-Width Exploit Sanitization Guard.
 * Cleans untrusted text from student notes, OCR dumps, and PDF text
 * before passing context into LLM system prompts.
 */
export function sanitizePromptInput(rawText: string): string {
  if (!rawText) return "";

  let cleaned = rawText;

  cleaned = cleaned.replace(/[\u200B-\u200D\u2060\uFEFF]/g, "");

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
