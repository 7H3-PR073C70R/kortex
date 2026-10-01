-- ============================================================================
-- Migration: 20261001080000_sync_user_streak_to_leaderboards.sql
-- Description: Synchronize user streak days and XP to leaderboards table and
--              backfill any zero-streak rows where study activity/XP is present.
-- ============================================================================

-- 1. Create a trigger function to keep leaderboards.streak_days in lockstep with profiles.streak_days
CREATE OR REPLACE FUNCTION public.sync_profile_to_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.leaderboards
    SET 
        streak_days = GREATEST(1, NEW.streak_days),
        user_name = COALESCE(NULLIF(NEW.display_name, ''), leaderboards.user_name),
        avatar_url = COALESCE(NEW.photo_url, leaderboards.avatar_url),
        track = COALESCE(NULLIF(NEW.target_track, ''), leaderboards.track),
        updated_at = now()
    WHERE user_id = NEW.id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_profile_to_leaderboard ON public.profiles;
CREATE TRIGGER trg_sync_profile_to_leaderboard
AFTER UPDATE OF streak_days, display_name, photo_url, target_track ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_to_leaderboard();

-- 2. Trigger from user_analytics to sync current_streak_days to leaderboards
CREATE OR REPLACE FUNCTION public.sync_analytics_streak_to_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.leaderboards
    SET 
        streak_days = GREATEST(1, NEW.current_streak_days),
        updated_at = now()
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_analytics_streak_to_leaderboard ON public.user_analytics;
CREATE TRIGGER trg_sync_analytics_streak_to_leaderboard
AFTER UPDATE OF current_streak_days ON public.user_analytics
FOR EACH ROW EXECUTE FUNCTION public.sync_analytics_streak_to_leaderboard();

-- 3. Backfill existing leaderboards records where streak_days is 0 or unpopulated
UPDATE public.leaderboards l
SET streak_days = GREATEST(
    1,
    COALESCE((SELECT p.streak_days FROM public.profiles p WHERE p.id = l.user_id), 0),
    COALESCE((SELECT ua.current_streak_days FROM public.user_analytics ua WHERE ua.user_id = l.user_id), 0),
    CASE 
        WHEN l.weekly_xp > 500 THEN 7
        WHEN l.weekly_xp > 200 THEN 4
        WHEN l.weekly_xp > 50 THEN 2
        WHEN l.weekly_xp > 0 THEN 1
        ELSE 1
    END
),
updated_at = now()
WHERE l.streak_days <= 0 OR l.streak_days IS NULL;
