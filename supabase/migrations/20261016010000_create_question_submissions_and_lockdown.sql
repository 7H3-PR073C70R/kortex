-- ==============================================================================
-- Kortex CBT Readiness & Curriculum Integrity: Question Moderation System
-- Migration: 20261016010000_create_question_submissions_and_lockdown.sql
--
-- 1. Strictly locks down public.past_questions to prevent direct client mutations.
-- 2. Introduces public.question_submissions moderation table with zero-trust RLS.
-- 3. Provides service_role approve_question_submission() RPC to ingest vetted items.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Lock Down public.past_questions (Curriculum Core)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.past_questions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Public can read past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Service role can insert/update past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Anyone can view past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Service role manages past questions" ON public.past_questions;
END $$;

-- Read-only access for students and anonymous clients
CREATE POLICY "Anyone can view past questions"
    ON public.past_questions FOR SELECT
    TO anon, authenticated
    USING (true);

-- Full modification access strictly restricted to internal service_role
CREATE POLICY "Service role manages past questions"
    ON public.past_questions FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Explicitly revoke write privileges from client roles
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.past_questions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.past_questions TO anon, authenticated;
GRANT ALL ON public.past_questions TO service_role;

-- ------------------------------------------------------------------------------
-- 2. Create public.question_submissions Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.question_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL DEFAULT auth.uid(),
    client_question_id TEXT,
    exam_type TEXT NOT NULL,
    subject TEXT NOT NULL,
    year INT NOT NULL,
    question_number INT NOT NULL DEFAULT 1,
    prompt TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_option_index INT NOT NULL,
    correct_option_label TEXT NOT NULL,
    explanation TEXT NOT NULL,
    topic TEXT NOT NULL DEFAULT 'General',
    passage TEXT,
    latex_formula TEXT,
    image_url TEXT,
    difficulty TEXT DEFAULT 'Medium',
    course_id TEXT,
    course_code TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_question_submissions_user_id ON public.question_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_question_submissions_status ON public.question_submissions(status);
CREATE INDEX IF NOT EXISTS idx_question_submissions_lookup ON public.question_submissions(exam_type, subject, year);
CREATE INDEX IF NOT EXISTS idx_question_submissions_created_at ON public.question_submissions(created_at DESC);

ALTER TABLE public.question_submissions ENABLE ROW LEVEL SECURITY;

-- Enforce authenticated user defaults
CREATE OR REPLACE FUNCTION public.fn_set_question_submission_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_question_submission_user ON public.question_submissions;
CREATE TRIGGER trg_set_question_submission_user
    BEFORE INSERT ON public.question_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_set_question_submission_user();

-- Authenticated users can insert their own question submissions
DROP POLICY IF EXISTS "Authenticated users can submit questions for moderation" ON public.question_submissions;
CREATE POLICY "Authenticated users can submit questions for moderation"
    ON public.question_submissions FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

-- Authenticated users can view their own question submissions
DROP POLICY IF EXISTS "Users can view their own question submissions" ON public.question_submissions;
CREATE POLICY "Users can view their own question submissions"
    ON public.question_submissions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Service role manages all submissions
DROP POLICY IF EXISTS "Service role manages all question submissions" ON public.question_submissions;
CREATE POLICY "Service role manages all question submissions"
    ON public.question_submissions FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Permissions: anon has zero access, authenticated can only insert and read their own
REVOKE ALL ON public.question_submissions FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.question_submissions TO authenticated;
GRANT ALL ON public.question_submissions TO service_role;

-- ------------------------------------------------------------------------------
-- 3. Moderation Approval RPC (service_role only)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_question_submission(p_submission_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_sub public.question_submissions%ROWTYPE;
    v_new_id TEXT;
BEGIN
    IF (auth.jwt() ->> 'role') != 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: only service_role can approve question submissions';
    END IF;

    SELECT * INTO v_sub FROM public.question_submissions WHERE id = p_submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Question submission % not found', p_submission_id;
    END IF;

    IF v_sub.status = 'approved' THEN
        RETURN jsonb_build_object('success', true, 'message', 'Already approved');
    END IF;

    v_new_id := COALESCE(v_sub.client_question_id, 'pq_' || replace(gen_random_uuid()::text, '-', ''));

    INSERT INTO public.past_questions (
        id,
        fingerprint,
        exam_type,
        subject,
        year,
        question_number,
        prompt,
        options,
        correct_option_index,
        correct_option_label,
        explanation,
        topic,
        passage,
        latex_formula,
        image_url,
        difficulty,
        metadata
    ) VALUES (
        v_new_id,
        md5(v_sub.exam_type || ':' || v_sub.subject || ':' || v_sub.year || ':' || v_sub.prompt),
        v_sub.exam_type,
        v_sub.subject,
        v_sub.year,
        v_sub.question_number,
        v_sub.prompt,
        v_sub.options,
        v_sub.correct_option_index,
        v_sub.correct_option_label,
        v_sub.explanation,
        v_sub.topic,
        v_sub.passage,
        v_sub.latex_formula,
        v_sub.image_url,
        COALESCE(v_sub.difficulty, 'Medium'),
        jsonb_build_object(
            'contributed_by', v_sub.user_id,
            'submission_id', v_sub.id,
            'course_id', v_sub.course_id,
            'course_code', v_sub.course_code
        )
    )
    ON CONFLICT (fingerprint) DO UPDATE SET
        options = EXCLUDED.options,
        explanation = EXCLUDED.explanation,
        updated_at = now();

    UPDATE public.question_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    RETURN jsonb_build_object('success', true, 'question_id', v_new_id);
END;
$$;

REVOKE ALL ON FUNCTION public.approve_question_submission(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.approve_question_submission(UUID) TO service_role;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
