-- ============================================================================
-- Migration: 20261004173500_reconcile_heatmap_and_user_analytics.sql
-- Description:
--   1. Backfill all missing heatmap_activity rows from actual study_review_logs.
--   2. Synchronize profiles XP and streak with the highest values from leaderboards.
--   3. Synchronize user_analytics XP, streak, and academic ranks to match profiles.
-- ============================================================================

-- 1. Backfill all missing heatmap_activity rows from actual study_review_logs
INSERT INTO public.heatmap_activity (
    user_id,
    activity_date,
    intensity_level,
    cards_reviewed,
    minutes_studied
)
SELECT
    user_id,
    date(reviewed_at_utc) AS activity_date,
    LEAST(4, GREATEST(1, count(*) / 15)) AS intensity_level,
    count(*) AS cards_reviewed,
    GREATEST(1, count(*) / 3) AS minutes_studied
FROM public.study_review_logs
GROUP BY user_id, date(reviewed_at_utc)
ON CONFLICT (user_id, activity_date) DO UPDATE SET
    cards_reviewed = GREATEST(heatmap_activity.cards_reviewed, EXCLUDED.cards_reviewed),
    minutes_studied = GREATEST(heatmap_activity.minutes_studied, EXCLUDED.minutes_studied),
    intensity_level = LEAST(4, GREATEST(heatmap_activity.intensity_level, EXCLUDED.intensity_level));

-- 2. Synchronize profiles XP and streak with the highest values from leaderboards
UPDATE public.profiles p
SET
    xp_points   = GREATEST(COALESCE(p.xp_points, 0), COALESCE(l.weekly_xp, 0)),
    streak_days = GREATEST(COALESCE(p.streak_days, 0), COALESCE(l.streak_days, 0)),
    updated_at  = now()
FROM public.leaderboards l
WHERE p.id = l.user_id;

-- 3. Synchronize user_analytics XP, streak, and academic ranks
UPDATE public.user_analytics ua
SET
    xp_points           = p.xp_points,
    current_streak_days = p.streak_days,
    longest_streak_days = GREATEST(ua.longest_streak_days, p.streak_days),
    academic_rank       = CASE
                              WHEN p.xp_points >= 1000 THEN 'Dean''s List'
                              WHEN p.xp_points >= 600 THEN 'Diamond Scholar'
                              WHEN p.xp_points >= 350 THEN 'Gold Scholar'
                              WHEN p.xp_points >= 150 THEN 'Silver Scholar'
                              ELSE 'Novice Scholar'
                          END,
    updated_at          = now()
FROM public.profiles p
WHERE ua.user_id = p.id;
