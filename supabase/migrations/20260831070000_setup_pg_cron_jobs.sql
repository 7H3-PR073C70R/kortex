-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 007 - Automated Background Maintenance Jobs
-- Extensions: pg_cron, pg_net
-- Jobs: Timezone-Aware Daily Streaks, Tiered Weekly Leaderboards, Cache Cleanup
-- ==============================================================================

-- 1. Enable Required Maintenance Extensions
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 2. Enhance user profiles with streak protection & timezone
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS streak_freeze_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS last_streak_saved_at TIMESTAMPTZ;

-- ==============================================================================
-- 3. Timezone-Aware Daily Streak & Freeze Maintenance Function
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.maintain_daily_streaks()
RETURNS void AS $$
DECLARE
    -- 36-hour grace window to comfortably accommodate any worldwide timezone
    cutoff_time TIMESTAMPTZ := now() - INTERVAL '36 hours';
BEGIN
    -- A. Users with active streaks who studied within the grace period:
    -- Reward streak freezes at 7-day milestones (capped at 2)
    UPDATE public.profiles p
    SET streak_freeze_count = LEAST(streak_freeze_count + 1, 2),
        updated_at = now()
    WHERE p.streak_days > 0 
      AND p.streak_days % 7 = 0
      AND p.streak_freeze_count < 2
      AND p.id IN (
          SELECT DISTINCT user_id
          FROM public.heatmap_activity
          WHERE activity_date >= (CURRENT_DATE - INTERVAL '1 day')
            AND (cards_reviewed > 0 OR minutes_studied > 0)
      );

    -- B. Users who missed studying: Check if Streak Freeze is available
    -- If freeze available: Consume 1 freeze and protect the streak!
    UPDATE public.profiles p
    SET streak_freeze_count = streak_freeze_count - 1,
        last_streak_saved_at = now(),
        updated_at = now()
    WHERE p.streak_days > 0
      AND p.streak_freeze_count > 0
      AND p.id NOT IN (
          SELECT DISTINCT user_id
          FROM public.heatmap_activity
          WHERE activity_date >= (CURRENT_DATE - INTERVAL '1 day')
            AND (cards_reviewed > 0 OR minutes_studied > 0)
      );

    -- C. Users who missed studying AND have zero freezes left: Reset streak
    UPDATE public.profiles p
    SET streak_days = 0,
        updated_at = now()
    WHERE p.streak_days > 0
      AND p.streak_freeze_count = 0
      AND p.id NOT IN (
          SELECT DISTINCT user_id
          FROM public.heatmap_activity
          WHERE activity_date >= (CURRENT_DATE - INTERVAL '1 day')
            AND (cards_reviewed > 0 OR minutes_studied > 0)
      );

    -- D. Mirror streaks to user_analytics
    UPDATE public.user_analytics ua
    SET current_streak_days = COALESCE(
        (SELECT p.streak_days FROM public.profiles p WHERE p.id = ua.user_id),
        0
    ),
    updated_at = now();

    -- E. Mirror streaks to leaderboards
    UPDATE public.leaderboards l
    SET streak_days = COALESCE(
        (SELECT p.streak_days FROM public.profiles p WHERE p.id = l.user_id),
        0
    ),
    updated_at = now();

    RAISE NOTICE 'Timezone-aware streak maintenance completed with freeze protection at %', now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 4. Quality-Weighted Weekly Leaderboard Rank & League Aggregation
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.aggregate_weekly_leaderboards()
RETURNS void AS $$
DECLARE
    week_start_date DATE := CURRENT_DATE - INTERVAL '7 days';
