-- Migration: 20260929000000_enhance_xp_gamification_system.sql
-- Description: Universal XP & Gamification Enhancement System (Audit Log, RPC, Realtime Multipliers)

-- 1. Create XP Transactions Audit Table
CREATE TABLE IF NOT EXISTS public.user_xp_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount INT NOT NULL,
    category TEXT NOT NULL,
    source_id TEXT,
    multiplier NUMERIC(3,2) NOT NULL DEFAULT 1.00,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast user transaction timeline lookups
CREATE INDEX IF NOT EXISTS idx_user_xp_transactions_user_date 
ON public.user_xp_transactions(user_id, created_at DESC);

-- Enable RLS
ALTER TABLE public.user_xp_transactions ENABLE ROW LEVEL SECURITY;

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_xp_transactions;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own xp transactions" ON public.user_xp_transactions;
CREATE POLICY "Users can view own xp transactions"
    ON public.user_xp_transactions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. Create Atomic RPC to Award User XP with Streak Multiplier & Transaction Logging
CREATE OR REPLACE FUNCTION public.award_user_xp(
    p_user_id UUID,
    p_amount INT,
    p_category TEXT,
    p_source_id TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_streak INT := 0;
    v_multiplier NUMERIC(3,2) := 1.00;
    v_final_xp INT := 0;
    v_new_total_xp INT := 0;
BEGIN
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'XP amount must be positive');
    END IF;

    -- Fetch current streak for multiplier calculation
    SELECT COALESCE(current_streak_days, 0)
    INTO v_streak
    FROM public.user_analytics
    WHERE user_id = p_user_id;

    -- Calculate streak multiplier
    IF v_streak >= 30 THEN
        v_multiplier := 2.00;
    ELSIF v_streak >= 14 THEN
        v_multiplier := 1.75;
    ELSIF v_streak >= 7 THEN
        v_multiplier := 1.50;
    ELSIF v_streak >= 4 THEN
        v_multiplier := 1.25;
    ELSE
        v_multiplier := 1.00;
    END IF;

    v_final_xp := ROUND(p_amount * v_multiplier);

    -- 1. Insert XP transaction log
    INSERT INTO public.user_xp_transactions (
        user_id,
        amount,
        category,
        source_id,
        multiplier,
        metadata
    ) VALUES (
        p_user_id,
        v_final_xp,
        p_category,
        p_source_id,
        v_multiplier,
        p_metadata
    );

    -- 2. Update user analytics xp_points atomically
    INSERT INTO public.user_analytics (user_id, xp_points)
    VALUES (p_user_id, v_final_xp)
    ON CONFLICT (user_id) DO UPDATE
    SET xp_points = COALESCE(user_analytics.xp_points, 0) + v_final_xp,
        updated_at = now()
    RETURNING xp_points INTO v_new_total_xp;

    -- 3. Sync to user profile table
    UPDATE public.profiles
    SET xp_points = v_new_total_xp
    WHERE id = p_user_id;

    -- 4. Log or update daily user activity log
    INSERT INTO public.user_activity_logs (user_id, activity_date, xp_earned)
    VALUES (p_user_id, CURRENT_DATE, v_final_xp)
    ON CONFLICT (user_id, activity_date) DO UPDATE
    SET xp_earned = user_activity_logs.xp_earned + v_final_xp;

    RETURN jsonb_build_object(
        'success', true,
        'xp_awarded', v_final_xp,
        'base_amount', p_amount,
        'multiplier', v_multiplier,
        'new_total_xp', v_new_total_xp,
        'streak_days', v_streak,
        'category', p_category
    );
END;
$$;
