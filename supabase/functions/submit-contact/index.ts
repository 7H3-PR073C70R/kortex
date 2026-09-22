/**
 * submit-contact – Hardened v2
 *
 * OWASP Controls:
 *   A01 (Access Control)     – service_role writes; anon key can only call this function
 *   A03 (Injection)          – all inputs sanitised + length constrained; parameterised queries
 *   A04 (Insecure Design)    – honeypot, rate limiting, topic/source whitelists
 *   A05 (Security Misconfig) – strict CORS origin allowlist, security headers
 *   A07 (Auth Failures)      – rate limit 3 submissions per hour per IP
 *   A09 (Logging)            – errors logged without PII
 */

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://kortex-study-app-2026.web.app",
  "https://kortex-study-app-2026.firebaseapp.com",
  "http://localhost:8089",
  "http://localhost:3000",
];

const EMAIL_RE =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

const ALLOWED_TOPICS = new Set([
  "early_access", "exam_past_questions", "feature_request",
  "campus_partnership", "bug_report", "other",
]);

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

function sanitize(input: unknown, maxLen = 3000): string {
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
    return json({ error: "Invalid request body" }, 400, origin);
  }

  if (sanitize(body.hp, 10).length > 0) {
    return json({ status: "received" }, 200, origin);
  }

  const name    = sanitize(body.name, 100);
  const email   = sanitize(body.email, 254).toLowerCase();
  const topic   = sanitize(body.topic, 50);
  const message = sanitize(body.message, 3000);
  const optIn   = Boolean(body.newsletterOptIn);

  const errors: string[] = [];
  if (name.length < 2 || name.length > 100)        errors.push("Name must be 2–100 characters.");
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) errors.push("Valid email required.");
  if (message.length < 5 || message.length > 3000) errors.push("Message must be 5–3,000 characters.");

  if (errors.length > 0) {
    return json({ error: errors[0] }, 422, origin);
  }

  const cleanTopic = ALLOWED_TOPICS.has(topic) ? topic : "other";

  const rawIp  = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await anonymiseIp(rawIp);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  const { data: withinLimit } = await supabase.rpc("check_and_record_rate_limit", {
    p_ip_hash:        ipHash,
    p_endpoint:       "submit-contact",
    p_max_requests:   3,
    p_window_minutes: 60,
  });

  if (withinLimit === false) {
    return json(
      { error: "You have submitted too many messages. Please try again in an hour." },
      429, origin
    );
  }

  const { error: insertErr } = await supabase
    .from("contact_inquiries")
    .insert({ name, email, topic: cleanTopic, message, newsletter_optin: optIn });

  if (insertErr) {
    console.error("[submit-contact] DB insert error:", insertErr.code, insertErr.message);
    return json({ error: "Failed to submit. Please try again." }, 500, origin);
  }

  if (optIn) {
    await supabase
      .from("newsletter_subscribers")
      .upsert({ email, source: "contact_form", is_active: true }, { onConflict: "email" });
  }

  return json({ status: "received" }, 200, origin);
});
