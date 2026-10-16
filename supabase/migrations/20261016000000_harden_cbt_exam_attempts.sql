-- ==============================================================================
-- Kortex CBT Readiness Audit: Server-Side Graded Exam Attempts & RPC Security Hardening
-- Migration: 20261016000000_harden_cbt_exam_attempts.sql
--
-- 1. Create public.cbt_exam_sessions table for server-side attempt tracking and lifecycle management.
-- 2. Add CHECK constraints to public.quizzes (score_percent 0-100, correct_answers <= total, duration >= 0).
-- 3. Upgrade public.start_mock_exam RPC:
--    - Enforce auth.uid() caller check (revoke execute from anon and PUBLIC).
--    - Set search_path = public, pg_temp.
--    - Insert tracking record into cbt_exam_sessions with started_at, duration_minutes, and expires_at.
-- 4. Create public.submit_cbt_mock_attempt RPC:
--    - Enforce auth.uid() caller check (revoke execute from anon and PUBLIC).
--    - Verify server time has not exceeded expires_at + grace_period before accepting scores.
--    - Validate input integrity (correct_answers <= total_questions, duration_seconds >= 0).
--    - Recalculate score_percent server-side.
--    - Upsert into public.quizzes and mark cbt_exam_sessions as 'completed' idempotently.
-- ==============================================================================

-- Ensure prerequisites on public.quizzes exist
ALTER TABLE IF EXISTS public.quizzes
    ADD COLUMN IF NOT EXISTS subject TEXT,
    ADD COLUMN IF NOT EXISTS course_id TEXT,
    ADD COLUMN IF NOT EXISTS course_code TEXT;

-- ------------------------------------------------------------------------------
-- 1. Create public.cbt_exam_sessions Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cbt_exam_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exam_id TEXT NOT NULL,
    subject TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    duration_minutes INT NOT NULL DEFAULT 60,
    expires_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'expired', 'abandoned')),
    score_percent INT CHECK (score_percent IS NULL OR (score_percent >= 0 AND score_percent <= 100)),
    total_questions INT CHECK (total_questions IS NULL OR total_questions >= 0),
    correct_answers INT CHECK (correct_answers IS NULL OR (correct_answers >= 0 AND correct_answers <= total_questions)),
    metadata JSONB DEFAULT '{}'::jsonb,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cbt_exam_sessions_user_id ON public.cbt_exam_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_cbt_exam_sessions_status ON public.cbt_exam_sessions(status);
CREATE INDEX IF NOT EXISTS idx_cbt_exam_sessions_lookup ON public.cbt_exam_sessions(user_id, exam_id, subject);
CREATE INDEX IF NOT EXISTS idx_cbt_exam_sessions_expires_at ON public.cbt_exam_sessions(expires_at);

ALTER TABLE public.cbt_exam_sessions ENABLE ROW LEVEL SECURITY;

-- RLS: Users can view their own sessions
DROP POLICY IF EXISTS "Users can view own CBT exam sessions" ON public.cbt_exam_sessions;
CREATE POLICY "Users can view own CBT exam sessions"
    ON public.cbt_exam_sessions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- RLS: Service role has full management access
DROP POLICY IF EXISTS "Service role manages CBT exam sessions" ON public.cbt_exam_sessions;
CREATE POLICY "Service role manages CBT exam sessions"
    ON public.cbt_exam_sessions FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Revoke direct mutation privileges from clients (mutations must go through secure RPCs)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.cbt_exam_sessions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.cbt_exam_sessions TO authenticated;
GRANT ALL ON public.cbt_exam_sessions TO service_role;

