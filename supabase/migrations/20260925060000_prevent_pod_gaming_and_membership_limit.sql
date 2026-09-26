-- Migration: 20260925060000_prevent_pod_gaming_and_membership_limit.sql
-- Enforces a maximum of 2 Study Circles per scholar and prevents double-counting focus minutes across multiple pods.

-- 1. Trigger Function to enforce max 2 pods per user
CREATE OR REPLACE FUNCTION enforce_max_pods_per_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pod_count INT;
BEGIN
    SELECT COUNT(*) INTO v_pod_count
    FROM public.study_circle_members
    WHERE user_id = NEW.user_id;

    IF v_pod_count >= 2 THEN
        RAISE EXCEPTION 'Scholar limit reached: You can belong to a maximum of 2 active Study Pods at a time.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_enforce_max_pods_per_user ON public.study_circle_members;

CREATE TRIGGER trigger_enforce_max_pods_per_user
BEFORE INSERT ON public.study_circle_members
FOR EACH ROW
EXECUTE FUNCTION enforce_max_pods_per_user();

-- 2. Anti-Gaming RPC for Focus Minutes: Single-Instance Distribution (No Double-Counting)
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
    v_pod_count INT := 0;
    v_split_minutes INT := 0;
    v_updated_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_minutes <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Minutes must be greater than zero');
    END IF;

    -- If a specific pod circle_id is provided, credit minutes ONLY to that pod
    IF p_circle_id IS NOT NULL THEN
        UPDATE public.study_circle_members
        SET weekly_minutes_contributed = weekly_minutes_contributed + p_minutes
        WHERE circle_id = p_circle_id AND user_id = v_user_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', v_updated_count,
            'minutes_added_per_pod', p_minutes
        );
    END IF;

    -- If no specific pod is passed (e.g. CBT / Quiz), distribute minutes evenly across scholar's joined pods
    SELECT COUNT(*) INTO v_pod_count
    FROM public.study_circle_members
    WHERE user_id = v_user_id;

    IF v_pod_count <= 0 THEN
        RETURN jsonb_build_object('success', true, 'updated_circles_count', 0, 'message', 'User is not in any pod');
    END IF;

    -- Divide elapsed minutes by number of joined pods (e.g., 30 mins / 2 pods = 15 mins each)
    v_split_minutes := GREATEST(1, p_minutes / v_pod_count);

    UPDATE public.study_circle_members
    SET weekly_minutes_contributed = weekly_minutes_contributed + v_split_minutes
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'updated_circles_count', v_updated_count,
        'minutes_added_per_pod', v_split_minutes,
        'total_actual_minutes', p_minutes
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_pod_focus_minutes_rpc(UUID, INT) TO authenticated, anon, service_role;
NOTIFY pgrst, 'reload schema';
