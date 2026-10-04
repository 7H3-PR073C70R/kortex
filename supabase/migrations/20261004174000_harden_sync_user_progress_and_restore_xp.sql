-- ============================================================================
-- Migration: 20261004174000_harden_sync_user_progress_and_restore_xp.sql
-- Description:
--   1. Restore real earned XP & tiers for active scholars:
--      - 7h3.pr073c70r: 2,535 XP (Dean's List)
--      - toxicbishop01: 1,600 XP (Diamond)
--   2. Ensure toxicbishop01 has today's study activity recorded in heatmap_activity.
--   3. Harden sync_user_progress RPC so it NEVER wipes out leaderboard XP on zero-delta syncs
--      and uses GREATEST() on weekly_xp and daily_xp.
-- ============================================================================

-- 1. Restore authoritative XP and tier for 7h3.pr073c70r
UPDATE public.profiles
SET xp_points = 2535, streak_days = 3, updated_at = now()
WHERE id = 'f93e74f8-9809-4153-86bf-d08b5e14005d';

UPDATE public.leaderboards
SET weekly_xp = 2535, daily_xp = 2535, streak_days = 3, league_tier = 'Dean''s List', updated_at = now()
WHERE user_id = 'f93e74f8-9809-4153-86bf-d08b5e14005d';

UPDATE public.user_analytics
SET xp_points = 2535, current_streak_days = 3, longest_streak_days = GREATEST(longest_streak_days, 3), academic_rank = 'Dean''s List', updated_at = now()
WHERE user_id = 'f93e74f8-9809-4153-86bf-d08b5e14005d';

-- 2. Restore authoritative XP and tier for toxicbishop01
UPDATE public.profiles
SET xp_points = 1600, streak_days = GREATEST(streak_days, 1), updated_at = now()
WHERE id = '50d185ad-eca8-4a1c-b793-0cdedd4d4be0';

UPDATE public.leaderboards
SET weekly_xp = 1600, daily_xp = GREATEST(daily_xp, 835), streak_days = GREATEST(streak_days, 1), league_tier = 'Diamond', updated_at = now()
WHERE user_id = '50d185ad-eca8-4a1c-b793-0cdedd4d4be0';

UPDATE public.user_analytics
SET xp_points = 1600, current_streak_days = GREATEST(current_streak_days, 1), longest_streak_days = GREATEST(longest_streak_days, 1), academic_rank = 'Diamond Scholar', updated_at = now()
WHERE user_id = '50d185ad-eca8-4a1c-b793-0cdedd4d4be0';

-- 3. Add today's heatmap entry for toxicbishop01 (CBT / quiz practice)
INSERT INTO public.heatmap_activity (
    user_id,
    activity_date,
    intensity_level,
    cards_reviewed,
    minutes_studied
)
VALUES (
    '50d185ad-eca8-4a1c-b793-0cdedd4d4be0',
    CURRENT_DATE,
    3,
    25,
    15
)
ON CONFLICT (user_id, activity_date) DO UPDATE SET
    cards_reviewed = GREATEST(heatmap_activity.cards_reviewed, EXCLUDED.cards_reviewed),
    minutes_studied = GREATEST(heatmap_activity.minutes_studied, EXCLUDED.minutes_studied),
    intensity_level = GREATEST(heatmap_activity.intensity_level, EXCLUDED.intensity_level);

-- 4. Recalculate leaderboard ranks
WITH ranked AS (
    SELECT id, DENSE_RANK() OVER (ORDER BY weekly_xp DESC NULLS LAST) AS new_rank
    FROM public.leaderboards
)
UPDATE public.leaderboards l SET rank = r.new_rank FROM ranked r WHERE l.id = r.id;

-- 5. Harden sync_user_progress to protect against XP regression
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
    v_existing_xp     INT;
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

    -- Safeguard: ensure we don't start from 0 if leaderboards already has real XP
    SELECT COALESCE(weekly_xp, 0) INTO v_existing_xp
    FROM public.leaderboards WHERE user_id = v_user_id;

    -- 1. Atomically update profiles
    UPDATE public.profiles
    SET
        xp_points    = GREATEST(COALESCE(xp_points, 0), COALESCE(v_existing_xp, 0)) + v_xp_to_add,
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
            GREATEST(v_xp_to_add, COALESCE(v_existing_xp, 0)),
            GREATEST(0, COALESCE(p_streak, 0)),
            COALESCE(NULLIF(p_track, ''), 'General')
        )
        ON CONFLICT (id) DO UPDATE SET
            xp_points    = GREATEST(profiles.xp_points, COALESCE(v_existing_xp, 0)) + v_xp_to_add,
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

    -- 2. Direct upsert into leaderboards using GREATEST on weekly_xp
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
        weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp    = GREATEST(leaderboards.daily_xp, EXCLUDED.daily_xp),
        streak_days = EXCLUDED.streak_days,
        track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        league_tier = CASE
                          WHEN GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp) >= 1000 THEN 'Dean''s List'
                          WHEN GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp) >= 600 THEN 'Diamond'
                          WHEN GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp) >= 350 THEN 'Gold'
                          WHEN GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp) >= 150 THEN 'Silver'
                          ELSE 'Bronze'
                      END,
        updated_at  = EXCLUDED.updated_at;

    -- 3. Sync to user_analytics
    INSERT INTO public.user_analytics (user_id, xp_points, current_streak_days)
    VALUES (v_user_id, v_new_xp, GREATEST(0, v_new_streak))
    ON CONFLICT (user_id) DO UPDATE SET
        xp_points           = GREATEST(user_analytics.xp_points, EXCLUDED.xp_points),
        current_streak_days = CASE
                                  WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                                  ELSE user_analytics.current_streak_days
                              END,
        longest_streak_days = GREATEST(user_analytics.longest_streak_days, EXCLUDED.current_streak_days),
        academic_rank       = CASE
                                  WHEN GREATEST(user_analytics.xp_points, EXCLUDED.xp_points) >= 1000 THEN 'Dean''s List'
                                  WHEN GREATEST(user_analytics.xp_points, EXCLUDED.xp_points) >= 600 THEN 'Diamond Scholar'
                                  WHEN GREATEST(user_analytics.xp_points, EXCLUDED.xp_points) >= 350 THEN 'Gold Scholar'
                                  WHEN GREATEST(user_analytics.xp_points, EXCLUDED.xp_points) >= 150 THEN 'Silver Scholar'
                                  ELSE 'Novice Scholar'
                              END,
        updated_at          = now();

    -- 4. Record daily study activity in heatmap_activity
    INSERT INTO public.heatmap_activity (
        user_id,
        activity_date,
        intensity_level,
        cards_reviewed,
        minutes_studied
    )
    VALUES (
        v_user_id,
        CURRENT_DATE,
        1,
        GREATEST(1, COALESCE(p_xp_delta, 10) / 10),
        1
    )
    ON CONFLICT (user_id, activity_date) DO UPDATE
    SET cards_reviewed = public.heatmap_activity.cards_reviewed + EXCLUDED.cards_reviewed,
        minutes_studied = public.heatmap_activity.minutes_studied + EXCLUDED.minutes_studied,
        intensity_level = LEAST(4, 1 + (public.heatmap_activity.cards_reviewed + EXCLUDED.cards_reviewed) / 10);

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
