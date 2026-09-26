-- Migration: 20260925030000_track_aware_room_cleanup.sql
-- Clean up legacy pre-seeded static rooms so rooms are organically created or dynamically filtered per track.

DELETE FROM public.study_rooms
WHERE (active_participants_count <= 1 OR active_participants_count IS NULL)
  AND (
      title ILIKE '%Silent Focus Room%'
      OR title ILIKE '%Peer Study Hub%'
  );

-- Update RPC to delete stale rooms with <= 1 active participant after 2 hours
CREATE OR REPLACE FUNCTION cleanup_inactive_study_rooms()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT := 0;
BEGIN
    WITH deleted_rooms AS (
        DELETE FROM public.study_rooms
        WHERE (active_participants_count <= 1 OR active_participants_count IS NULL)
          AND created_at < (now() - INTERVAL '2 hours')
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_count FROM deleted_rooms;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_inactive_rooms_count', v_deleted_count,
        'timestamp', now()
    );
END;
$$;
