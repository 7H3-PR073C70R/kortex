-- Migration: Gamified Study Activity Heatmap, Streak Shield, and Achievement Badges

-- 1. Alter user_analytics and profiles to support streak freezes
ALTER TABLE public.user_analytics
ADD COLUMN IF NOT EXISTS streak_freezes_available INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS streak_freeze_active BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS streak_freezes_available INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS streak_freeze_active BOOLEAN NOT NULL DEFAULT false;

-- 2. Create user_activity_logs for annual 365-day heatmap density
CREATE TABLE IF NOT EXISTS public.user_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reviews_count INT NOT NULL DEFAULT 0,
    xp_earned INT NOT NULL DEFAULT 0,
    time_spent_seconds INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_activity_date UNIQUE (user_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_user_activity_logs_user_date 
ON public.user_activity_logs(user_id, activity_date DESC);

-- 3. Create user_achievements table
CREATE TABLE IF NOT EXISTS public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    badge_key TEXT NOT NULL,
    progress INT NOT NULL DEFAULT 0,
    target INT NOT NULL DEFAULT 100,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    unlocked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_achievement_badge UNIQUE (user_id, badge_key)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user 
ON public.user_achievements(user_id);

-- Enable RLS and Realtime
ALTER TABLE public.user_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION supabase_realtime ADD TABLE public.user_activity_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_achievements;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own activity logs" ON public.user_activity_logs;
DROP POLICY IF EXISTS "Users can insert own activity logs" ON public.user_activity_logs;
DROP POLICY IF EXISTS "Users can update own activity logs" ON public.user_activity_logs;

CREATE POLICY "Users can view own activity logs"
    ON public.user_activity_logs FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity logs"
    ON public.user_activity_logs FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own activity logs"
    ON public.user_activity_logs FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own achievements" ON public.user_achievements;
DROP POLICY IF EXISTS "Users can manage own achievements" ON public.user_achievements;

CREATE POLICY "Users can view own achievements"
    ON public.user_achievements FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own achievements"
    ON public.user_achievements FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RPC: Purchase Streak Freeze using 200 XP
CREATE OR REPLACE FUNCTION public.purchase_streak_freeze(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INT;
    v_cost INT := 200;
BEGIN
    SELECT xp_points INTO v_current_xp
    FROM public.user_analytics
    WHERE user_id = p_user_id;

    IF v_current_xp IS NULL OR v_current_xp < v_cost THEN
        RETURN jsonb_build_object('success', false, 'message', 'Insufficient XP');
    END IF;

    UPDATE public.user_analytics
    SET xp_points = xp_points - v_cost,
        streak_freezes_available = streak_freezes_available + 1,
        streak_freeze_active = true
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'remaining_xp', v_current_xp - v_cost,
        'message', 'Streak Freeze equipped successfully'
    );
END;
$$;
