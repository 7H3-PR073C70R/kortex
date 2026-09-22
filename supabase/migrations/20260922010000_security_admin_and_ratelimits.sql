-- =============================================================================
-- Migration: Security Hardening — Admin Auth, Rate Limiting, OWASP A01-A10
-- =============================================================================

-- ─── 1. Admin Settings Table (server-side passcode, bcrypt hashed) ───────────
CREATE TABLE IF NOT EXISTS public.admin_settings (
  key         text        NOT NULL,
  value       text        NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admin_settings_pkey PRIMARY KEY (key)
);

-- Seed the default admin passcode hash using bcrypt via pgcrypto
-- DEFAULT PASSCODE: Kortex!Admin#Secure2026
-- ⚠️  CHANGE THIS via Supabase Dashboard → SQL Editor after first deploy:
--     UPDATE public.admin_settings
--     SET value = extensions.crypt('your-new-passcode', extensions.gen_salt('bf'))
--     WHERE key = 'admin_passcode_hash';
DO $$
BEGIN
  INSERT INTO public.admin_settings (key, value)
  VALUES (
    'admin_passcode_hash',
    extensions.crypt('Kortex!Admin#Secure2026', extensions.gen_salt('bf'))
  )
  ON CONFLICT (key) DO NOTHING;
EXCEPTION WHEN undefined_function THEN
  -- pgcrypto functions not available in this schema; insert a placeholder
  -- You MUST manually run the UPDATE statement above before using admin features
  INSERT INTO public.admin_settings (key, value)
  VALUES ('admin_passcode_hash', '__UNSET_RUN_SQL_UPDATE__')
  ON CONFLICT (key) DO NOTHING;
END;
$$;

-- Strict RLS: no client can ever read admin_settings
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_settings_no_access"
  ON public.admin_settings FOR ALL USING (false);

-- ─── 2. API Rate Limits Table ─────────────────────────────────────────────────
-- Stores per-IP, per-endpoint request timestamps for sliding window rate limiting.
-- ip_hash is SHA-256 of (IP + daily salt) — never stores raw IPs (GDPR-friendly).
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id          bigserial   NOT NULL,
  ip_hash     text        NOT NULL,
  endpoint    text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT api_rate_limits_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_lookup
  ON public.api_rate_limits (ip_hash, endpoint, created_at DESC);

-- No client access to rate limit table
ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rate_limits_no_access"
  ON public.api_rate_limits FOR ALL USING (false);

-- ─── 3. Admin Passcode Verification RPC (SECURITY DEFINER) ───────────────────
-- Runs with elevated privileges but exposes no raw data.
-- Returns true only if the passcode matches the bcrypt hash.
CREATE OR REPLACE FUNCTION public.verify_admin_passcode(input_passcode text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT extensions.crypt(input_passcode, value) = value
  FROM public.admin_settings
  WHERE key = 'admin_passcode_hash';
$$;

-- Revoke public access; only service_role can call it
REVOKE ALL ON FUNCTION public.verify_admin_passcode(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_passcode(text) TO service_role;

-- ─── 4. Rate Limit Check + Record RPC ────────────────────────────────────────
-- Atomically records a new request and returns whether the caller is within limit.
-- p_ip_hash:        anonymized IP hash
-- p_endpoint:       e.g. 'subscribe-newsletter'
-- p_max_requests:   e.g. 5
-- p_window_minutes: e.g. 60
-- Returns TRUE if allowed, FALSE if rate-limited.
CREATE OR REPLACE FUNCTION public.check_and_record_rate_limit(
  p_ip_hash        text,
  p_endpoint       text,
  p_max_requests   integer,
  p_window_minutes integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  -- Count requests in the sliding window
  SELECT COUNT(*) INTO v_count
  FROM public.api_rate_limits
  WHERE ip_hash  = p_ip_hash
    AND endpoint = p_endpoint
    AND created_at > now() - (p_window_minutes || ' minutes')::interval;

  -- Always record the attempt (even rejected ones — prevents enumeration timing)
  INSERT INTO public.api_rate_limits (ip_hash, endpoint)
  VALUES (p_ip_hash, p_endpoint);

  -- 1% probabilistic cleanup of entries older than 48 hours (low-cost maintenance)
  IF random() < 0.01 THEN
    DELETE FROM public.api_rate_limits
    WHERE created_at < now() - interval '48 hours';
  END IF;

  -- v_count is the count BEFORE this new insert, so compare with max
  RETURN v_count < p_max_requests;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_record_rate_limit(text, text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_record_rate_limit(text, text, integer, integer) TO service_role;

-- ─── 5. Admin Token Sessions Table ───────────────────────────────────────────
-- Stores short-lived session tokens for the internal admin portal.
-- Tokens are SHA-256 hashed before storage (never stored raw).
CREATE TABLE IF NOT EXISTS public.admin_sessions (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  token_hash   text        NOT NULL UNIQUE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  expires_at   timestamptz NOT NULL DEFAULT now() + interval '1 hour',
  ip_hash      text,
  CONSTRAINT admin_sessions_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_token
  ON public.admin_sessions (token_hash, expires_at);

ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_sessions_no_access"
  ON public.admin_sessions FOR ALL USING (false);

-- ─── 6. Session Verification RPC ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_admin_session(input_token_hash text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_sessions
    WHERE token_hash = input_token_hash
      AND expires_at > now()
  );
$$;

REVOKE ALL ON FUNCTION public.verify_admin_session(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_admin_session(text) TO service_role;

-- ─── 7. Enforce No Direct Writes to newsletter/contact via anon ──────────────
-- Already enforced by the RLS policies from migration 20260922000000.
-- Double-check by revoking DML grants just in case:
REVOKE INSERT, UPDATE, DELETE ON public.newsletter_subscribers FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.contact_inquiries FROM anon, authenticated;
REVOKE SELECT ON public.newsletter_subscribers FROM anon, authenticated;
REVOKE SELECT ON public.contact_inquiries FROM anon, authenticated;
