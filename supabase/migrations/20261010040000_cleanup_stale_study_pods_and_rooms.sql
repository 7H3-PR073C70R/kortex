-- Migration: 20261010040000_cleanup_stale_study_pods_and_rooms.sql
-- Function to clean up inactive/stale study rooms and stale/empty study pods.

CREATE OR REPLACE FUNCTION public.cleanup_stale_study_pods_and_rooms()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_rooms INT := 0;
    v_deleted_pods INT := 0;
BEGIN
    -- 1. Delete user-created focus rooms older than 12 hours OR empty user-created rooms older than 30 minutes
    WITH deleted_r AS (
        DELETE FROM public.study_rooms
        WHERE title NOT ILIKE '%Official Silent Focus Hub%'
          AND title NOT ILIKE '%General Peer Focus Hub%'
          AND (
              active_participants_count <= 0 
              OR active_participants_count IS NULL 
              OR created_at < (now() - INTERVAL '12 hours')
          )
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_rooms FROM deleted_r;

    -- 2. Delete inactive/empty study pods created more than 7 days ago with <= 1 member and 0 focus minutes
    WITH deleted_p AS (
        DELETE FROM public.study_circles
        WHERE (
            (member_count <= 1 AND total_minutes_completed = 0 AND created_at < (now() - INTERVAL '7 days'))
            OR (created_at < (now() - INTERVAL '30 days'))
        )
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted_pods FROM deleted_p;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_rooms_count', v_deleted_rooms,
        'deleted_pods_count', v_deleted_pods,
        'timestamp', now()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_stale_study_pods_and_rooms() TO authenticated, anon, service_role;

-- Execute cleanup immediately on migration
SELECT public.cleanup_stale_study_pods_and_rooms();

-- Schedule recurring pg_cron job to run cleanup every hour
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('cleanup-stale-study-pods-and-rooms')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-stale-study-pods-and-rooms');

        PERFORM cron.schedule(
            'cleanup-stale-study-pods-and-rooms',
            '0 * * * *',
            'SELECT public.cleanup_stale_study_pods_and_rooms();'
        );
    END IF;
END $$;
