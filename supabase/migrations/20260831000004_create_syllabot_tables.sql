-- ==============================================================================
-- Migration: 20260831000004_create_syllabot_tables.sql
-- Description: Chat sessions, real-time message logs, strict RLS, and maintenance
-- ==============================================================================

-- 1. Create chat_sessions table
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Study Session',
    socratic_mode TEXT NOT NULL DEFAULT 'stepByStep' CHECK (socratic_mode IN ('stepByStep', 'directAnswer', 'examSim', 'deepResearch')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('user', 'syllabot')),
    text TEXT NOT NULL,
    latex_snippets TEXT[] DEFAULT '{}',
    engine_type TEXT NOT NULL DEFAULT 'cloudSupabase' CHECK (engine_type IN ('cloudSupabase', 'localOnDevice')),
    tokens_count INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Indexes for rapid session retrieval and thread traversal
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON public.chat_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON public.chat_messages(session_id, created_at ASC);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 5. Strict RLS Policies
CREATE POLICY "Users can manage their own chat sessions"
ON public.chat_sessions
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage their own chat messages"
ON public.chat_messages
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 6. Trigger for updated_at on chat_sessions
CREATE OR REPLACE FUNCTION public.update_chat_session_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_chat_session_timestamp ON public.chat_sessions;
CREATE TRIGGER trg_update_chat_session_timestamp
BEFORE UPDATE ON public.chat_sessions
FOR EACH ROW
EXECUTE FUNCTION public.update_chat_session_timestamp();

-- 7. Auto-cleanup function for inactive guest / transient sessions (> 90 days)
CREATE OR REPLACE FUNCTION public.cleanup_expired_chat_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM public.chat_sessions
    WHERE updated_at < (now() - INTERVAL '90 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
