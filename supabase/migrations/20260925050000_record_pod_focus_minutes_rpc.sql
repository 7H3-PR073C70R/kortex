-- Migration: 20260925050000_record_pod_focus_minutes_rpc.sql
-- RPC & Trigger to automatically record and sync focus minutes for pod members across Quizzes, CBTs, Mock Exams, and Pomodoro sessions.

-- 1. Trigger Function to sync total_minutes_completed on study_circles
CREATE OR REPLACE FUNCTION sync_study_circle_total_minutes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.study_circles
    SET total_minutes_completed = (
        SELECT COALESCE(SUM(weekly_minutes_contributed), 0)
        FROM public.study_circle_members
        WHERE circle_id = NEW.circle_id
    ),
    updated_at = now()
    WHERE id = NEW.circle_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_study_circle_total_minutes ON public.study_circle_members;

CREATE TRIGGER trigger_sync_study_circle_total_minutes
AFTER INSERT OR UPDATE OF weekly_minutes_contributed OR DELETE
ON public.study_circle_members
FOR EACH ROW
EXECUTE FUNCTION sync_study_circle_total_minutes();

-- 2. RPC to record focus minutes when a scholar finishes a Pomodoro timer, CBT, Quiz, or Mock Exam
CREATE OR REPLACE FUNCTION record_pod_focus_minutes_rpc(
    p_circle_id UUID DEFAULT NULL,
    p_minutes INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_minutes <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Minutes must be greater than zero');
    END IF;

    IF p_circle_id IS NOT NULL THEN
        UPDATE public.study_circle_members
        SET weekly_minutes_contributed = weekly_minutes_contributed + p_minutes
        WHERE circle_id = p_circle_id AND user_id = v_user_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    ELSE
        UPDATE public.study_circle_members
        SET weekly_minutes_contributed = weekly_minutes_contributed + p_minutes
        WHERE user_id = v_user_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'updated_circles_count', v_updated_count,
        'minutes_added', p_minutes
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_pod_focus_minutes_rpc(UUID, INT) TO authenticated, anon, service_role;
NOTIFY pgrst, 'reload schema';
