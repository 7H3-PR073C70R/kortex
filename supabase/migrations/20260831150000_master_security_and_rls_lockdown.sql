-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 019 - Master Total Zero-Trust Security & RLS Lockdown
-- ==============================================================================

-- 1. Enforce search_path = public, pg_temp on all sensitive database functions
-- to prevent search_path schema-hijacking privilege escalation.

ALTER FUNCTION public.process_card_sm2_review(UUID, INT) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.upsert_fsrs_review_batch(JSONB) 
    SET search_path = public, pg_temp;

-- 2. Revoke execution from 'anon' and 'public' on all operational & financial RPCs
REVOKE EXECUTE ON FUNCTION public.process_card_sm2_review(UUID, INT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.process_card_sm2_review(UUID, INT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.upsert_fsrs_review_batch(JSONB) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.upsert_fsrs_review_batch(JSONB) TO authenticated, service_role;

-- 3. Lock down Usage Logs table (Internal Audit Trail)
CREATE TABLE IF NOT EXISTS public.usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    token_count INT NOT NULL DEFAULT 0,
    tier TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.usage_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own usage logs" ON public.usage_logs;
CREATE POLICY "Users can view own usage logs"
    ON public.usage_logs
    FOR SELECT
    USING (auth.uid() = user_id);

-- Explicitly ban client inserts on usage_logs; only service_role (Edge Functions) can record usage
DROP POLICY IF EXISTS "Service role inserts usage logs" ON public.usage_logs;
CREATE POLICY "Service role inserts usage logs"
    ON public.usage_logs
    FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

-- 4. Lock down Profile Subscription Tier (Client cannot escalate own tier)
-- Profiles table update policy ensures subscription_tier cannot be updated by normal user JWT
CREATE OR REPLACE FUNCTION public.protect_subscription_tier_escalation()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.subscription_tier IS DISTINCT FROM NEW.subscription_tier) AND (auth.role() != 'service_role') THEN
        RAISE EXCEPTION 'Unauthorized: subscription_tier can only be mutated by server billing webhooks.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_protect_subscription_tier ON public.profiles;
CREATE TRIGGER trg_protect_subscription_tier
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_subscription_tier_escalation();

-- 5. Comprehensive RLS check across all operational tables
ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_review_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_results ENABLE ROW LEVEL SECURITY;

-- 6. Grant appropriate table permissions strictly
GRANT SELECT, INSERT, UPDATE, DELETE ON public.decks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.flashcards TO authenticated;
GRANT SELECT, INSERT ON public.study_review_logs TO authenticated;
GRANT SELECT, INSERT ON public.session_results TO authenticated;
GRANT SELECT ON public.usage_logs TO authenticated;

REVOKE ALL ON public.usage_logs FROM anon;
REVOKE ALL ON public.study_review_logs FROM anon;
REVOKE ALL ON public.flashcards FROM anon;
REVOKE ALL ON public.decks FROM anon;
