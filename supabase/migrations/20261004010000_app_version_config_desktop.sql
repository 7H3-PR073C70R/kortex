-- ============================================================
-- Supabase Migration: Add desktop platform support
-- Extends app_version_config for macOS, Windows, and Linux
-- ============================================================

-- 1. Relax the CHECK constraint to include desktop slugs.
ALTER TABLE public.app_version_config
  DROP CONSTRAINT IF EXISTS app_version_config_platform_check;

ALTER TABLE public.app_version_config
  ADD CONSTRAINT app_version_config_platform_check
  CHECK (platform IN ('ios', 'android', 'macos', 'windows', 'linux'));

-- 2. Seed desktop rows with force-update disabled (safe defaults).
--    For desktop apps the store_url typically points to a download page,
--    GitHub Releases page, or a custom update server URL.
INSERT INTO public.app_version_config
  (platform, minimum_version, current_version, is_force_update_active, store_url, update_message)
VALUES
  (
    'macos',
    '1.0.0',
    '1.0.0',
    false,
    'https://kortexify.app/download',  -- ⚠ replace with real macOS download URL
    'A new version of Kortex for macOS is required. Please download the latest version.'
  ),
  (
    'windows',
    '1.0.0',
    '1.0.0',
    false,
    'https://kortexify.app/download',  -- ⚠ replace with real Windows download URL
    'A new version of Kortex for Windows is required. Please download the latest version.'
  ),
  (
    'linux',
    '1.0.0',
    '1.0.0',
    false,
    'https://kortexify.app/download',  -- ⚠ replace with real Linux download URL
    'A new version of Kortex for Linux is required. Please download the latest version.'
  )
ON CONFLICT (platform) DO NOTHING;

-- ── How to enable force-update for macOS (example) ────────────────────────
-- UPDATE public.app_version_config
-- SET
--   minimum_version        = '2.5.0',
--   current_version        = '2.5.1',
--   is_force_update_active = true,
--   store_url              = 'https://kortexify.app/download/macos/2.5.1'
-- WHERE platform = 'macos';
