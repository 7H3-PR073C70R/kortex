-- ==============================================================================
-- Migration: 20260914030000_create_start_mock_exam_rpc.sql
-- Description: Creates the start_mock_exam RPC endpoint in Supabase to initialize
-- mock exam sessions with parameters (examId, subject).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.start_mock_exam(
    "examId" TEXT DEFAULT '',
    "subject" TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := gen_random_uuid();
BEGIN
    RETURN jsonb_build_object(
        'sessionId', v_session_id::text,
        'examId', "examId",
        'subject', "subject",
        'startedAt', now()
    );
END;
$$;

-- Support snake_case parameters if called with p_exam_id / p_subject
CREATE OR REPLACE FUNCTION public.start_mock_exam(
    p_exam_id TEXT DEFAULT '',
    p_subject TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := gen_random_uuid();
BEGIN
    RETURN jsonb_build_object(
        'sessionId', v_session_id::text,
        'examId', p_exam_id,
        'subject', p_subject,
        'startedAt', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_mock_exam(TEXT, TEXT) TO authenticated, anon;
