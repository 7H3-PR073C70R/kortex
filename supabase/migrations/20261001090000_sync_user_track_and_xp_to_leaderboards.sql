-- ============================================================================
-- Migration: 20261001090000_sync_user_track_and_xp_to_leaderboards.sql
-- Description: Synchronize user academic track and live XP to leaderboards table,
--              ensuring user_id uniqueness and automatic upserts on profile updates.
-- ============================================================================

-- 0. Ensure required columns exist on public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS xp_points INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS streak_days INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS target_track TEXT DEFAULT 'General';

-- 1. Deduplicate any existing leaderboards rows per user_id keeping the highest weekly_xp
DELETE FROM public.leaderboards a
USING public.leaderboards b
WHERE a.user_id = b.user_id 
  AND a.id <> b.id 
  AND (a.weekly_xp < b.weekly_xp OR (a.weekly_xp = b.weekly_xp AND a.updated_at < b.updated_at));

-- 2. Add unique constraint on user_id to enable atomic UPSERTs
CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboards_user_id ON public.leaderboards(user_id);

-- 3. Trigger function to synchronize profiles (track, xp_points, streak, name, avatar) to leaderboards
CREATE OR REPLACE FUNCTION public.sync_profile_to_leaderboard()
RETURNS TRIGGER AS $$
DECLARE
    v_tier TEXT := 'Bronze';
    v_xp INT := 0;
BEGIN
    v_xp := COALESCE(NEW.xp_points, 0);

    -- Calculate league tier based on XP
    IF v_xp >= 1000 THEN
        v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN
        v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN
        v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN
        v_tier := 'Silver';
    ELSE
        v_tier := 'Bronze';
    END IF;

    INSERT INTO public.leaderboards (
        user_id,
        user_name,
        avatar_url,
        track,
        weekly_xp,
        daily_xp,
        streak_days,
        league_tier,
        rank,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.display_name, ''), 'Scholar'),
        NEW.photo_url,
        COALESCE(NULLIF(NEW.target_track, ''), 'WAEC'),
        v_xp,
        v_xp,
        GREATEST(1, COALESCE(NEW.streak_days, 1)),
        v_tier,
        1,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        track = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        weekly_xp = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp = EXCLUDED.daily_xp,
        streak_days = GREATEST(leaderboards.streak_days, EXCLUDED.streak_days),
        league_tier = EXCLUDED.league_tier,
        updated_at = now();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to profiles for both INSERT and UPDATE of track and XP
DROP TRIGGER IF EXISTS trg_sync_profile_to_leaderboard ON public.profiles;
CREATE TRIGGER trg_sync_profile_to_leaderboard
AFTER INSERT OR UPDATE OF streak_days, display_name, photo_url, target_track, xp_points ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_to_leaderboard();

-- 4. Trigger function for user_analytics updates (xp_points, current_streak_days)
CREATE OR REPLACE FUNCTION public.sync_analytics_to_leaderboard()
RETURNS TRIGGER AS $$
DECLARE
    v_xp INT := 0;
    v_tier TEXT := 'Bronze';
BEGIN
    v_xp := COALESCE(NEW.xp_points, 0);

    IF v_xp >= 1000 THEN
        v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN
        v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN
        v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN
        v_tier := 'Silver';
    ELSE
        v_tier := 'Bronze';
    END IF;

    UPDATE public.leaderboards
    SET 
        weekly_xp = GREATEST(leaderboards.weekly_xp, v_xp),
        streak_days = GREATEST(leaderboards.streak_days, COALESCE(NEW.current_streak_days, 1)),
        league_tier = CASE 
            WHEN v_xp >= 1000 THEN 'Dean''s List'
            WHEN v_xp >= 600 THEN 'Diamond'
            WHEN v_xp >= 350 THEN 'Gold'
            WHEN v_xp >= 150 THEN 'Silver'
            ELSE leaderboards.league_tier
        END,
        updated_at = now()
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_analytics_to_leaderboard ON public.user_analytics;
CREATE TRIGGER trg_sync_analytics_to_leaderboard
AFTER UPDATE OF xp_points, current_streak_days ON public.user_analytics
FOR EACH ROW EXECUTE FUNCTION public.sync_analytics_to_leaderboard();

