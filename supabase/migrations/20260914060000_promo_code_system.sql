
CREATE TABLE IF NOT EXISTS public.promo_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    duration_days INT NOT NULL DEFAULT 365,
    max_redemptions INT DEFAULT NULL,
    redemption_count INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON public.promo_codes (lower(trim(code)));
CREATE INDEX IF NOT EXISTS idx_promo_codes_is_active ON public.promo_codes (is_active);

CREATE TABLE IF NOT EXISTS public.promo_code_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promo_code_id UUID NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    duration_days INT NOT NULL,
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_promo_user UNIQUE (promo_code_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user_id ON public.promo_code_redemptions (user_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_promo_id ON public.promo_code_redemptions (promo_code_id);

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_pro BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS pro_until TIMESTAMPTZ DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free';

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_code_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role has full access to promo codes" ON public.promo_codes;
CREATE POLICY "Service role has full access to promo codes"
    ON public.promo_codes
    FOR ALL
    USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Authenticated users can read active promo codes metadata" ON public.promo_codes;
CREATE POLICY "Authenticated users can read active promo codes metadata"
    ON public.promo_codes
    FOR SELECT
    TO authenticated
    USING (is_active = true);

DROP POLICY IF EXISTS "Users can view own promo redemptions" ON public.promo_code_redemptions;
CREATE POLICY "Users can view own promo redemptions"
    ON public.promo_code_redemptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR auth.role() = 'service_role');

GRANT ALL ON public.promo_codes TO postgres, service_role;
GRANT SELECT ON public.promo_codes TO authenticated;
GRANT ALL ON public.promo_code_redemptions TO postgres, service_role;
GRANT SELECT ON public.promo_code_redemptions TO authenticated;

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
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'UNAUTHORIZED',
            'message', 'You must be signed in to redeem a promo code.'
        );
    END IF;

    v_clean_code := lower(trim(code_input));
    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'EMPTY_CODE',
            'message', 'Please enter a valid promo code.'
        );
    END IF;

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

    IF NOT v_promo.is_active THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INACTIVE_CODE',
            'message', 'This promo code is no longer active.'
        );
    END IF;

    IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < now() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'EXPIRED_CODE',
            'message', 'This promo code has expired.'
        );
    END IF;

    IF v_promo.max_redemptions IS NOT NULL AND v_promo.redemption_count >= v_promo.max_redemptions THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'MAX_REDEMPTIONS_REACHED',
            'message', 'This promo code has reached its maximum redemptions limit.'
        );
    END IF;

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

    SELECT pro_until INTO v_current_pro_until
    FROM public.profiles
    WHERE id = v_user_id;

    v_base_time := GREATEST(COALESCE(v_current_pro_until, now()), now());
    v_new_pro_until := v_base_time + (v_promo.duration_days || ' days')::interval;

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

    UPDATE public.promo_codes
    SET
        redemption_count = redemption_count + 1,
        updated_at = now()
    WHERE id = v_promo.id;

    UPDATE public.profiles
    SET
        is_pro = true,
        pro_until = v_new_pro_until,
        subscription_tier = 'pro',
        updated_at = now()
    WHERE id = v_user_id;

    BEGIN
        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
            'is_pro', true,
            'pro_until', v_new_pro_until,
            'subscription_tier', 'pro'
        )
        WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Could not update auth.users metadata: %', SQLERRM;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'code', v_promo.code,
        'duration_days', v_promo.duration_days,
        'pro_until', v_new_pro_until,
        'message', 'Promo code redeemed successfully! ' || v_promo.duration_days || ' days of Kortex Pro activated.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

GRANT EXECUTE ON FUNCTION public.redeem_promo_code(text) TO authenticated, service_role;

INSERT INTO public.promo_codes (
    code,
    duration_days,
    is_active
) VALUES (
    'ori0n_pr073c7',
    365,
    true
)
ON CONFLICT (code) DO UPDATE SET
    duration_days = 365,
    is_active = true,
    updated_at = now();
