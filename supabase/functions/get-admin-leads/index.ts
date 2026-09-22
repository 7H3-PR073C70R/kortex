/**
 * get-admin-leads
 *
 * Private endpoint for the internal admin portal.
 * Validates the session token hash before returning any data.
 * Supports paginated CSV export.
 *
 * OWASP Controls:
 *   A01 (Broken Access)   – session token required, validated server-side
 *   A02 (Crypto Failures) – token stored as SHA-256 hash, validated in time-constant manner
 *   A03 (Injection)       – all query params validated/cast before use
 *   A05 (Misconfig)       – strict CORS, security headers
 */

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-admin-token",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
    "Content-Type": "application/json",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Cache-Control": "no-store, no-cache, must-revalidate",
  };
}

function json(data: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: corsHeaders(origin),
  });
}

async function hashToken(token: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

/** Escape a single CSV field (RFC 4180) */
function csvEscape(val: unknown): string {
  const s = String(val ?? "");
  // Block CSV injection (A03) - prefix dangerous chars
  if (/^[=+\-@\t\r]/.test(s)) return `"'${s.replace(/"/g, '""')}"`;
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405, origin);
  }

  // ── Token extraction ────────────────────────────────────────────────────────
  const rawToken = req.headers.get("X-Admin-Token")?.trim() ?? "";
  if (!rawToken || rawToken.length < 64) {
    return json({ error: "Unauthorized" }, 401, origin);
  }

  const tokenHash = await hashToken(rawToken);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  // ── Validate session ────────────────────────────────────────────────────────
  const { data: isValid, error: sessionErr } = await supabase.rpc("verify_admin_session", {
    input_token_hash: tokenHash,
  });

  if (sessionErr || !isValid) {
    return json({ error: "Unauthorized" }, 401, origin);
  }

  // ── Parse query params (validated, never interpolated into SQL) ─────────────
  const url    = new URL(req.url);
  const type   = url.searchParams.get("type") ?? "newsletter";   // 'newsletter' | 'contact'
  const format = url.searchParams.get("format") ?? "json";        // 'json' | 'csv'
  const page   = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10));
  const limit  = Math.min(500, Math.max(1, parseInt(url.searchParams.get("limit") ?? "100", 10)));
  const offset = (page - 1) * limit;

  if (!["newsletter", "contact"].includes(type)) {
    return json({ error: "Invalid type parameter" }, 400, origin);
  }
  if (!["json", "csv"].includes(format)) {
    return json({ error: "Invalid format parameter" }, 400, origin);
  }

  // ── Fetch data ──────────────────────────────────────────────────────────────
  if (type === "newsletter") {
    const { data, error, count } = await supabase
      .from("newsletter_subscribers")
      .select("id, email, source, subscribed_at, is_active", { count: "exact" })
      .order("subscribed_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error("[get-admin-leads] Newsletter fetch error:", error.message);
      return json({ error: "Failed to fetch data" }, 500, origin);
    }

    if (format === "csv") {
      const header  = "id,email,source,subscribed_at,is_active\n";
      const rows    = (data ?? []).map(r =>
        [r.id, r.email, r.source, r.subscribed_at, r.is_active].map(csvEscape).join(",")
      ).join("\n");
      const csv = header + rows;
      return new Response(csv, {
        status: 200,
        headers: {
          ...corsHeaders(origin),
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": `attachment; filename="newsletter_${new Date().toISOString().slice(0,10)}.csv"`,
        },
      });
    }

    return json({ data, total: count, page, limit }, 200, origin);
  }

  // type === 'contact'
  const { data, error, count } = await supabase
    .from("contact_inquiries")
    .select("id, name, email, topic, message, newsletter_optin, submitted_at", { count: "exact" })
    .order("submitted_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) {
    console.error("[get-admin-leads] Contact fetch error:", error.message);
    return json({ error: "Failed to fetch data" }, 500, origin);
  }

  if (format === "csv") {
    const header = "id,name,email,topic,message,newsletter_optin,submitted_at\n";
    const rows   = (data ?? []).map(r =>
      [r.id, r.name, r.email, r.topic, r.message, r.newsletter_optin, r.submitted_at].map(csvEscape).join(",")
    ).join("\n");
    const csv = header + rows;
    return new Response(csv, {
      status: 200,
      headers: {
        ...corsHeaders(origin),
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="contacts_${new Date().toISOString().slice(0,10)}.csv"`,
      },
    });
  }

  return json({ data, total: count, page, limit }, 200, origin);
});
