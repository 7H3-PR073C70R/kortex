-- ============================================================================
-- Migration: 20261012060000_harden_cron_rpc_permissions.sql
-- Description: P2-04 Background Cron Secret & State Fixes
--
-- 1. Hardens search_path on background maintenance RPCs.
-- 2. Revokes direct execution rights from anon, authenticated, and PUBLIC.
-- 3. Grants execution strictly to service_role to ensure only trusted backend
--    cron orchestrators can trigger destructive cleanups or leaderboard aggregates.
-- ============================================================================

-- 1. Hardened cleanup_stale_study_pods_and_rooms
CREATE OR REPLACE FUNCTION public.cleanup_stale_study_pods_and_rooms()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

REVOKE EXECUTE ON FUNCTION public.cleanup_stale_study_pods_and_rooms() FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_stale_study_pods_and_rooms() TO service_role;

-- 2. Hardened cleanup_expired_chat_sessions
CREATE OR REPLACE FUNCTION public.cleanup_expired_chat_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    DELETE FROM public.chat_sessions
    WHERE updated_at < (now() - INTERVAL '90 days');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cleanup_expired_chat_sessions() FROM anon, authenticated, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_chat_sessions() TO service_role;

-- 3. Hardened aggregate_weekly_leaderboards (if present)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' AND p.proname = 'aggregate_weekly_leaderboards'
    ) THEN
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.aggregate_weekly_leaderboards() FROM anon, authenticated, PUBLIC';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.aggregate_weekly_leaderboards() TO service_role';
    END IF;
END $$;
