-- Migration: 20261004171500_sync_user_progress_heatmap_activity.sql
-- Description:
--   Syncs daily activity to public.heatmap_activity on every sync_user_progress call
--   so that streak protection checks (check_streak_protection_and_notify and trigger-notifications worker)
--   recognize CBT practice, past questions, and flashcard sessions equally without requiring flashcard decks.

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

    -- 1. Atomically update profiles; the existing trigger fires to leaderboards.
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

    -- 2. Direct upsert for immediate realtime push (belt-and-suspenders).
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

    -- 3. Sync to user_analytics for dashboard consistency.
    INSERT INTO public.user_analytics (user_id, xp_points, current_streak_days)
    VALUES (v_user_id, v_new_xp, GREATEST(0, v_new_streak))
    ON CONFLICT (user_id) DO UPDATE SET
        xp_points           = EXCLUDED.xp_points,
        current_streak_days = CASE
                                  WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                                  ELSE user_analytics.current_streak_days
                              END,
        updated_at          = now();

    -- 4. Record daily study activity in heatmap_activity so that streak protection
    -- checks (e.g. check_streak_protection_and_notify and trigger-notifications worker)
    -- recognize that the student studied today (via CBT practice, past questions, or decks).
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
