-- ============================================================
-- Supabase Migration: App Version Force-Update Config
-- Table: app_version_config
-- ============================================================
--
-- Purpose: Lets the backend team control the minimum required
--          app version per platform without a server deploy.
--          Setting `is_force_update_active = false` globally
--          disables all version gating (kill-switch).
--
-- One row per platform ("ios" | "android"). Update via the
-- Supabase Dashboard Table Editor or via SQL.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_version_config (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  platform              TEXT        NOT NULL CHECK (platform IN ('ios', 'android')),
  minimum_version       TEXT        NOT NULL DEFAULT '0.0.0',
  current_version       TEXT        NOT NULL DEFAULT '0.0.0',
  is_force_update_active BOOLEAN    NOT NULL DEFAULT false,
  store_url             TEXT        NOT NULL DEFAULT '',
  update_message        TEXT,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_app_version_platform UNIQUE (platform)
);

-- Keep `updated_at` fresh on every update.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_version_config_updated_at ON public.app_version_config;
CREATE TRIGGER trg_app_version_config_updated_at
  BEFORE UPDATE ON public.app_version_config
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- Row-Level Security: anonymous users can only READ.
-- Only service_role (your backend / admin dashboard) can write.
ALTER TABLE public.app_version_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_app_version_config"
  ON public.app_version_config
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "service_role_all_app_version_config"
  ON public.app_version_config
  FOR ALL
  TO service_role
  USING (true);

-- ── Seed with safe defaults (force-update off) ─────────────────────────────
INSERT INTO public.app_version_config
  (platform, minimum_version, current_version, is_force_update_active, store_url, update_message)
VALUES
  (
    'ios',
    '1.0.0',
    '1.0.0',
    false,
    'https://apps.apple.com/app/kortex/id0000000000',  -- ⚠ replace with real App Store ID
    'A new version of Kortex is required to continue. Please update from the App Store.'
  ),
  (
    'android',
    '1.0.0',
    '1.0.0',
    false,
    'https://play.google.com/store/apps/details?id=com.kortexify.app',
    'A new version of Kortex is required to continue. Please update from the Play Store.'
  )
ON CONFLICT (platform) DO NOTHING;

-- ── How to enable force-update for iOS (example) ──────────────────────────
-- UPDATE public.app_version_config
-- SET
--   minimum_version       = '2.5.0',
--   current_version       = '2.5.1',
--   is_force_update_active = true
-- WHERE platform = 'ios';
