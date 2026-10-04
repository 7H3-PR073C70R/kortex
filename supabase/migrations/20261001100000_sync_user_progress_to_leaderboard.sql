-- ============================================================================
-- Migration: 20261001100000_sync_user_progress_to_leaderboard.sql
-- Description: Single authoritative RPC for client-driven leaderboard sync.
--   The client calls sync_user_progress after awarding XP or updating streak.
--   This atomically updates profiles (which fires existing triggers to
--   leaderboards) and also directly upserts leaderboards for immediate
--   realtime visibility.
-- ============================================================================

-- 0. Ensure profiles table columns exist and leaderboards.user_name has default
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS xp_points INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS streak_days INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS target_track TEXT DEFAULT 'General';

ALTER TABLE public.leaderboards
    ALTER COLUMN user_name SET DEFAULT 'Scholar';

-- 1. sync_user_progress: canonical client-driven leaderboard sync endpoint
--    Parameters:
--      p_xp_delta  INT  -- XP earned in this event (added cumulatively)
--      p_streak    INT  -- Current streak days (exact value, replaces stored)
--      p_track     TEXT -- User's academic track (e.g. 'WAEC','JAMB','IGCSE')
CREATE OR REPLACE FUNCTION public.sync_user_progress(
    p_xp_delta  INT  DEFAULT 0,
    p_streak    INT  DEFAULT NULL,
    p_track     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id         UUID;
    v_new_xp          INT;
    v_new_streak      INT;
    v_effective_track  TEXT;
    v_tier            TEXT;
    v_multiplier      NUMERIC(3,2) := 1.00;
    v_xp_to_add       INT;
    v_display_name    TEXT;
    v_avatar_url      TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    v_new_streak := COALESCE(p_streak, 0);
    IF v_new_streak >= 30 THEN v_multiplier := 2.00;
    ELSIF v_new_streak >= 14 THEN v_multiplier := 1.75;
    ELSIF v_new_streak >= 7  THEN v_multiplier := 1.50;
    ELSIF v_new_streak >= 4  THEN v_multiplier := 1.25;
    END IF;

    v_xp_to_add := GREATEST(0, ROUND(COALESCE(p_xp_delta, 0) * v_multiplier));

    -- Atomically update profiles; the existing trigger fires to leaderboards.
    UPDATE public.profiles
    SET
        xp_points    = COALESCE(xp_points, 0) + v_xp_to_add,
        streak_days  = CASE
                           WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                           ELSE streak_days
                       END,
        target_track = CASE
                           WHEN p_track IS NOT NULL AND p_track <> ''
                               THEN p_track
                           ELSE target_track
                       END,
        updated_at   = now()
    WHERE id = v_user_id
    RETURNING xp_points, streak_days, target_track, display_name, photo_url
    INTO v_new_xp, v_new_streak, v_effective_track, v_display_name, v_avatar_url;

    IF NOT FOUND THEN
        SELECT 
            COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', split_part(email, '@', 1), 'Scholar'),
            raw_user_meta_data->>'avatar_url'
        INTO v_display_name, v_avatar_url
        FROM auth.users
        WHERE id = v_user_id;

        INSERT INTO public.profiles (id, email, display_name, photo_url, xp_points, streak_days, target_track)
        VALUES (
            v_user_id,
            COALESCE((SELECT email FROM auth.users WHERE id = v_user_id), ''),
            COALESCE(NULLIF(v_display_name, ''), 'Scholar'),
            v_avatar_url,
            v_xp_to_add,
            GREATEST(0, COALESCE(p_streak, 0)),
            COALESCE(NULLIF(p_track, ''), 'General')
        )
        ON CONFLICT (id) DO UPDATE SET
            xp_points    = profiles.xp_points + v_xp_to_add,
            streak_days  = CASE WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak) ELSE profiles.streak_days END,
            target_track = CASE WHEN p_track IS NOT NULL AND p_track <> '' THEN p_track ELSE profiles.target_track END
        RETURNING xp_points, streak_days, target_track, display_name, photo_url
        INTO v_new_xp, v_new_streak, v_effective_track, v_display_name, v_avatar_url;
    END IF;

    -- Ensure we have a valid display_name fallback
    IF v_display_name IS NULL OR TRIM(v_display_name) = '' THEN
        SELECT 
            COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', split_part(email, '@', 1), 'Scholar')
        INTO v_display_name
        FROM auth.users
        WHERE id = v_user_id;
    END IF;
    v_display_name := COALESCE(NULLIF(TRIM(v_display_name), ''), 'Scholar');

    IF v_new_xp >= 1000 THEN v_tier := 'Dean''s List';
    ELSIF v_new_xp >= 600 THEN v_tier := 'Diamond';
    ELSIF v_new_xp >= 350 THEN v_tier := 'Gold';
    ELSIF v_new_xp >= 150 THEN v_tier := 'Silver';
    ELSE v_tier := 'Bronze';
    END IF;

    -- Direct upsert for immediate realtime push (belt-and-suspenders).
    INSERT INTO public.leaderboards (
        user_id, user_name, avatar_url, weekly_xp, daily_xp, streak_days, track, league_tier, rank, updated_at
    ) VALUES (
        v_user_id,
        v_display_name,
        v_avatar_url,
        v_new_xp,
        v_new_xp,
        GREATEST(0, v_new_streak),
        COALESCE(NULLIF(v_effective_track, ''), 'General'),
        v_tier,
        1,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name   = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name, 'Scholar'),
        avatar_url  = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        weekly_xp   = EXCLUDED.weekly_xp,
        streak_days = EXCLUDED.streak_days,
        track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        league_tier = EXCLUDED.league_tier,
        updated_at  = EXCLUDED.updated_at;

    -- Sync to user_analytics for dashboard consistency.
    INSERT INTO public.user_analytics (user_id, xp_points, current_streak_days)
    VALUES (v_user_id, v_new_xp, GREATEST(0, v_new_streak))
    ON CONFLICT (user_id) DO UPDATE SET
        xp_points           = EXCLUDED.xp_points,
        current_streak_days = CASE
                                  WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                                  ELSE user_analytics.current_streak_days
                              END,
        updated_at          = now();

    RETURN jsonb_build_object(
        'success',     true,
        'user_id',     v_user_id,
        'total_xp',    v_new_xp,
        'xp_added',    v_xp_to_add,
        'streak_days', v_new_streak,
        'track',       v_effective_track,
        'league_tier', v_tier,
        'multiplier',  v_multiplier
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_user_progress(INT, INT, TEXT) TO authenticated;

-- 2. Fix claim_weekly_xp to use profiles as source of truth (not just client value)
CREATE OR REPLACE FUNCTION public.claim_weekly_xp(p_xp_amount INT DEFAULT 0)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_profile RECORD;
    v_xp      INT;
    v_tier    TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT xp_points, streak_days, target_track, display_name, photo_url
    INTO v_profile FROM public.profiles WHERE id = v_user_id;

    v_xp := GREATEST(COALESCE(p_xp_amount, 0), COALESCE(v_profile.xp_points, 0));

    IF v_xp >= 1000 THEN v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN v_tier := 'Silver';
    ELSE v_tier := 'Bronze';
    END IF;

    INSERT INTO public.leaderboards (
        user_id, user_name, avatar_url, track,
        weekly_xp, daily_xp, streak_days, league_tier, rank, updated_at
    ) VALUES (
        v_user_id,
        COALESCE(NULLIF(v_profile.display_name, ''), 'Scholar'),
        v_profile.photo_url,
        COALESCE(NULLIF(v_profile.target_track, ''), 'General'),
        v_xp, v_xp,
        GREATEST(0, COALESCE(v_profile.streak_days, 0)),
        v_tier, 1, now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name   = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
        avatar_url  = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp    = EXCLUDED.daily_xp,
        streak_days = EXCLUDED.streak_days,
        league_tier = EXCLUDED.league_tier,
        updated_at  = now();

    RETURN jsonb_build_object(
        'success', true, 'user_id', v_user_id,
        'weekly_xp', v_xp,
        'track', COALESCE(NULLIF(v_profile.target_track, ''), 'General'),
        'league_tier', v_tier
    );
END;
$$;

-- 3. Fix profile trigger: streak can decrease (reset is legitimate)
CREATE OR REPLACE FUNCTION public.sync_profile_to_leaderboard()
RETURNS TRIGGER AS $$
DECLARE
    v_tier TEXT := 'Bronze';
    v_xp   INT  := COALESCE(NEW.xp_points, 0);
BEGIN
    IF v_xp >= 1000 THEN v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN v_tier := 'Silver';
    END IF;

    INSERT INTO public.leaderboards (
        user_id, user_name, avatar_url, track,
        weekly_xp, daily_xp, streak_days, league_tier, rank, updated_at
    ) VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.display_name, ''), 'Scholar'),
        NEW.photo_url,
        COALESCE(NULLIF(NEW.target_track, ''), 'General'),
        v_xp, v_xp,
        GREATEST(0, COALESCE(NEW.streak_days, 0)),
        v_tier, 1, now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name   = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
        avatar_url  = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp    = EXCLUDED.daily_xp,
        -- Streak can decrease: do NOT use GREATEST
        streak_days = EXCLUDED.streak_days,
        league_tier = EXCLUDED.league_tier,
        updated_at  = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_profile_to_leaderboard ON public.profiles;