-- ------------------------------------------------------------------------------
-- 2. Add CHECK Constraints to public.quizzes
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    -- Clamp existing outlier rows if any exist in the database prior to applying constraints
    UPDATE public.quizzes
    SET score_percent = LEAST(GREATEST(score_percent, 0), 100)
    WHERE score_percent < 0 OR score_percent > 100;

    UPDATE public.quizzes
    SET total_questions = 0
    WHERE total_questions < 0;

    UPDATE public.quizzes
    SET correct_answers = LEAST(GREATEST(correct_answers, 0), total_questions)
    WHERE correct_answers < 0 OR correct_answers > total_questions;

    UPDATE public.quizzes
    SET duration_seconds = 0
    WHERE duration_seconds < 0;

    -- Apply CHECK constraints safely
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quizzes_score_percent'
    ) THEN
        ALTER TABLE public.quizzes
            ADD CONSTRAINT chk_quizzes_score_percent
            CHECK (score_percent >= 0 AND score_percent <= 100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quizzes_correct_answers'
    ) THEN
        ALTER TABLE public.quizzes
            ADD CONSTRAINT chk_quizzes_correct_answers
            CHECK (correct_answers >= 0 AND correct_answers <= total_questions);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quizzes_total_questions'
    ) THEN
        ALTER TABLE public.quizzes
            ADD CONSTRAINT chk_quizzes_total_questions
            CHECK (total_questions >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_quizzes_duration_seconds'
    ) THEN
        ALTER TABLE public.quizzes
            ADD CONSTRAINT chk_quizzes_duration_seconds
            CHECK (duration_seconds >= 0);
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. Upgrade public.start_mock_exam RPC
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.start_mock_exam(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_mock_exam(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_mock_exam(TEXT, TEXT, TEXT, TEXT, INT, INT, UUID, UUID);
DROP FUNCTION IF EXISTS public.start_mock_exam();

CREATE OR REPLACE FUNCTION public.start_mock_exam(
    p_exam_id TEXT DEFAULT '',
    p_subject TEXT DEFAULT '',
    "examId" TEXT DEFAULT NULL,
    "subject" TEXT DEFAULT NULL,
    p_duration_minutes INT DEFAULT NULL,
    "durationMinutes" INT DEFAULT NULL,
    p_session_id UUID DEFAULT NULL,
    "sessionId" UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN := public.is_service_role_caller();
    v_caller_id UUID := auth.uid();
    v_session_id UUID;
    v_actual_exam_id TEXT;
    v_actual_subject TEXT;
    v_duration INT;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- 1. Enforce Authenticated Caller Check (Explicitly Revoking Anon Execution)
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Caller must be authenticated to start a mock exam';
        END IF;
    ELSE
        v_caller_id := COALESCE(v_caller_id, '00000000-0000-0000-0000-000000000000'::uuid);
    END IF;

    -- 2. Resolve Parameters
    v_actual_exam_id := COALESCE(NULLIF("examId", ''), NULLIF(p_exam_id, ''), 'general_cbt');
    v_actual_subject := COALESCE(NULLIF("subject", ''), NULLIF(p_subject, ''), 'General');
    v_session_id := COALESCE("sessionId", p_session_id, gen_random_uuid());
    
    -- Default duration: 60 mins, bounded between 5 and 300 mins
    v_duration := COALESCE("durationMinutes", p_duration_minutes, 60);
    IF v_duration < 5 THEN
        v_duration := 5;
    ELSIF v_duration > 300 THEN
        v_duration := 300;
    END IF;

    v_expires_at := now() + (v_duration || ' minutes')::interval;

    -- 3. Insert or Update Session Record
    INSERT INTO public.cbt_exam_sessions (
        id,
        user_id,
        exam_id,
        subject,
        started_at,
        duration_minutes,
        expires_at,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_session_id,
        v_caller_id,
        v_actual_exam_id,
        v_actual_subject,
        now(),
        v_duration,
        v_expires_at,
        'in_progress',
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        exam_id = EXCLUDED.exam_id,
        subject = EXCLUDED.subject,
        duration_minutes = EXCLUDED.duration_minutes,
        expires_at = EXCLUDED.expires_at,
        status = 'in_progress',
        updated_at = now();

    -- 4. Return Session Payload
    RETURN jsonb_build_object(
        'sessionId', v_session_id::text,
        'examId', v_actual_exam_id,
        'subject', v_actual_subject,
        'durationMinutes', v_duration,
        'startedAt', now(),
        'expiresAt', v_expires_at,
        'status', 'in_progress'
    );
END;
$$;

-- Revoke execute from PUBLIC and anon!
REVOKE ALL ON FUNCTION public.start_mock_exam(TEXT, TEXT, TEXT, TEXT, INT, INT, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_mock_exam(TEXT, TEXT, TEXT, TEXT, INT, INT, UUID, UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. Create public.submit_cbt_mock_attempt RPC
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_cbt_mock_attempt(UUID, TEXT, TEXT, INT, INT, INT, TEXT[], TEXT, TEXT, UUID, JSONB);

CREATE OR REPLACE FUNCTION public.submit_cbt_mock_attempt(
    p_session_id UUID,
    p_quiz_title TEXT,
    p_subject TEXT DEFAULT '',
    p_total_questions INT DEFAULT 0,
    p_correct_answers INT DEFAULT 0,
    p_duration_seconds INT DEFAULT 0,
    p_weak_subtopics TEXT[] DEFAULT '{}',
    p_course_id TEXT DEFAULT NULL,
    p_course_code TEXT DEFAULT NULL,
    p_deck_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN := public.is_service_role_caller();
    v_caller_id UUID := auth.uid();
    v_session public.cbt_exam_sessions%ROWTYPE;
    v_score_percent INT := 0;
    v_grace_period INTERVAL := interval '5 minutes';
    v_final_subject TEXT;
BEGIN
    -- 1. Authorization Guard
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Caller must be authenticated to submit exam attempt';
        END IF;
    ELSE
        v_caller_id := COALESCE(v_caller_id, '00000000-0000-0000-0000-000000000000'::uuid);
    END IF;

    -- 2. Input Sanity Checks
    IF p_total_questions < 0 THEN
        RAISE EXCEPTION 'P0002: Invalid Argument: total_questions must be non-negative';
    END IF;

    IF p_correct_answers < 0 OR p_correct_answers > p_total_questions THEN
        RAISE EXCEPTION 'P0002: Invalid Argument: correct_answers must be between 0 and total_questions';
    END IF;

    IF p_duration_seconds < 0 THEN
        RAISE EXCEPTION 'P0002: Invalid Argument: duration_seconds must be non-negative';
    END IF;

    -- 3. Calculate Score Percent Server-Side
    IF p_total_questions > 0 THEN
        v_score_percent := ROUND((p_correct_answers::numeric / p_total_questions::numeric) * 100)::int;
    ELSE
        v_score_percent := 0;
    END IF;
    v_score_percent := LEAST(GREATEST(v_score_percent, 0), 100);

    -- 4. Session Validation (if active server session exists)
    SELECT * INTO v_session
    FROM public.cbt_exam_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF FOUND THEN
        -- Verify Ownership
        IF NOT v_is_service AND v_session.user_id <> v_caller_id THEN
            RAISE EXCEPTION 'P0001: Permission Denied: You do not own this exam attempt session';
        END IF;

        -- Idempotent Re-Submission Return
        IF v_session.status = 'completed' THEN
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Exam attempt was already submitted',
                'quiz_id', p_session_id::text,
                'score_percent', v_session.score_percent,
                'status', 'completed'
            );
        END IF;

        -- Enforce Deadline Validation with Grace Period
        IF now() > (v_session.expires_at + v_grace_period) THEN
            UPDATE public.cbt_exam_sessions
            SET status = 'expired',
                updated_at = now()
            WHERE id = p_session_id;

            RAISE EXCEPTION 'P0003: Exam Expired: Submission rejected because the exam deadline expired at % (grace period exceeded)',
                (v_session.expires_at + v_grace_period);
        END IF;
    END IF;

    v_final_subject := COALESCE(NULLIF(p_subject, ''), v_session.subject, p_quiz_title);

    -- 5. Insert / Upsert into public.quizzes with Idempotency
    INSERT INTO public.quizzes (
        id,
        user_id,
        title,
        subject,
        course_id,
        course_code,
        deck_id,
        total_questions,
        correct_answers,
        score_percent,
        duration_seconds,
        weak_subtopics,
        completed_at,
        created_at
    ) VALUES (
        p_session_id,
        COALESCE(v_session.user_id, v_caller_id),
        p_quiz_title,
        v_final_subject,
        p_course_id,
        p_course_code,
        p_deck_id,
        p_total_questions,
        p_correct_answers,
        v_score_percent,
        p_duration_seconds,
        COALESCE(p_weak_subtopics, '{}'),
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        score_percent = EXCLUDED.score_percent,
        correct_answers = EXCLUDED.correct_answers,
        total_questions = EXCLUDED.total_questions,
        duration_seconds = EXCLUDED.duration_seconds,
        weak_subtopics = EXCLUDED.weak_subtopics,
        completed_at = EXCLUDED.completed_at;

    -- 6. Update or Record Completed Session in cbt_exam_sessions
    INSERT INTO public.cbt_exam_sessions (
        id,
        user_id,
        exam_id,
        subject,
        started_at,
        duration_minutes,
        expires_at,
        status,
        score_percent,
        total_questions,
        correct_answers,
        metadata,
        completed_at,
        created_at,
        updated_at
    ) VALUES (
        p_session_id,
        COALESCE(v_session.user_id, v_caller_id),
        COALESCE(v_session.exam_id, p_quiz_title),
        v_final_subject,
        COALESCE(v_session.started_at, now() - (p_duration_seconds || ' seconds')::interval),
        COALESCE(v_session.duration_minutes, CEIL(p_duration_seconds::numeric / 60)::int, 60),
        COALESCE(v_session.expires_at, now()),
        'completed',
        v_score_percent,
        p_total_questions,
        p_correct_answers,
        p_metadata,
        now(),
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        status = 'completed',
        score_percent = EXCLUDED.score_percent,
        total_questions = EXCLUDED.total_questions,
        correct_answers = EXCLUDED.correct_answers,
        completed_at = EXCLUDED.completed_at,
        updated_at = now();

    RETURN jsonb_build_object(
        'success', true,
        'quiz_id', p_session_id::text,
        'score_percent', v_score_percent,
        'status', 'completed'
    );
END;
$$;

-- Revoke execute from PUBLIC and anon!
REVOKE ALL ON FUNCTION public.submit_cbt_mock_attempt(UUID, TEXT, TEXT, INT, INT, INT, TEXT[], TEXT, TEXT, UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_cbt_mock_attempt(UUID, TEXT, TEXT, INT, INT, INT, TEXT[], TEXT, TEXT, UUID, JSONB) TO authenticated, service_role;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
