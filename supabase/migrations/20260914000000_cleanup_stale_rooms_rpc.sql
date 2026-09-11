-- Migration: Stale Study Room Cleanup & Maintenance RPC
-- Archives or removes inactive non-default study rooms with 0 participants older than 24 hours

CREATE OR REPLACE FUNCTION cleanup_inactive_study_rooms()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    -- Delete ad-hoc study rooms that:
    -- 1. Have active_participants_count = 0 (or null)
    -- 2. Were created more than 24 hours ago
    -- 3. Are NOT the designated active_room_id for any auto-provisioned study community
    WITH deleted_rooms AS (
        DELETE FROM public.study_rooms
        WHERE (active_participants_count <= 0 OR active_participants_count IS NULL)
          AND created_at < (now() - INTERVAL '24 hours')
          AND id NOT IN (
              SELECT active_room_id 
              FROM public.study_communities 
              WHERE active_room_id IS NOT NULL
          )
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_count FROM deleted_rooms;

    -- Update active_rooms_count on study_communities based on surviving rooms
    UPDATE public.study_communities sc
    SET active_rooms_count = (
        SELECT COUNT(*)
        FROM public.study_rooms sr
        WHERE sr.subject = sc.course_code
           OR sr.category = sc.department
    ),
    updated_at = now();

    RETURN jsonb_build_object(
        'success', true,
        'deleted_inactive_rooms_count', v_deleted_count,
        'timestamp', now()
    );
END;
$$;
