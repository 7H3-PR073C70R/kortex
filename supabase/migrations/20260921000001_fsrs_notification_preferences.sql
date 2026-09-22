-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 018 - FSRS-6 Notification Preferences
-- Adds per-user notification reminder time, timezone, and FSRS desired retention
-- to the profiles table for use by the FCM cron scheduler and local reminder sync.
-- ==============================================================================

-- 1. Add notification preference columns to profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS notification_reminder_hour    INT    NOT NULL DEFAULT 19,
    ADD COLUMN IF NOT EXISTS notification_reminder_minute  INT    NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS user_timezone                 TEXT   NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS fsrs_desired_retention        FLOAT  NOT NULL DEFAULT 0.90;

-- Annotate columns
COMMENT ON COLUMN public.profiles.notification_reminder_hour IS
    'Hour (0–23, local timezone) of preferred daily study reminder. Default 19:00.';
COMMENT ON COLUMN public.profiles.notification_reminder_minute IS
    'Minute (0–59) of preferred daily study reminder.';
COMMENT ON COLUMN public.profiles.user_timezone IS
    'IANA timezone string (e.g. "Africa/Lagos") for scheduling server-side cron reminders.';
COMMENT ON COLUMN public.profiles.fsrs_desired_retention IS
    'User-configured FSRS target retention probability (0.80–0.97). Synced from FsrsUserSettings.';

-- 2. RPC: upsert notification preferences (called from Flutter after FsrsUserSettings change)
CREATE OR REPLACE FUNCTION public.upsert_notification_preferences(
    p_reminder_hour       INT,
    p_reminder_minute     INT,
    p_user_timezone       TEXT,
    p_desired_retention   FLOAT DEFAULT 0.90
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate retention is within FSRS valid range
    IF p_desired_retention < 0.80 OR p_desired_retention > 0.97 THEN
        RAISE EXCEPTION 'desired_retention must be between 0.80 and 0.97';
    END IF;

    -- Validate hour/minute ranges
    IF p_reminder_hour < 0 OR p_reminder_hour > 23 THEN
        RAISE EXCEPTION 'reminder_hour must be between 0 and 23';
    END IF;
    IF p_reminder_minute < 0 OR p_reminder_minute > 59 THEN
        RAISE EXCEPTION 'reminder_minute must be between 0 and 59';
    END IF;

    UPDATE public.profiles
    SET
        notification_reminder_hour   = p_reminder_hour,
        notification_reminder_minute = p_reminder_minute,
        user_timezone                = p_user_timezone,
        fsrs_desired_retention       = p_desired_retention,
        updated_at                   = now()
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'reminder_hour', p_reminder_hour,
        'reminder_minute', p_reminder_minute,
        'user_timezone', p_user_timezone,
        'fsrs_desired_retention', p_desired_retention
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.upsert_notification_preferences(INT, INT, TEXT, FLOAT) TO authenticated;

-- 3. pg_cron: Spaced-repetition due alert — runs at 08:00 UTC daily
--    Calls trigger-notifications edge function with action=spaced_repetition_due
DO $$
DECLARE
    v_supabase_url  TEXT := current_setting('app.supabase_url', true);
    v_cron_secret   TEXT := current_setting('app.cron_secret',  true);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        RAISE NOTICE 'pg_cron not installed — skipping cron job registration';
        RETURN;
    END IF;

    -- Remove stale versions first (idempotent)
    PERFORM cron.unschedule('kortex-spaced-repetition-due')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kortex-spaced-repetition-due');

    PERFORM cron.unschedule('kortex-daily-streak-reminder')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kortex-daily-streak-reminder');

    -- Spaced repetition due check: 08:00 UTC daily
    IF v_supabase_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
        PERFORM cron.schedule(
            'kortex-spaced-repetition-due',
            '0 8 * * *',
            format(
                $$SELECT net.http_post(
                    url := %L || '/functions/v1/trigger-notifications',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'X-Cron-Secret', %L
                    ),
                    body := '{"action":"spaced_repetition_due"}'::jsonb
                )$$,
                v_supabase_url,
                v_cron_secret
            )
        );

        -- Daily streak reminder: 20:00 UTC (catches most timezones before midnight)
        PERFORM cron.schedule(
            'kortex-daily-streak-reminder',
            '0 20 * * *',
            format(
                $$SELECT net.http_post(
                    url := %L || '/functions/v1/trigger-notifications',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'X-Cron-Secret', %L
                    ),
                    body := '{"action":"daily_streak_reminder"}'::jsonb
                )$$,
                v_supabase_url,
                v_cron_secret
            )
        );

        RAISE NOTICE 'Registered kortex-spaced-repetition-due and kortex-daily-streak-reminder cron jobs';
    ELSE
        RAISE NOTICE 'app.supabase_url or app.cron_secret not set — cron jobs skipped. Set them via ALTER DATABASE ... SET app.supabase_url=...';
    END IF;
END $$;