BEGIN
    -- Temporary staging table for calculated weekly user XP based on real study and peer help
    CREATE TEMP TABLE tmp_weekly_user_xp ON COMMIT DROP AS
    WITH user_study_xp AS (
        -- 5 XP per flashcard reviewed, 2 XP per minute focused
        SELECT 
            user_id,
            SUM(cards_reviewed * 5 + minutes_studied * 2) AS study_xp
        FROM public.heatmap_activity
        WHERE activity_date >= week_start_date
        GROUP BY user_id
    ),
    user_verified_solution_xp AS (
        -- 100 XP for each peer question solved and marked as verified solution
        SELECT 
            author_id AS user_id,
            COUNT(*) * 100 AS solution_xp
        FROM public.forum_replies
        WHERE is_verified_solution = true
          AND created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    ),
    user_peer_upvotes_xp AS (
        -- 15 XP for every upvote received from peers on solutions
        SELECT 
            author_id AS user_id,
            SUM(upvotes) * 15 AS upvote_xp
        FROM public.forum_replies
        WHERE created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    ),
    user_shared_deck_clones_xp AS (
        -- 25 XP when another student clones their shared deck
        SELECT 
            owner_id AS user_id,
            SUM(downloads_count) * 25 AS deck_xp
        FROM public.shared_decks
        WHERE updated_at >= now() - INTERVAL '7 days'
        GROUP BY owner_id
    )
    SELECT 
        p.id AS user_id,
        COALESCE(p.display_name, 'Scholar') AS user_name,
        p.photo_url AS avatar_url,
        COALESCE(p.target_track, 'General') AS track,
        p.streak_days,
        (
            COALESCE(s.study_xp, 0) + 
            COALESCE(v.solution_xp, 0) + 
            COALESCE(u.upvote_xp, 0) +
            COALESCE(d.deck_xp, 0)
        )::INT AS calculated_weekly_xp,
        CASE
            WHEN (COALESCE(s.study_xp, 0) + COALESCE(v.solution_xp, 0) + COALESCE(u.upvote_xp, 0) + COALESCE(d.deck_xp, 0)) >= 1000 THEN 'Dean''s List'
            WHEN (COALESCE(s.study_xp, 0) + COALESCE(v.solution_xp, 0) + COALESCE(u.upvote_xp, 0) + COALESCE(d.deck_xp, 0)) >= 600 THEN 'Diamond'
            WHEN (COALESCE(s.study_xp, 0) + COALESCE(v.solution_xp, 0) + COALESCE(u.upvote_xp, 0) + COALESCE(d.deck_xp, 0)) >= 350 THEN 'Gold'
            WHEN (COALESCE(s.study_xp, 0) + COALESCE(v.solution_xp, 0) + COALESCE(u.upvote_xp, 0) + COALESCE(d.deck_xp, 0)) >= 150 THEN 'Silver'
            ELSE 'Bronze'
        END AS calculated_league_tier
    FROM public.profiles p
    LEFT JOIN user_study_xp s ON p.id = s.user_id
    LEFT JOIN user_verified_solution_xp v ON p.id = v.user_id
    LEFT JOIN user_peer_upvotes_xp u ON p.id = u.user_id
    LEFT JOIN user_shared_deck_clones_xp d ON p.id = d.user_id;

    -- Upsert aggregated records into leaderboards table
    INSERT INTO public.leaderboards (
        user_id,
        user_name,
        avatar_url,
        track,
        weekly_xp,
        streak_days,
        league_tier,
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
        t.calculated_league_tier,
        DENSE_RANK() OVER (PARTITION BY t.track ORDER BY t.calculated_weekly_xp DESC)::INT AS rank,
        now()
    FROM tmp_weekly_user_xp t
    ON CONFLICT (id) DO UPDATE SET
        user_name = EXCLUDED.user_name,
        avatar_url = EXCLUDED.avatar_url,
        track = EXCLUDED.track,
        weekly_xp = EXCLUDED.weekly_xp,
        streak_days = EXCLUDED.streak_days,
        league_tier = EXCLUDED.league_tier,
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

    RAISE NOTICE 'Tiered quality-weighted leaderboard aggregation completed successfully at %', now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 5. Ephemeral AI Cache & Storage Cleanup Function
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_cache()
RETURNS void AS $$
DECLARE
    purged_chunks_count INT := 0;
    purged_sessions_count INT := 0;
BEGIN
    -- Purge orphaned document vector embeddings whose parent document was deleted
    WITH deleted_chunks AS (
        DELETE FROM public.document_chunks
        WHERE document_id IS NOT NULL 
          AND document_id NOT IN (SELECT id FROM public.documents)
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_chunks_count FROM deleted_chunks;

    -- Purge expired guest chat sessions older than 30 days
    WITH deleted_sessions AS (
        DELETE FROM public.chat_sessions
        WHERE created_at < (now() - INTERVAL '30 days')
          AND title LIKE '%Guest%'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_sessions_count FROM deleted_sessions;

    -- Purge orphaned chat messages whose session was removed
    DELETE FROM public.chat_messages
    WHERE session_id NOT IN (SELECT id FROM public.chat_sessions);

    RAISE NOTICE 'Ephemeral cache cleanup complete: % vector chunks and % chat sessions purged at %',
        purged_chunks_count, purged_sessions_count, now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 6. Register pg_cron Scheduled Maintenance Jobs
-- ==============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Daily Streaks & Freeze: Runs every 4 hours to catch rolling local timezones
        PERFORM cron.unschedule('maintain-daily-streaks')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintain-daily-streaks');

        PERFORM cron.schedule(
            'maintain-daily-streaks',
            '0 */4 * * *',
            'SELECT public.maintain_daily_streaks();'
        );

        -- Weekly Leaderboards & Leagues: Every Sunday at 23:50 UTC (50 23 * * 0)
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
