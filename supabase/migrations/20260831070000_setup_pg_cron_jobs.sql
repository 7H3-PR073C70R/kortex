-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 007 - Automated Background Maintenance Jobs
-- Extensions: pg_cron, pg_net
-- Jobs: Daily Streaks, Weekly Leaderboards, Ephemeral Storage & Cache Cleanup
-- ==============================================================================

-- 1. Enable Required Maintenance Extensions
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- ==============================================================================
-- 2. Daily Streak Maintenance Function
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.maintain_daily_streaks()
RETURNS void AS $$
DECLARE
    cutoff_date DATE := CURRENT_DATE - INTERVAL '1 day';
BEGIN
    -- Reset streak to 0 for users who had zero activity recorded yesterday or today
    UPDATE public.user_analytics ua
    SET current_streak_days = 0,
        updated_at = now()
    WHERE ua.user_id NOT IN (
        SELECT DISTINCT user_id
        FROM public.heatmap_activity
        WHERE activity_date >= cutoff_date
          AND (cards_reviewed > 0 OR minutes_studied > 0)
    )
    AND ua.current_streak_days > 0;

    -- Mirror streak reset to user profiles table
    UPDATE public.profiles p
    SET streak_days = 0,
        updated_at = now()
    WHERE p.id NOT IN (
        SELECT DISTINCT user_id
        FROM public.heatmap_activity
        WHERE activity_date >= cutoff_date
          AND (cards_reviewed > 0 OR minutes_studied > 0)
    )
    AND p.streak_days > 0;

    -- Mirror streak update in leaderboards table
    UPDATE public.leaderboards l
    SET streak_days = COALESCE(
        (SELECT p.streak_days FROM public.profiles p WHERE p.id = l.user_id),
        0
    ),
    updated_at = now();

    RAISE NOTICE 'Daily streak maintenance completed successfully at %', now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 3. Weekly Leaderboard Rank Aggregation Function
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.aggregate_weekly_leaderboards()
RETURNS void AS $$
DECLARE
    week_start_date DATE := CURRENT_DATE - INTERVAL '7 days';
BEGIN
    -- Temporary staging table for calculated weekly user XP
    CREATE TEMP TABLE tmp_weekly_user_xp ON COMMIT DROP AS
    WITH user_heatmap_xp AS (
        SELECT 
            user_id,
            SUM(cards_reviewed * 10 + minutes_studied * 2) AS study_xp
        FROM public.heatmap_activity
        WHERE activity_date >= week_start_date
        GROUP BY user_id
    ),
    user_forum_xp AS (
        SELECT 
            author_id AS user_id,
            COUNT(*) * 50 AS forum_xp
        FROM public.forum_posts
        WHERE created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    ),
    user_reply_xp AS (
        SELECT 
            author_id AS user_id,
            COUNT(*) * 25 AS reply_xp
        FROM public.forum_replies
        WHERE created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    )
    SELECT 
        p.id AS user_id,
        COALESCE(p.display_name, 'Anonymous Scholar') AS user_name,
        p.photo_url AS avatar_url,
        COALESCE(p.target_track, 'General') AS track,
        p.streak_days,
        (
            COALESCE(h.study_xp, 0) + 
            COALESCE(f.forum_xp, 0) + 
            COALESCE(r.reply_xp, 0)
        )::INT AS calculated_weekly_xp
    FROM public.profiles p
    LEFT JOIN user_heatmap_xp h ON p.id = h.user_id
    LEFT JOIN user_forum_xp f ON p.id = f.user_id
    LEFT JOIN user_reply_xp r ON p.id = r.user_id;

    -- Upsert aggregated records into leaderboards table
    INSERT INTO public.leaderboards (
        user_id,
        user_name,
        avatar_url,
        track,
        weekly_xp,
        streak_days,
        rank,
        updated_at
    )
    SELECT 
        t.user_id,
        t.user_name,
        t.avatar_url,
        t.track,
        t.calculated_weekly_xp,
        t.streak_days,
        DENSE_RANK() OVER (PARTITION BY t.track ORDER BY t.calculated_weekly_xp DESC)::INT AS rank,
        now()
    FROM tmp_weekly_user_xp t
    ON CONFLICT (id) DO UPDATE SET
        user_name = EXCLUDED.user_name,
        avatar_url = EXCLUDED.avatar_url,
        track = EXCLUDED.track,
        weekly_xp = EXCLUDED.weekly_xp,
        streak_days = EXCLUDED.streak_days,
        rank = EXCLUDED.rank,
        updated_at = now();

    -- Recalculate dense ranks for all tracks
    WITH ranked AS (
        SELECT 
            id,
            DENSE_RANK() OVER (PARTITION BY track ORDER BY weekly_xp DESC) AS new_rank
        FROM public.leaderboards
    )
    UPDATE public.leaderboards l
    SET rank = r.new_rank,
        updated_at = now()
    FROM ranked r
    WHERE l.id = r.id;

    RAISE NOTICE 'Weekly leaderboard aggregation completed successfully at %', now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 4. Ephemeral AI Cache & Storage Cleanup Function
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_cache()
RETURNS void AS $$
DECLARE
    purged_chunks_count INT := 0;
    purged_sessions_count INT := 0;
BEGIN
    -- 1. Purge orphaned document vector embeddings whose parent document was deleted
    WITH deleted_chunks AS (
        DELETE FROM public.document_chunks
        WHERE document_id IS NOT NULL 
          AND document_id NOT IN (SELECT id FROM public.documents)
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_chunks_count FROM deleted_chunks;

    -- 2. Purge expired guest chat sessions older than 30 days
    WITH deleted_sessions AS (
        DELETE FROM public.chat_sessions
        WHERE created_at < (now() - INTERVAL '30 days')
          AND title LIKE '%Guest%'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_sessions_count FROM deleted_sessions;

    -- 3. Purge orphaned chat messages whose session was removed
    DELETE FROM public.chat_messages
    WHERE session_id NOT IN (SELECT id FROM public.chat_sessions);

    RAISE NOTICE 'Ephemeral cache cleanup complete: % vector chunks and % chat sessions purged at %',
        purged_chunks_count, purged_sessions_count, now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 5. Register pg_cron Scheduled Maintenance Jobs
-- ==============================================================================

-- Remove existing job registrations if present to ensure clean idempotent migrations
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Daily Streaks: Every day at 00:05 UTC (5 0 * * *)
        PERFORM cron.unschedule('maintain-daily-streaks')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintain-daily-streaks');

        PERFORM cron.schedule(
            'maintain-daily-streaks',
            '5 0 * * *',
            'SELECT public.maintain_daily_streaks();'
        );

        -- Weekly Leaderboards: Every Sunday at 23:50 UTC (50 23 * * 0)
        PERFORM cron.unschedule('aggregate-weekly-leaderboards')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'aggregate-weekly-leaderboards');

        PERFORM cron.schedule(
            'aggregate-weekly-leaderboards',
            '50 23 * * 0',
            'SELECT public.aggregate_weekly_leaderboards();'
        );

        -- Ephemeral Cache Cleanup: 1st of every month at 02:00 UTC (0 2 1 * *)
        PERFORM cron.unschedule('cleanup-ephemeral-cache')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-ephemeral-cache');

        PERFORM cron.schedule(
            'cleanup-ephemeral-cache',
            '0 2 1 * *',
            'SELECT public.cleanup_ephemeral_cache();'
        );
    END IF;
END $$;
