-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: Fix Promo Code Tier Escalation Trigger
--
-- Problem:
-- When an authenticated user redeems a valid promo code via RPC `redeem_promo_code`,
-- updating `profiles.subscription_tier` trips `trg_protect_subscription_tier`
-- which raises "Unauthorized: subscription_tier can only be mutated by server billing webhooks"
-- because `auth.role()` evaluates to 'authenticated' instead of 'service_role'.
--
-- Solution:
-- 1. Update `protect_subscription_tier_escalation()` trigger function to allow tier mutations
--    if `auth.role() = 'service_role'` OR if a transaction-local bypass flag `app.bypass_tier_protection`
--    is set to 'true'.
-- 2. Update `redeem_promo_code()` to set `app.bypass_tier_protection = 'true'` (is_local = true)
--    during its atomic execution before updating `profiles`.
-- ==============================================================================

-- 1. Update trigger function to support authorized transaction-local bypass
CREATE OR REPLACE FUNCTION public.protect_subscription_tier_escalation()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if subscription_tier is changing
    IF (OLD.subscription_tier IS DISTINCT FROM NEW.subscription_tier) THEN
        -- Allow mutation if:
        -- 1. Caller is service_role (e.g. backend webhooks)
        -- 2. Or caller is an authorized internal database procedure that set the local bypass flag
        IF (auth.role() != 'service_role') AND (current_setting('app.bypass_tier_protection', true) IS DISTINCT FROM 'true') THEN
            RAISE EXCEPTION 'Unauthorized: subscription_tier can only be mutated by server billing webhooks or authorized redemption functions.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Ensure trigger is active
DROP TRIGGER IF EXISTS trg_protect_subscription_tier ON public.profiles;
CREATE TRIGGER trg_protect_subscription_tier
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_subscription_tier_escalation();

-- 2. Update redeem_promo_code to set local bypass flag before updating profiles
CREATE OR REPLACE FUNCTION public.redeem_promo_code(code_input text)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_clean_code TEXT;
    v_promo RECORD;
    v_current_pro_until TIMESTAMPTZ;
    v_base_time TIMESTAMPTZ;
    v_new_pro_until TIMESTAMPTZ;
    v_already_redeemed BOOLEAN;
BEGIN
    -- Ensure caller is authenticated
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'UNAUTHORIZED',
            'message', 'You must be signed in to redeem a promo code.'
        );
    END IF;

    -- Clean code input
    v_clean_code := lower(trim(code_input));
    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'EMPTY_CODE',
            'message', 'Please enter a valid promo code.'
        );
    END IF;

    -- Find matching promo code (locking the row for atomic update)
    SELECT * INTO v_promo
    FROM public.promo_codes
    WHERE lower(trim(code)) = v_clean_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_CODE',
            'message', 'Promo code not found. Please check and try again.'
        );
    END IF;

    -- Check if active
    IF NOT v_promo.is_active THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INACTIVE_CODE',
            'message', 'This promo code is no longer active.'
        );
    END IF;

    -- Check expiration
    IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < now() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'EXPIRED_CODE',
            'message', 'This promo code has expired.'
        );
    END IF;

    -- Check max redemptions
    IF v_promo.max_redemptions IS NOT NULL AND v_promo.redemption_count >= v_promo.max_redemptions THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'MAX_REDEMPTIONS_REACHED',
            'message', 'This promo code has reached its maximum redemptions limit.'
        );
    END IF;

    -- Check if user already redeemed this promo code
    SELECT EXISTS (
        SELECT 1
        FROM public.promo_code_redemptions
        WHERE promo_code_id = v_promo.id AND user_id = v_user_id
    ) INTO v_already_redeemed;

    IF v_already_redeemed THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'ALREADY_REDEEMED',
            'message', 'You have already redeemed this promo code.'
        );
    END IF;

    -- Calculate new Pro expiration timestamp
    SELECT pro_until INTO v_current_pro_until
    FROM public.profiles
    WHERE id = v_user_id;

    v_base_time := GREATEST(COALESCE(v_current_pro_until, now()), now());
    v_new_pro_until := v_base_time + (v_promo.duration_days || ' days')::interval;

    -- 1. Insert redemption record
    INSERT INTO public.promo_code_redemptions (
        promo_code_id,
        user_id,
        duration_days,
        redeemed_at
    ) VALUES (
        v_promo.id,
        v_user_id,
        v_promo.duration_days,
        now()
    );

    -- 2. Increment redemption count on promo_codes
    UPDATE public.promo_codes
    SET
        redemption_count = redemption_count + 1,
        updated_at = now()
    WHERE id = v_promo.id;

    -- Set transaction-local bypass flag so protect_subscription_tier_escalation allows the tier mutation
    PERFORM set_config('app.bypass_tier_protection', 'true', true);

    -- 3. Update profiles table
    UPDATE public.profiles
    SET
        is_pro = true,
        pro_until = v_new_pro_until,
        subscription_tier = 'pro',
        updated_at = now()
    WHERE id = v_user_id;

    -- 4. Update raw_user_meta_data in auth.users for JWT/session reflection
    BEGIN
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
            'is_pro', true,
            'pro_until', v_new_pro_until,
            'subscription_tier', 'pro'
        )
        WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking in case auth.users permission restricts direct update
        RAISE WARNING 'Could not update auth.users metadata: %', SQLERRM;
    END;

    -- Return success payload
    RETURN jsonb_build_object(
        'success', true,
        'code', v_promo.code,
        'duration_days', v_promo.duration_days,
        'pro_until', v_new_pro_until,
        'message', 'Promo code redeemed successfully! ' || v_promo.duration_days || ' days of Kortex Pro activated.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- Re-grant execute permission
GRANT EXECUTE ON FUNCTION public.redeem_promo_code(text) TO authenticated, service_role;
