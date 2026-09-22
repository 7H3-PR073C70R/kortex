
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS streak_freeze_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS last_streak_saved_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.maintain_daily_streaks()
RETURNS void AS $$
DECLARE
    cutoff_time TIMESTAMPTZ := now() - INTERVAL '36 hours';
BEGIN
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

    UPDATE public.user_analytics ua
    SET current_streak_days = COALESCE(
        (SELECT p.streak_days FROM public.profiles p WHERE p.id = ua.user_id),
        0
    ),
    updated_at = now();

    UPDATE public.leaderboards l
    SET streak_days = COALESCE(
        (SELECT p.streak_days FROM public.profiles p WHERE p.id = l.user_id),
        0
    ),
    updated_at = now();

    RAISE NOTICE 'Timezone-aware streak maintenance completed with freeze protection at %', now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.aggregate_weekly_leaderboards()
RETURNS void AS $$
DECLARE
    week_start_date DATE := CURRENT_DATE - INTERVAL '7 days';
BEGIN
    CREATE TEMP TABLE tmp_weekly_user_xp ON COMMIT DROP AS
    WITH user_study_xp AS (
        SELECT 
            user_id,
            SUM(cards_reviewed * 5 + minutes_studied * 2) AS study_xp
        FROM public.heatmap_activity
        WHERE activity_date >= week_start_date
        GROUP BY user_id
    ),
    user_verified_solution_xp AS (
        SELECT 
            author_id AS user_id,
            COUNT(*) * 100 AS solution_xp
        FROM public.forum_replies
        WHERE is_verified_solution = true
          AND created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    ),
    user_peer_upvotes_xp AS (
        SELECT 
            author_id AS user_id,
            SUM(upvotes) * 15 AS upvote_xp
        FROM public.forum_replies
        WHERE created_at >= now() - INTERVAL '7 days'
        GROUP BY author_id
    ),
    user_shared_deck_clones_xp AS (
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

CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_cache()
RETURNS void AS $$
DECLARE
    purged_chunks_count INT := 0;
    purged_sessions_count INT := 0;
BEGIN
    WITH deleted_chunks AS (
        DELETE FROM public.document_chunks
        WHERE document_id IS NOT NULL 
          AND document_id NOT IN (SELECT id FROM public.documents)
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_chunks_count FROM deleted_chunks;

    WITH deleted_sessions AS (
        DELETE FROM public.chat_sessions
        WHERE created_at < (now() - INTERVAL '30 days')
          AND title LIKE '%Guest%'
        RETURNING id
    )
    SELECT COUNT(*) INTO purged_sessions_count FROM deleted_sessions;

    DELETE FROM public.chat_messages
    WHERE session_id NOT IN (SELECT id FROM public.chat_sessions);

    RAISE NOTICE 'Ephemeral cache cleanup complete: % vector chunks and % chat sessions purged at %',
        purged_chunks_count, purged_sessions_count, now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('maintain-daily-streaks')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'maintain-daily-streaks');

        PERFORM cron.schedule(
            'maintain-daily-streaks',
            '0 */4 * * *',
            'SELECT public.maintain_daily_streaks();'
        );

        PERFORM cron.unschedule('aggregate-weekly-leaderboards')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'aggregate-weekly-leaderboards');

        PERFORM cron.schedule(
            'aggregate-weekly-leaderboards',
            '50 23 * * 0',
            'SELECT public.aggregate_weekly_leaderboards();'
        );

        PERFORM cron.unschedule('cleanup-ephemeral-cache')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-ephemeral-cache');

        PERFORM cron.schedule(
            'cleanup-ephemeral-cache',
            '0 2 1 * *',
            'SELECT public.cleanup_ephemeral_cache();'
        );
    END IF;
END $$;