CREATE TRIGGER trg_sync_profile_to_leaderboard
AFTER INSERT OR UPDATE OF xp_points, streak_days, display_name, photo_url, target_track
ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_to_leaderboard();

-- 4. Recalculate ranks now
WITH ranked AS (
    SELECT id, DENSE_RANK() OVER (ORDER BY weekly_xp DESC NULLS LAST) AS new_rank
    FROM public.leaderboards
)
UPDATE public.leaderboards l SET rank = r.new_rank FROM ranked r WHERE l.id = r.id;

-- 5. Backfill every profile into leaderboards with real data
INSERT INTO public.leaderboards (
    user_id, user_name, avatar_url, track,
    weekly_xp, daily_xp, streak_days, league_tier, rank, updated_at
)
SELECT
    p.id,
    COALESCE(NULLIF(p.display_name, ''), 'Scholar'),
    p.photo_url,
    COALESCE(NULLIF(p.target_track, ''), 'General'),
    GREATEST(0, COALESCE(p.xp_points, 0), COALESCE(ua.xp_points, 0)),
    COALESCE(p.xp_points, 0),
    GREATEST(0, COALESCE(p.streak_days, 0), COALESCE(ua.current_streak_days, 0)),
    CASE
        WHEN GREATEST(COALESCE(p.xp_points,0), COALESCE(ua.xp_points,0)) >= 1000 THEN 'Dean''s List'
        WHEN GREATEST(COALESCE(p.xp_points,0), COALESCE(ua.xp_points,0)) >= 600  THEN 'Diamond'
        WHEN GREATEST(COALESCE(p.xp_points,0), COALESCE(ua.xp_points,0)) >= 350  THEN 'Gold'
        WHEN GREATEST(COALESCE(p.xp_points,0), COALESCE(ua.xp_points,0)) >= 150  THEN 'Silver'
        ELSE 'Bronze'
    END,
    1, now()
FROM public.profiles p
LEFT JOIN public.user_analytics ua ON p.id = ua.user_id
ON CONFLICT (user_id) DO UPDATE SET
    user_name   = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
    avatar_url  = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
    track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
    weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
    streak_days = GREATEST(leaderboards.streak_days, EXCLUDED.streak_days),
    league_tier = EXCLUDED.league_tier,
    updated_at  = now()
WHERE leaderboards.updated_at < now() - interval '1 hour';
