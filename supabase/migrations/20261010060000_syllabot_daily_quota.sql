-- Migration: 20261010060000_syllabot_daily_quota.sql
-- Enforces server-side database tracking and daily quota for Syllabot AI queries for Free and Pro users.
-- Free users have a 20 queries/day limit.
-- Pro users have unlimited queries, but their usage and count are strictly tracked and counted on the server side.
-- Quota and counts are stored in public.usage_logs and queried authoritatively via RPC.

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

-- RPC: Get authoritative Syllabot query quota & count for current authenticated user
CREATE OR REPLACE FUNCTION public.get_syllabot_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_tier TEXT := 'free';
    v_today_count INT := 0;
    v_limit INT := 20; -- Free users get 20 daily Syllabot queries (MON-04)
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', 0,
            'limit', v_limit,
            'remaining', v_limit,
            'can_use', true
        );
    END IF;

    -- Fetch user subscription tier from profiles table
    SELECT COALESCE(subscription_tier, 'free') INTO v_tier
    FROM public.profiles
    WHERE id = v_user_id;

    -- Count usage today (UTC day boundary) for user
    SELECT COUNT(*)::INT INTO v_today_count
    FROM public.usage_logs
    WHERE user_id = v_user_id
      AND action_type = 'syllabot_query'
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');

    IF v_tier = 'pro' THEN
        RETURN jsonb_build_object(
            'is_pro', true,
            'today_count', v_today_count,
            'limit', null,
            'remaining', null,
            'can_use', true
        );
    ELSE
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', v_today_count,
            'limit', v_limit,
            'remaining', GREATEST(0, v_limit - v_today_count),
            'can_use', (v_today_count < v_limit)
        );
    END IF;
END;
$$;

-- RPC: Authoritatively record Syllabot query usage in Postgres
CREATE OR REPLACE FUNCTION public.record_syllabot_usage(p_token_count INT DEFAULT 0)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_tier TEXT := 'free';
    v_today_count INT := 0;
    v_limit INT := 20;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User session required';
    END IF;

    SELECT COALESCE(subscription_tier, 'free') INTO v_tier
    FROM public.profiles
    WHERE id = v_user_id;

    SELECT COUNT(*)::INT INTO v_today_count
    FROM public.usage_logs
    WHERE user_id = v_user_id
      AND action_type = 'syllabot_query'
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');

    IF v_tier IS DISTINCT FROM 'pro' AND v_today_count >= v_limit THEN
        RAISE EXCEPTION 'Payment Required: Daily Syllabot query limit of % reached for free tier', v_limit;
    END IF;

    INSERT INTO public.usage_logs (user_id, action_type, token_count, tier, created_at)
    VALUES (v_user_id, 'syllabot_query', COALESCE(p_token_count, 0), v_tier, now());

    v_today_count := v_today_count + 1;

    IF v_tier = 'pro' THEN
        RETURN jsonb_build_object(
            'is_pro', true,
            'today_count', v_today_count,
            'limit', null,
            'remaining', null,
            'can_use', true
        );
    ELSE
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', v_today_count,
            'limit', v_limit,
            'remaining', GREATEST(0, v_limit - v_today_count),
            'can_use', (v_today_count < v_limit)
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_syllabot_quota() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.record_syllabot_usage(INT) TO authenticated;