-- 5. Backfill all existing scholars into leaderboards with their real academic track, XP, and streak
INSERT INTO public.leaderboards (
    user_id,
    user_name,
    avatar_url,
    track,
    weekly_xp,
    daily_xp,
    streak_days,
    league_tier,
    rank,
    updated_at
)
SELECT 
    p.id AS user_id,
    COALESCE(NULLIF(p.display_name, ''), 'Scholar') AS user_name,
    p.photo_url AS avatar_url,
    COALESCE(NULLIF(p.target_track, ''), 'WAEC') AS track,
    GREATEST(
        COALESCE(p.xp_points, 0),
        COALESCE(ua.xp_points, 0)
    ) AS weekly_xp,
    COALESCE(p.xp_points, 0) AS daily_xp,
    GREATEST(1, COALESCE(p.streak_days, 1), COALESCE(ua.current_streak_days, 1)) AS streak_days,
    CASE 
        WHEN GREATEST(COALESCE(p.xp_points, 0), COALESCE(ua.xp_points, 0)) >= 1000 THEN 'Dean''s List'
        WHEN GREATEST(COALESCE(p.xp_points, 0), COALESCE(ua.xp_points, 0)) >= 600 THEN 'Diamond'
        WHEN GREATEST(COALESCE(p.xp_points, 0), COALESCE(ua.xp_points, 0)) >= 350 THEN 'Gold'
        WHEN GREATEST(COALESCE(p.xp_points, 0), COALESCE(ua.xp_points, 0)) >= 150 THEN 'Silver'
        ELSE 'Bronze'
    END AS league_tier,
    1 AS rank,
    now() AS updated_at
FROM public.profiles p
LEFT JOIN public.user_analytics ua ON p.id = ua.user_id
ON CONFLICT (user_id) DO UPDATE SET
    user_name = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
    track = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
    weekly_xp = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
    daily_xp = EXCLUDED.daily_xp,
    streak_days = GREATEST(leaderboards.streak_days, EXCLUDED.streak_days),
    league_tier = EXCLUDED.league_tier,
    updated_at = now();

-- 6. Recalculate ranks across all leaderboards rows
WITH ranked AS (
    SELECT id, DENSE_RANK() OVER (ORDER BY weekly_xp DESC) as new_rank
    FROM public.leaderboards
)
UPDATE public.leaderboards l
SET rank = r.new_rank
FROM ranked r
WHERE l.id = r.id;

-- 7. Define claim_weekly_xp RPC for explicit client-driven sync
CREATE OR REPLACE FUNCTION public.claim_weekly_xp(
    p_xp_amount INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_profile RECORD;
    v_xp INT := 0;
    v_tier TEXT := 'Bronze';
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    v_xp := GREATEST(COALESCE(p_xp_amount, 0), COALESCE(v_profile.xp_points, 0));

    IF v_xp >= 1000 THEN
        v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN
        v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN
        v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN
        v_tier := 'Silver';
    ELSE
        v_tier := 'Bronze';
    END IF;

    INSERT INTO public.leaderboards (
        user_id,
        user_name,
        avatar_url,
        track,
        weekly_xp,
        daily_xp,
        streak_days,
        league_tier,
        rank,
        updated_at
    )
    VALUES (
        v_user_id,
        COALESCE(NULLIF(v_profile.display_name, ''), 'Scholar'),
        v_profile.photo_url,
        COALESCE(NULLIF(v_profile.target_track, ''), 'WAEC'),
        v_xp,
        v_xp,
        GREATEST(1, COALESCE(v_profile.streak_days, 1)),
        v_tier,
        1,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        track = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        weekly_xp = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp = EXCLUDED.daily_xp,
        streak_days = GREATEST(leaderboards.streak_days, EXCLUDED.streak_days),
        league_tier = EXCLUDED.league_tier,
        updated_at = now();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'weekly_xp', v_xp,
        'track', COALESCE(NULLIF(v_profile.target_track, ''), 'WAEC'),
        'league_tier', v_tier
    );
END;
$$;
