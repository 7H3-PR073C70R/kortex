-- ============================================================================
-- Migration: 20261012030000_unify_ai_quota_tracking.sql
-- Description: P1-05 Unified AI Generation Quota Guard & Model Protection
--
-- 1. Creates public.user_daily_ai_quotas table for atomic day-scoped tracking.
-- 2. Implements atomic check_and_consume_ai_quota(user_id, feature_type, token_count)
--    with FOR UPDATE row locks to eliminate TOCTOU race conditions.
-- 3. Unifies and synchronizes legacy quota RPCs:
--    - get_syllabot_quota()
--    - record_syllabot_usage()
--    - get_ai_smart_gen_quota()
--    - record_ai_smart_gen_usage()
-- 4. Enforces strict zero-trust permissions and search_path hygiene.
-- ============================================================================

-- 1. Daily AI Quota Counter Table
CREATE TABLE IF NOT EXISTS public.user_daily_ai_quotas (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    quota_date DATE NOT NULL,
    usage_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, action_type, quota_date)
);

CREATE INDEX IF NOT EXISTS idx_user_daily_ai_quotas_lookup
ON public.user_daily_ai_quotas (user_id, action_type, quota_date);

ALTER TABLE public.user_daily_ai_quotas ENABLE ROW LEVEL SECURITY;

-- RLS: Users can only view their own quota counts. Mutations strictly through RPC / service_role.
DROP POLICY IF EXISTS "Users can view own daily ai quotas" ON public.user_daily_ai_quotas;
CREATE POLICY "Users can view own daily ai quotas"
    ON public.user_daily_ai_quotas
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages daily ai quotas" ON public.user_daily_ai_quotas;
CREATE POLICY "Service role manages daily ai quotas"
    ON public.user_daily_ai_quotas
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Revoke direct modifications from public/anon/authenticated
REVOKE INSERT, UPDATE, DELETE ON public.user_daily_ai_quotas FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.user_daily_ai_quotas TO authenticated;
GRANT ALL ON public.user_daily_ai_quotas TO service_role;

