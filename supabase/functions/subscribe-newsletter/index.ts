/**
 * subscribe-newsletter – Hardened v2
 *
 * OWASP Controls:
 *   A01 (Access Control)     – RLS + service_role only writes; anon key exposed is safe
 *   A02 (Crypto)             – HTTPS only; no sensitive data logged
 *   A03 (Injection)          – Input sanitised, parameterised queries via Supabase client
 *   A04 (Insecure Design)    – Honeypot, server-side rate limiting, email whitelist regex
 *   A05 (Security Misconfig) – Strict CORS (origin allowlist), security headers
 *   A07 (Auth Failures)      – Rate limit 5 req/hour/IP
 *   A09 (Logging)            – Structured error logs, never logs PII
 */

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Constants ────────────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  "https://kortex-study-app-2026.web.app",
  "https://kortex-study-app-2026.firebaseapp.com",
  "http://localhost:8089",
  "http://localhost:3000",
];

const EMAIL_RE =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

const ALLOWED_SOURCES = new Set([
  "landing_page", "contact_form", "in_app", "referral", "other",
]);

// ─── Helpers ─────────────────────────────────────────────────────────────────

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, apikey, Authorization",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
  };
}

function json(data: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders(origin) });
}

function sanitize(input: unknown, maxLen = 254): string {
  if (typeof input !== "string") return "";
  return input
    .replace(/<[^>]*>/g, "")
    .replace(/javascript\s*:/gi, "")
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
    .trim()
    .substring(0, maxLen);
}

async function anonymiseIp(ip: string): Promise<string> {
  const salt = new Date().toISOString().slice(0, 10);
  const buf  = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ip + salt));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

// ─── Main ─────────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, origin);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400, origin);
  }

  // ── Honeypot check (bot trap — silent drop) ─────────────────────────────────
  if (sanitize(body.hp, 10).length > 0) {
    return json({ status: "subscribed" }, 200, origin);
  }

  // ── Input validation ────────────────────────────────────────────────────────
  const rawEmail = sanitize(body.email).toLowerCase();
  if (!rawEmail || rawEmail.length > 254 || !EMAIL_RE.test(rawEmail)) {
    return json({ error: "Please provide a valid email address." }, 422, origin);
  }

  const rawSource = sanitize(body.source as string, 50);
  const source    = ALLOWED_SOURCES.has(rawSource) ? rawSource : "landing_page";

  // ── IP rate limiting: 5 subscriptions per hour per IP ──────────────────────
  const rawIp  = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await anonymiseIp(rawIp);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  const { data: withinLimit } = await supabase.rpc("check_and_record_rate_limit", {
    p_ip_hash:        ipHash,
    p_endpoint:       "subscribe-newsletter",
    p_max_requests:   5,
    p_window_minutes: 60,
  });

  if (withinLimit === false) {
    return json(
      { error: "Too many subscription attempts. Please try again in an hour." },
      429, origin
    );
  }

  // ── Upsert subscriber (parameterised — zero SQL injection risk) ─────────────
  const { error } = await supabase
    .from("newsletter_subscribers")
    .upsert(
      { email: rawEmail, source, is_active: true },
      { onConflict: "email", ignoreDuplicates: false }
    );

  if (error) {
    // Log error code/message — never log user email
    console.error("[subscribe-newsletter] DB error:", error.code, error.message);
    return json({ error: "Failed to save subscription. Please try again." }, 500, origin);
  }

  return json({ status: "subscribed" }, 200, origin);
});
