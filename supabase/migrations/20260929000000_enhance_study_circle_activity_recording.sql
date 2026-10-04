-- Migration: 20260929000000_enhance_study_circle_activity_recording.sql
-- Upgrades record_pod_focus_minutes_rpc to support activity type logging and robust minute attribution.

CREATE OR REPLACE FUNCTION record_pod_focus_minutes_rpc(
    p_circle_id UUID DEFAULT NULL,
    p_minutes INT DEFAULT 0,
    p_activity_type TEXT DEFAULT 'general'
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
        RAISE EXCEPTION 'Unauthorized: User must be authenticated to record study circle activity';
    END IF;

    -- If minutes is zero or negative, return gracefully without failure
    IF p_minutes <= 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', 0,
            'minutes_added_per_pod', 0,
            'message', 'No focus minutes earned (duration too short)'
        );
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
            'minutes_added_per_pod', p_minutes,
            'activity_type', p_activity_type
        );
    END IF;

    -- If no specific pod is passed, distribute minutes evenly across scholar's joined pods
    SELECT COUNT(*) INTO v_pod_count
    FROM public.study_circle_members
    WHERE user_id = v_user_id;

    IF v_pod_count <= 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', 0,
            'message', 'User is not a member of any active study pod'
        );
    END IF;

    -- Divide elapsed minutes by number of joined pods (min 1 min per pod if total > 0)
    v_split_minutes := GREATEST(1, p_minutes / v_pod_count);

    UPDATE public.study_circle_members
    SET weekly_minutes_contributed = weekly_minutes_contributed + v_split_minutes
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'updated_circles_count', v_updated_count,
        'minutes_added_per_pod', v_split_minutes,
        'total_actual_minutes', p_minutes,
        'activity_type', p_activity_type
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_pod_focus_minutes_rpc(UUID, INT, TEXT) TO authenticated, anon, service_role;
NOTIFY pgrst, 'reload schema';
