-- Migration: 20261010050000_ai_smart_gen_daily_quota.sql
-- Enforces server-side database tracking and daily quota for AI Smart Gen synthesis.
-- Pro users have a daily cap (30/day), Free users are gated (0/day).
-- Fast Local synthesis remains completely unlimited with zero cap.

CREATE TABLE IF NOT EXISTS public.usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    token_count INT NOT NULL DEFAULT 0,
    tier TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_usage_logs_user_action_created 
ON public.usage_logs (user_id, action_type, created_at DESC);

-- RPC: Get authoritative AI Smart Gen quota for current authenticated user
CREATE OR REPLACE FUNCTION public.get_ai_smart_gen_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_tier TEXT := 'free';
    v_today_count INT := 0;
    v_limit INT := 30;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', 0,
            'limit', 0,
            'remaining', 0,
            'can_use', false
        );
    END IF;

    -- Fetch user subscription tier from profiles table
    SELECT COALESCE(subscription_tier, 'free') INTO v_tier
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_tier IS DISTINCT FROM 'pro' THEN
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', 0,
            'limit', 0,
            'remaining', 0,
            'can_use', false
        );
    END IF;

    -- Count usage today (UTC day boundary)
    SELECT COUNT(*)::INT INTO v_today_count
    FROM public.usage_logs
    WHERE user_id = v_user_id
      AND action_type = 'ai_smart_gen'
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');

    RETURN jsonb_build_object(
        'is_pro', true,
        'today_count', v_today_count,
        'limit', v_limit,
        'remaining', GREATEST(0, v_limit - v_today_count),
        'can_use', (v_today_count < v_limit)
    );
END;
$$;

-- RPC: Authoritatively record AI Smart Gen usage in Postgres
CREATE OR REPLACE FUNCTION public.record_ai_smart_gen_usage()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_tier TEXT := 'free';
    v_today_count INT := 0;
    v_limit INT := 30;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User session required';
    END IF;

    SELECT COALESCE(subscription_tier, 'free') INTO v_tier
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_tier IS DISTINCT FROM 'pro' THEN
        RAISE EXCEPTION 'Forbidden: AI Smart Gen requires an active Pro subscription';
    END IF;

    SELECT COUNT(*)::INT INTO v_today_count
    FROM public.usage_logs
    WHERE user_id = v_user_id
      AND action_type = 'ai_smart_gen'
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');

    IF v_today_count >= v_limit THEN
        RAISE EXCEPTION 'DailyLimitReached: You have reached your daily limit of % AI Smart Gen requests. Please use uncapped Fast Local synthesis.', v_limit;
    END IF;

    INSERT INTO public.usage_logs (user_id, action_type, token_count, tier, created_at)
    VALUES (v_user_id, 'ai_smart_gen', 1, 'pro', now());

    RETURN jsonb_build_object(
        'success', true,
        'today_count', v_today_count + 1,
        'limit', v_limit,
        'remaining', GREATEST(0, v_limit - (v_today_count + 1))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ai_smart_gen_quota() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_ai_smart_gen_usage() TO authenticated, service_role;
