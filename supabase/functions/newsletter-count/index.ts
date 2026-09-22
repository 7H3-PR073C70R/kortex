/**
 * newsletter-count
 *
 * Public, read-only aggregate counter for the pre-launch landing page.
 * Returns ONLY the number of active waitlist subscribers. Never returns
 * emails, sources, timestamps, or any row-level data.
 *
 * Design notes:
 *   - Uses the service_role key server-side so it can read a table whose
 *     public SELECT is revoked by RLS. The count is the only thing that
 *     ever leaves this function.
 *   - verify_jwt = false (see supabase/config.toml) so the landing page can
 *     call it as a plain, cacheable GET without shipping a privileged key.
 *   - Short Cache-Control keeps the number fresh while limiting load.
 *
 * OWASP Controls:
 *   A01 (Access Control)   – aggregate only, no row data exposed
 *   A05 (Security Misconfig) – strict CORS allowlist, security headers
 *   A09 (Logging)          – no PII logged
 */

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://kortex-study-app-2026.web.app",
  "https://kortex-study-app-2026.firebaseapp.com",
  "http://localhost:8089",
  "http://localhost:8099",
  "http://localhost:3000",
];

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "public, max-age=60",
  };
}

function json(data: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders(origin) });
}

serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405, origin);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  // head: true -> count only, no rows transferred.
  const { count, error } = await supabase
    .from("newsletter_subscribers")
    .select("*", { count: "exact", head: true })
    .eq("is_active", true);

  if (error) {
    console.error("[newsletter-count] DB error:", error.code, error.message);
    // Fail open with a null count so the page can hide the stat rather than
    // ever display a wrong number.
    return json({ count: null }, 500, origin);
  }

  return json({ count: count ?? 0 }, 200, origin);
});