-- 2. Atomic Unified Quota Check & Consume Function
CREATE OR REPLACE FUNCTION public.check_and_consume_ai_quota(
    p_user_id UUID,
    p_action_type TEXT,
    p_token_count INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_is_service BOOLEAN := false;
    v_today DATE := (now() AT TIME ZONE 'UTC')::DATE;
    v_tier TEXT := 'free';
    v_is_pro BOOLEAN := false;
    v_pro_until TIMESTAMPTZ;
    v_max_limit INT := 0;
    v_current_usage INT := 0;
    v_is_allowed BOOLEAN := false;
    v_reset_seconds INT;
BEGIN
    -- Determine if caller is service_role
    BEGIN
        v_is_service := (current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role');
    EXCEPTION WHEN OTHERS THEN
        v_is_service := false;
    END;

    -- Security Guard: Caller must be the target user or service_role
    IF NOT v_is_service AND (v_caller IS NULL OR v_caller <> p_user_id) THEN
        RAISE EXCEPTION 'Unauthorized: Caller cannot consume quota for user %', p_user_id;
    END IF;

    -- Lock the user's profile row FOR UPDATE to serialize concurrent quota checks for this user
    SELECT COALESCE(subscription_tier, 'free'), COALESCE(is_pro, false), pro_until
    INTO v_tier, v_is_pro, v_pro_until
    FROM public.profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found for id %', p_user_id;
    END IF;

    -- Authoritative tier resolution
    IF v_is_pro OR v_tier = 'pro' OR (v_pro_until IS NOT NULL AND v_pro_until > now()) THEN
        v_is_pro := true;
        v_tier := 'pro';
    ELSE
        v_is_pro := false;
        v_tier := 'free';
    END IF;

    -- Determine daily limit based on feature and subscription tier
    IF v_is_pro THEN
        CASE p_action_type
            WHEN 'ai_smart_gen' THEN v_max_limit := 30;
            WHEN 'document_ingestion' THEN v_max_limit := 50;
            WHEN 'flashcard_generation' THEN v_max_limit := 100;
            WHEN 'syllabot_query' THEN v_max_limit := 999999; -- Unlimited
            WHEN 'quiz_generation' THEN v_max_limit := 999999; -- Unlimited
            ELSE v_max_limit := 999999;
        END CASE;
    ELSE
        -- Free Tier strict caps
        CASE p_action_type
            WHEN 'syllabot_query' THEN v_max_limit := 20;
            WHEN 'document_ingestion' THEN v_max_limit := 3;
            WHEN 'flashcard_generation' THEN v_max_limit := 10;
            WHEN 'quiz_generation' THEN v_max_limit := 10;
            WHEN 'ai_smart_gen' THEN v_max_limit := 0; -- Gated to Fast Local
            ELSE v_max_limit := 10;
        END CASE;
    END IF;

    -- Ensure daily counter row exists for (user_id, action_type, today)
    INSERT INTO public.user_daily_ai_quotas (user_id, action_type, quota_date, usage_count, updated_at)
    VALUES (p_user_id, p_action_type, v_today, 0, now())
    ON CONFLICT (user_id, action_type, quota_date) DO NOTHING;

    -- Acquire row-level lock on the daily counter
    SELECT usage_count
    INTO v_current_usage
    FROM public.user_daily_ai_quotas
    WHERE user_id = p_user_id
      AND action_type = p_action_type
      AND quota_date = v_today
    FOR UPDATE;

    -- Check if request is within quota
    IF v_current_usage < v_max_limit THEN
        v_is_allowed := true;
        v_current_usage := v_current_usage + 1;

        UPDATE public.user_daily_ai_quotas
        SET usage_count = v_current_usage,
            updated_at = now()
        WHERE user_id = p_user_id
          AND action_type = p_action_type
          AND quota_date = v_today;

        -- Record audit entry in usage_logs
        INSERT INTO public.usage_logs (user_id, action_type, token_count, tier, created_at)
        VALUES (p_user_id, p_action_type, COALESCE(p_token_count, 0), v_tier, now());
    ELSE
        v_is_allowed := false;
    END IF;

    -- Calculate seconds remaining until next UTC midnight reset
    v_reset_seconds := GREATEST(1, EXTRACT(EPOCH FROM ((v_today + INTERVAL '1 day')::TIMESTAMPTZ - now()))::INT);

    RETURN jsonb_build_object(
        'allowed', v_is_allowed,
        'tier', v_tier,
        'is_pro', v_is_pro,
        'action_type', p_action_type,
        'current_usage', v_current_usage,
        'max_limit', CASE WHEN v_max_limit >= 999999 THEN NULL ELSE v_max_limit END,
        'remaining', CASE WHEN v_max_limit >= 999999 THEN NULL ELSE GREATEST(0, v_max_limit - v_current_usage) END,
        'reset_seconds', v_reset_seconds
    );
END;
$$;

-- 3. Backward-Compatible Synchronization of Existing RPCs

-- 3a. get_syllabot_quota()
CREATE OR REPLACE FUNCTION public.get_syllabot_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_today DATE := (now() AT TIME ZONE 'UTC')::DATE;
    v_tier TEXT := 'free';
    v_is_pro BOOLEAN := false;
    v_pro_until TIMESTAMPTZ;
    v_today_count INT := 0;
    v_limit INT := 20;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', 0,
            'limit', v_limit,
            'remaining', v_limit,
            'can_use', false
        );
    END IF;

    SELECT COALESCE(subscription_tier, 'free'), COALESCE(is_pro, false), pro_until
    INTO v_tier, v_is_pro, v_pro_until
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_is_pro OR v_tier = 'pro' OR (v_pro_until IS NOT NULL AND v_pro_until > now()) THEN
        v_is_pro := true;
        v_tier := 'pro';
    END IF;

    -- Read from user_daily_ai_quotas if exists, otherwise fallback to usage_logs
    SELECT COALESCE(
        (SELECT usage_count FROM public.user_daily_ai_quotas 
         WHERE user_id = v_user_id AND action_type = 'syllabot_query' AND quota_date = v_today),
        (SELECT COUNT(*)::INT FROM public.usage_logs 
         WHERE user_id = v_user_id AND action_type = 'syllabot_query' AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC'))
    ) INTO v_today_count;

    IF v_is_pro THEN
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

-- 3b. record_syllabot_usage()
CREATE OR REPLACE FUNCTION public.record_syllabot_usage(p_token_count INT DEFAULT 0)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_res JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User session required';
    END IF;

    v_res := public.check_and_consume_ai_quota(v_user_id, 'syllabot_query', p_token_count);

    IF (v_res->>'allowed')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'Payment Required: Daily Syllabot query limit reached for free tier';
    END IF;

    RETURN v_res;
END;
$$;

-- 3c. get_ai_smart_gen_quota()
CREATE OR REPLACE FUNCTION public.get_ai_smart_gen_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_today DATE := (now() AT TIME ZONE 'UTC')::DATE;
    v_tier TEXT := 'free';
    v_is_pro BOOLEAN := false;
    v_pro_until TIMESTAMPTZ;
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

    SELECT COALESCE(subscription_tier, 'free'), COALESCE(is_pro, false), pro_until
    INTO v_tier, v_is_pro, v_pro_until
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_is_pro OR v_tier = 'pro' OR (v_pro_until IS NOT NULL AND v_pro_until > now()) THEN
        v_is_pro := true;
    ELSE
        v_is_pro := false;
    END IF;

    IF NOT v_is_pro THEN
        RETURN jsonb_build_object(
            'is_pro', false,
            'today_count', 0,
            'limit', 0,
            'remaining', 0,
            'can_use', false
        );
    END IF;

    SELECT COALESCE(
        (SELECT usage_count FROM public.user_daily_ai_quotas 
         WHERE user_id = v_user_id AND action_type = 'ai_smart_gen' AND quota_date = v_today),
        (SELECT COUNT(*)::INT FROM public.usage_logs 
         WHERE user_id = v_user_id AND action_type = 'ai_smart_gen' AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC'))
    ) INTO v_today_count;

    RETURN jsonb_build_object(
        'is_pro', true,
        'today_count', v_today_count,
        'limit', v_limit,
        'remaining', GREATEST(0, v_limit - v_today_count),
        'can_use', (v_today_count < v_limit)
    );
END;
$$;

-- 3d. record_ai_smart_gen_usage()
CREATE OR REPLACE FUNCTION public.record_ai_smart_gen_usage()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_res JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User session required';
    END IF;

    v_res := public.check_and_consume_ai_quota(v_user_id, 'ai_smart_gen', 1);

    IF (v_res->>'allowed')::BOOLEAN IS NOT TRUE THEN
        IF (v_res->>'is_pro')::BOOLEAN IS NOT TRUE THEN
            RAISE EXCEPTION 'Forbidden: AI Smart Gen requires an active Pro subscription';
        ELSE
            RAISE EXCEPTION 'DailyLimitReached: You have reached your daily limit of AI Smart Gen requests';
        END IF;
    END IF;

    RETURN v_res;
END;
$$;

-- 4. Permissions & Hardening
REVOKE EXECUTE ON FUNCTION public.check_and_consume_ai_quota(UUID, TEXT, INT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_and_consume_ai_quota(UUID, TEXT, INT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_syllabot_quota() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_syllabot_quota() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.record_syllabot_usage(INT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_syllabot_usage(INT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_ai_smart_gen_quota() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_ai_smart_gen_quota() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.record_ai_smart_gen_usage() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_ai_smart_gen_usage() TO authenticated, service_role;
