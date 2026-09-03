-- ==============================================================================
-- Migration: 20260904000000_fix_syllabot_user_id_defaults.sql
-- Description: Set default user_id to auth.uid() on chat_sessions and chat_messages
-- to avoid RLS violation (42501) when creating a session, and grant proper permissions.
-- ==============================================================================

-- 1. Set column defaults to auth.uid()
ALTER TABLE IF EXISTS public.chat_sessions
    ALTER COLUMN user_id SET DEFAULT auth.uid();

ALTER TABLE IF EXISTS public.chat_messages
    ALTER COLUMN user_id SET DEFAULT auth.uid();

-- 2. Audit and ensure RLS policies for chat_sessions and chat_messages
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can create own chat sessions" ON public.chat_sessions;
    CREATE POLICY "Users can create own chat sessions"
        ON public.chat_sessions FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id OR user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can view own chat sessions" ON public.chat_sessions;
    CREATE POLICY "Users can view own chat sessions"
        ON public.chat_sessions FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can update own chat sessions" ON public.chat_sessions;
    CREATE POLICY "Users can update own chat sessions"
        ON public.chat_sessions FOR UPDATE
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can delete own chat sessions" ON public.chat_sessions;
    CREATE POLICY "Users can delete own chat sessions"
        ON public.chat_sessions FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can insert own chat messages" ON public.chat_messages;
    CREATE POLICY "Users can insert own chat messages"
        ON public.chat_messages FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id OR user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can view own chat messages" ON public.chat_messages;
    CREATE POLICY "Users can view own chat messages"
        ON public.chat_messages FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- 3. Explicitly grant permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_messages TO authenticated;
