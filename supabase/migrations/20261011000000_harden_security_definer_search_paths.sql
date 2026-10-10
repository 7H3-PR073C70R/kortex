-- ==============================================================================
-- KORTEX SECURITY HARDENING MIGRATION: 20261011000000
-- Enforce explicit search_path on all SECURITY DEFINER functions in schema 'public'
-- to mitigate CVE / privilege-escalation via search_path hijacking.
-- ==============================================================================

DO $$
DECLARE
    r RECORD;
    v_sql TEXT;
    v_count INT := 0;
BEGIN
    FOR r IN
        SELECT 
            p.oid, 
            n.nspname, 
            p.proname, 
            pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND (
            p.proconfig IS NULL 
            OR NOT (
                'search_path=public, pg_temp' = ANY(p.proconfig)
                OR 'search_path=public,pg_temp' = ANY(p.proconfig)
                OR 'search_path=public, auth' = ANY(p.proconfig)
                OR 'search_path=public, auth, pg_temp' = ANY(p.proconfig)
            )
          )
    LOOP
        v_sql := format(
            'ALTER FUNCTION %I.%I(%s) SET search_path = public, pg_temp;', 
            r.nspname, 
            r.proname, 
            r.args
        );
        BEGIN
            EXECUTE v_sql;
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Notice: Could not alter function %.%(%): %', r.nspname, r.proname, r.args, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Successfully hardened % SECURITY DEFINER functions with search_path = public, pg_temp.', v_count;
END;
$$;

-- Explicit hardening for key public RPC functions
DO $$
BEGIN
    -- Community & Study circles
    EXECUTE 'ALTER FUNCTION public.nudge_study_circle_rpc(UUID) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.record_pod_focus_minutes_rpc(UUID, INT) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.cleanup_inactive_study_rooms() SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.cleanup_stale_study_pods_and_rooms() SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.verify_forum_reply(UUID, UUID) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.rate_shared_deck(UUID, DOUBLE PRECISION) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.delete_shared_deck(UUID) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.clone_shared_deck(UUID) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.award_user_xp(UUID, INT, TEXT, TEXT, JSONB) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.claim_weekly_xp(INT) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.sync_profile_to_leaderboard() SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.sync_analytics_streak_to_leaderboard() SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.register_device_session_rpc(TEXT, TEXT, TEXT) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.disconnect_device_session_rpc(TEXT) SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER FUNCTION public.on_password_reset_purge_sessions() SET search_path = public, pg_temp';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
