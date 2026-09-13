-- ==============================================================================
-- Migration: 20260914030000_create_start_mock_exam_rpc.sql
-- Description: Creates the start_mock_exam RPC endpoint in Supabase to initialize
-- mock exam sessions with parameters (examId, subject, p_exam_id, p_subject).
-- ==============================================================================

DROP FUNCTION IF EXISTS public.start_mock_exam(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_mock_exam(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_mock_exam();

CREATE OR REPLACE FUNCTION public.start_mock_exam(
    p_exam_id TEXT DEFAULT '',
    p_subject TEXT DEFAULT '',
    "examId" TEXT DEFAULT NULL,
    "subject" TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := gen_random_uuid();
    v_actual_exam_id TEXT;
    v_actual_subject TEXT;
BEGIN
    v_actual_exam_id := COALESCE(NULLIF("examId", ''), p_exam_id, '');
    v_actual_subject := COALESCE(NULLIF("subject", ''), p_subject, '');
    RETURN jsonb_build_object(
        'sessionId', v_session_id::text,
        'examId', v_actual_exam_id,
        'subject', v_actual_subject,
        'startedAt', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_mock_exam(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
