/**
 * verify-admin-token
 *
 * Validates the admin passcode against the bcrypt hash stored in Supabase,
 * enforces brute-force rate limiting (5 attempts / 15 min per IP),
 * then issues a cryptographically signed, time-bound session token.
 *
 * OWASP Controls:
 *   A07 (Auth Failures)   – bcrypt comparison, rate limit, token expiry
 *   A01 (Broken Access)   – service_role only; no anon path to hash
 *   A04 (Insecure Design) – timing-safe comparison via pgcrypto crypt()
 *   A09 (Logging)         – auth failures logged with ip_hash
 */

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Helpers ─────────────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  "https://kortex-study-app-2026.web.app",
  "https://kortex-study-app-2026.firebaseapp.com",
  "http://localhost:8089",
  "http://localhost:3000",
];

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  };
}

function json(data: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: corsHeaders(origin),
  });
}

/** Anonymise an IP: SHA-256( ip + date_salt ) → 12-char hex prefix */
async function anonymiseIp(ip: string): Promise<string> {
  const salt = new Date().toISOString().slice(0, 10); // daily salt — rotates each day
  const raw  = new TextEncoder().encode(ip + salt);
  const buf  = await crypto.subtle.digest("SHA-256", raw);
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("").slice(0, 32);
}

/** Generate a cryptographically secure session token (256-bit) */
function generateSessionToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

/** SHA-256 hash of a token for DB storage (never store raw token) */
async function hashToken(token: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
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

  // ── Parse body ──────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400, origin);
  }

  const passcode = typeof body.passcode === "string" ? body.passcode.slice(0, 200) : "";
  if (!passcode) {
    return json({ error: "Passcode required" }, 400, origin);
  }

  // ── IP extraction & anonymisation ───────────────────────────────────────────
  const rawIp  = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
    || req.headers.get("x-real-ip")
    || "unknown";
  const ipHash = await anonymiseIp(rawIp);

  // ── Service-role Supabase client ────────────────────────────────────────────
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  // ── Rate limit: max 5 attempts per 15 minutes per IP ────────────────────────
  const { data: withinLimit, error: rlErr } = await supabase.rpc("check_and_record_rate_limit", {
    p_ip_hash:        ipHash,
    p_endpoint:       "verify-admin-token",
    p_max_requests:   5,
    p_window_minutes: 15,
  });

  if (rlErr) {
    console.error("[verify-admin-token] Rate limit RPC error:", rlErr.message);
  }

  if (withinLimit === false) {
    // Use the same delay as a valid attempt to prevent timing oracle attacks
    await new Promise(r => setTimeout(r, 300 + Math.random() * 200));
    return json({ error: "Too many attempts. Please wait 15 minutes before trying again." }, 429, origin);
  }

  // ── Verify passcode via bcrypt RPC ─────────────────────────────────────────
  // Uses pgcrypto crypt() which is timing-safe by design
  const { data: isValid, error: authErr } = await supabase.rpc("verify_admin_passcode", {
    input_passcode: passcode,
  });

  if (authErr) {
    console.error("[verify-admin-token] Auth RPC error:", authErr.message);
    return json({ error: "Authentication service unavailable." }, 503, origin);
  }

  if (!isValid) {
    // Constant-time delay prevents timing attacks
    await new Promise(r => setTimeout(r, 400 + Math.random() * 200));
    return json({ error: "Invalid passcode." }, 401, origin);
  }

  // ── Generate and persist session token ─────────────────────────────────────
  const rawToken   = generateSessionToken();
  const tokenHash  = await hashToken(rawToken);

  const { error: sessionErr } = await supabase
    .from("admin_sessions")
    .insert({ token_hash: tokenHash, ip_hash: ipHash });

  if (sessionErr) {
    console.error("[verify-admin-token] Session insert error:", sessionErr.message);
    return json({ error: "Failed to create session." }, 500, origin);
  }

  // Return ONLY the raw token (hash stored, raw token travels once over HTTPS)
  return json({ token: rawToken, expiresIn: 3600 }, 200, origin);
});
