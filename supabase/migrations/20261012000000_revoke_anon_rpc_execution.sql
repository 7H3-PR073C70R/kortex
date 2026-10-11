-- ==============================================================================
-- KORTEX SECURITY HARDENING: 20261012000000
-- Blanket Revocation of Public and Anon Function Execution Privileges
-- Closes unguarded SECURITY DEFINER RPC exposure to unauthenticated callers.
-- ==============================================================================

-- 1. Blanket Revocation: Strip EXECUTE on all functions in schema 'public' from PUBLIC and anon
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

-- 2. Modify Default Privileges: Ensure future functions created in schema 'public' do NOT
-- automatically grant EXECUTE to PUBLIC or anon by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;

-- 3. Restore Core Privileges to internal service role and authenticated app users
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- 4. Explicitly Revoke Sensitive Internal / Admin / Service-Role Functions from authenticated
-- Ordinary signed-in users must NOT be able to call administrative, worker, or background routines directly.
-- Dynamically query pg_proc to accurately resolve all overloads and exact argument signatures.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.oid::regprocedure AS proc_name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND (
            p.proname ILIKE '%admin%' OR
            p.proname ILIKE 'cleanup_%' OR
            p.proname ILIKE 'dequeue_%' OR
            p.proname ILIKE 'purge_%' OR
            p.proname IN (
                'check_and_record_rate_limit',
                'put_semantic_cache',
                'store_cached_response',
                'award_user_xp',
                'sanitize_user_metadata'
            )
          )
    ) LOOP
        EXECUTE 'REVOKE EXECUTE ON FUNCTION ' || r.proc_name || ' FROM authenticated;';
    END LOOP;
END $$;

-- 5. Explicitly Re-Grant Strictly Read-Only Discovery RPCs to anon
-- Allows prospective/guest students to browse forum discussions and view public curriculum metadata
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.oid::regprocedure AS proc_name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
            'fetch_forum_posts_keyset',
            'fetch_forum_thread_tree'
          )
    ) LOOP
        EXECUTE 'GRANT EXECUTE ON FUNCTION ' || r.proc_name || ' TO anon;';
    END LOOP;
END $$;
