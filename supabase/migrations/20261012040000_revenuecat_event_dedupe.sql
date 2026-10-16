-- ============================================================================
-- Migration: 20261012040000_revenuecat_event_dedupe.sql
-- Description: P2-01 Production-Hardened RevenueCat Webhook Storage & Deduplication
--
-- 1. Adds last_billing_event_at column to profiles for ordering guarantees.
-- 2. Creates public.revenuecat_processed_events table for webhook idempotency.
-- 3. Implements atomic process_revenuecat_billing_event function with:
--    - Event deduplication (replay protection)
--    - Row-level locking (FOR UPDATE)
--    - Monotonic event ordering (rejects stale/out-of-order events)
-- ============================================================================

-- 1. Track last processed billing event on profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_billing_event_at TIMESTAMPTZ;

-- 2. Processed events table for idempotency
CREATE TABLE IF NOT EXISTS public.revenuecat_processed_events (
    event_id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    environment TEXT DEFAULT 'PRODUCTION',
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rc_processed_events_user
ON public.revenuecat_processed_events (user_id, processed_at DESC);

ALTER TABLE public.revenuecat_processed_events ENABLE ROW LEVEL SECURITY;

-- Only service_role can access processed events
DROP POLICY IF EXISTS "Service role manages revenuecat processed events" ON public.revenuecat_processed_events;
CREATE POLICY "Service role manages revenuecat processed events"
    ON public.revenuecat_processed_events
    FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

REVOKE ALL ON public.revenuecat_processed_events FROM anon, authenticated, PUBLIC;
GRANT ALL ON public.revenuecat_processed_events TO service_role;

-- 3. Atomic Stored Procedure: process_revenuecat_billing_event
CREATE OR REPLACE FUNCTION public.process_revenuecat_billing_event(
    p_event_id TEXT,
    p_user_id UUID,
    p_event_type TEXT,
    p_event_timestamp TIMESTAMPTZ,
    p_target_tier TEXT,
    p_is_pro BOOLEAN,
    p_pro_until TIMESTAMPTZ,
    p_environment TEXT DEFAULT 'PRODUCTION'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN := false;
    v_last_event_at TIMESTAMPTZ;
BEGIN
    -- Verify caller is service_role
    BEGIN
        v_is_service := (current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role');
    EXCEPTION WHEN OTHERS THEN
        v_is_service := false;
    END;

    IF NOT v_is_service THEN
        RAISE EXCEPTION 'Unauthorized: Only service_role can process billing events';
    END IF;

    -- 1. Idempotency Check: Discard duplicate events
    IF EXISTS (
        SELECT 1 FROM public.revenuecat_processed_events
        WHERE event_id = p_event_id
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'duplicate_ignored',
            'event_id', p_event_id
        );
    END IF;

    -- 2. Acquire profile row lock FOR UPDATE
    SELECT last_billing_event_at
    INTO v_last_event_at
    FROM public.profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        -- Record event to prevent retry storms if user is deleted
        INSERT INTO public.revenuecat_processed_events (
            event_id, user_id, event_type, event_timestamp, environment
        )
        VALUES (
            p_event_id, p_user_id, p_event_type, p_event_timestamp, p_environment
        )
        ON CONFLICT (event_id) DO NOTHING;

        RETURN jsonb_build_object(
            'success', false,
            'status', 'user_not_found',
            'event_id', p_event_id
        );
    END IF;

    -- 3. Monotonic Event Ordering: Discard stale or out-of-order events
    IF v_last_event_at IS NOT NULL AND p_event_timestamp <= v_last_event_at THEN
        INSERT INTO public.revenuecat_processed_events (
            event_id, user_id, event_type, event_timestamp, environment
        )
        VALUES (
            p_event_id, p_user_id, p_event_type, p_event_timestamp, p_environment
        )
        ON CONFLICT (event_id) DO NOTHING;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'out_of_order_discarded',
            'event_id', p_event_id,
            'last_event_at', v_last_event_at,
            'event_timestamp', p_event_timestamp
        );
    END IF;

    -- 4. Apply subscription update
    UPDATE public.profiles
    SET subscription_tier = p_target_tier,
        is_pro = p_is_pro,
        pro_until = p_pro_until,
        last_billing_event_at = p_event_timestamp,
        updated_at = now()
    WHERE id = p_user_id;

    -- 5. Mark event as processed
    INSERT INTO public.revenuecat_processed_events (
        event_id, user_id, event_type, event_timestamp, environment
    )
    VALUES (
        p_event_id, p_user_id, p_event_type, p_event_timestamp, p_environment
    )
    ON CONFLICT (event_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'applied',
        'event_id', p_event_id,
        'tier', p_target_tier,
        'is_pro', p_is_pro,
        'pro_until', p_pro_until
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_revenuecat_billing_event FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.process_revenuecat_billing_event TO service_role;
