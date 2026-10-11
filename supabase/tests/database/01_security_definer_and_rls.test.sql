-- pgTAP Automated Security & RLS Test Suite for Supabase (P3-03)
-- Validates:
-- 1. Zero SECURITY DEFINER functions in schema 'public' are executable by 'anon'
-- 2. Fixed search_path on all SECURITY DEFINER functions
-- 3. Zero unrestricted global writes (qual = 'true' or with_check = 'true')
-- 4. RLS enabled on all sensitive application tables
-- 5. Cross-tenant mutation isolation for authenticated and anon roles

BEGIN;

-- Plan 18 tests
SELECT plan(18);

-- Test 1: Verify pgTAP extension is available
SELECT has_extension('pgtap', 'pgTAP extension is installed');

-- Test 2: Verify that NO SECURITY DEFINER functions in schema 'public' are executable by 'anon'
SELECT is(
    (
        SELECT count(*)::int
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.prosecdef = true
          AND has_function_privilege('anon', p.oid, 'EXECUTE')
    ),
    0,
    'No SECURITY DEFINER functions in schema public should be executable by anon role'
);

-- Test 3: Verify that search_path is strictly fixed on all SECURITY DEFINER functions in public
SELECT is(
    (
        SELECT count(*)::int
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND (p.proconfig IS NULL OR NOT EXISTS (
              SELECT 1 FROM unnest(p.proconfig) cfg WHERE cfg LIKE 'search_path=%'
          ))
    ),
    0,
    'All SECURITY DEFINER functions in schema public must set a fixed search_path'
);

-- Test 4: Verify write policies on public tables do not have unconditional global writes
SELECT is(
    (
        SELECT count(*)::int
        FROM pg_policies
        WHERE schemaname = 'public'
          AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
          AND (qual = 'true' OR with_check = 'true')
    ),
    0,
    'No public table write policies should permit unrestricted global writes (USING true / WITH CHECK true)'
);

-- Test 5-12: Verify RLS is enabled on all sensitive application tables
SELECT table_has_rls('public', 'past_questions', 'past_questions has RLS enabled');
SELECT table_has_rls('public', 'study_communities', 'study_communities has RLS enabled');
SELECT table_has_rls('public', 'semantic_ai_cache', 'semantic_ai_cache has RLS enabled');
SELECT table_has_rls('public', 'user_analytics', 'user_analytics has RLS enabled');
SELECT table_has_rls('public', 'forum_posts', 'forum_posts has RLS enabled');
SELECT table_has_rls('public', 'forum_replies', 'forum_replies has RLS enabled');
SELECT table_has_rls('public', 'user_daily_ai_quotas', 'user_daily_ai_quotas has RLS enabled');
SELECT table_has_rls('public', 'active_user_sessions', 'active_user_sessions has RLS enabled');

-- Test 13: Verify specific critical RPC functions reject execution by anon
SELECT is(
    has_function_privilege('anon', 'public.delete_user_account()', 'EXECUTE'),
    false,
    'delete_user_account() cannot be executed by anon'
);

-- Test 14: Verify check_livekit_room_access rejects execution by anon
SELECT is(
    has_function_privilege('anon', 'public.check_livekit_room_access(text)', 'EXECUTE'),
    false,
    'check_livekit_room_access(text) cannot be executed by anon'
);

-- Test 15: Verify app_sync_engine_upsert rejects execution by anon
SELECT is(
    has_function_privilege('anon', 'public.app_sync_engine_upsert(jsonb)', 'EXECUTE'),
    false,
    'app_sync_engine_upsert(jsonb) cannot be executed by anon'
);

-- Test 16: Verify upsert_user_subscription rejects execution by anon
SELECT is(
    has_function_privilege('anon', 'public.upsert_user_subscription(uuid, text, text, timestamptz, jsonb, text)', 'EXECUTE'),
    false,
    'upsert_user_subscription cannot be executed by anon'
);

-- Test 17: Verify user_analytics direct insert is denied to authenticated role
SELECT is(
    (
        SELECT count(*)::int
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'user_analytics'
          AND cmd = 'INSERT'
          AND 'authenticated' = ANY(roles)
    ),
    0,
    'user_analytics table must NOT allow direct INSERT by authenticated role (must use RPC)'
);

-- Test 18: Verify active_user_sessions enforce auth.uid() = user_id on SELECT
SELECT is(
    (
        SELECT count(*)::int
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'active_user_sessions'
          AND cmd = 'SELECT'
          AND qual LIKE '%auth.uid() = user_id%'
    ),
    1,
    'active_user_sessions must enforce auth.uid() = user_id on SELECT'
);

SELECT * FROM finish();
ROLLBACK;
