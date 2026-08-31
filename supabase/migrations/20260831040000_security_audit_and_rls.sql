-- ==============================================================================
-- KORTEX SECURITY AUDIT & ROW LEVEL SECURITY (RLS) POLICIES
-- Target: Data Isolation, Community Governance, Service-Role Hardening
-- ==============================================================================

-- 1. HARDEN CORE PRIVATE DATA TABLES (Strict auth.uid() Ownership)
-- ------------------------------------------------------------------------------

-- User Profiles
ALTER TABLE IF EXISTS public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
CREATE POLICY "Users can view own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Decks
ALTER TABLE IF EXISTS public.decks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own decks" ON public.decks;
CREATE POLICY "Users can view own decks"
    ON public.decks FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own decks" ON public.decks;
CREATE POLICY "Users can create own decks"
    ON public.decks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own decks" ON public.decks;
CREATE POLICY "Users can update own decks"
    ON public.decks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own decks" ON public.decks;
CREATE POLICY "Users can delete own decks"
    ON public.decks FOR DELETE
    USING (auth.uid() = user_id);

-- Flashcards
ALTER TABLE IF EXISTS public.flashcards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own flashcards" ON public.flashcards;
CREATE POLICY "Users can view own flashcards"
    ON public.flashcards FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own flashcards" ON public.flashcards;
CREATE POLICY "Users can create own flashcards"
    ON public.flashcards FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own flashcards" ON public.flashcards;
CREATE POLICY "Users can update own flashcards"
    ON public.flashcards FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own flashcards" ON public.flashcards;
CREATE POLICY "Users can delete own flashcards"
    ON public.flashcards FOR DELETE
    USING (auth.uid() = user_id);

-- Study Documents & OCR Ingestions
ALTER TABLE IF EXISTS public.documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own documents" ON public.documents;
CREATE POLICY "Users can view own documents"
    ON public.documents FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own documents" ON public.documents;
CREATE POLICY "Users can create own documents"
    ON public.documents FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own documents" ON public.documents;
CREATE POLICY "Users can update own documents"
    ON public.documents FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own documents" ON public.documents;
CREATE POLICY "Users can delete own documents"
    ON public.documents FOR DELETE
    USING (auth.uid() = user_id);

-- Syllabot Chat Sessions & Messages
ALTER TABLE IF EXISTS public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat sessions" ON public.chat_sessions;
CREATE POLICY "Users can view own chat sessions"
    ON public.chat_sessions FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own chat sessions" ON public.chat_sessions;
CREATE POLICY "Users can create own chat sessions"
    ON public.chat_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own chat sessions" ON public.chat_sessions;
CREATE POLICY "Users can delete own chat sessions"
    ON public.chat_sessions FOR DELETE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own chat messages" ON public.chat_messages;
CREATE POLICY "Users can view own chat messages"
    ON public.chat_messages FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own chat messages" ON public.chat_messages;
CREATE POLICY "Users can insert own chat messages"
    ON public.chat_messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);


-- 2. COMMUNITY GOVERNANCE POLICIES (Public Read, Author-Only Mutations)
-- ------------------------------------------------------------------------------

-- Shared Decks Marketplace
ALTER TABLE IF EXISTS public.shared_decks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view public shared decks" ON public.shared_decks;
CREATE POLICY "Anyone can view public shared decks"
    ON public.shared_decks FOR SELECT
    USING (is_public = true OR auth.uid() = creator_id);

DROP POLICY IF EXISTS "Creators can publish shared decks" ON public.shared_decks;
CREATE POLICY "Creators can publish shared decks"
    ON public.shared_decks FOR INSERT
    WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Creators can update own shared decks" ON public.shared_decks;
CREATE POLICY "Creators can update own shared decks"
    ON public.shared_decks FOR UPDATE
    USING (auth.uid() = creator_id)
    WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Creators can delete own shared decks" ON public.shared_decks;
CREATE POLICY "Creators can delete own shared decks"
    ON public.shared_decks FOR DELETE
    USING (auth.uid() = creator_id);

-- Forum Discussion Posts
ALTER TABLE IF EXISTS public.forum_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view forum posts" ON public.forum_posts;
CREATE POLICY "Anyone can view forum posts"
    ON public.forum_posts FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can create forum posts" ON public.forum_posts;
CREATE POLICY "Authenticated users can create forum posts"
    ON public.forum_posts FOR INSERT
    WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Authors can update own forum posts" ON public.forum_posts;
CREATE POLICY "Authors can update own forum posts"
    ON public.forum_posts FOR UPDATE
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Authors can delete own forum posts" ON public.forum_posts;
CREATE POLICY "Authors can delete own forum posts"
    ON public.forum_posts FOR DELETE
    USING (auth.uid() = author_id);

-- Realtime Study Rooms
ALTER TABLE IF EXISTS public.study_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active study rooms" ON public.study_rooms;
CREATE POLICY "Anyone can view active study rooms"
    ON public.study_rooms FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can host study rooms" ON public.study_rooms;
CREATE POLICY "Authenticated users can host study rooms"
    ON public.study_rooms FOR INSERT
    WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS "Hosts can update own study rooms" ON public.study_rooms;
CREATE POLICY "Hosts can update own study rooms"
    ON public.study_rooms FOR UPDATE
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS "Hosts can close own study rooms" ON public.study_rooms;
CREATE POLICY "Hosts can close own study rooms"
    ON public.study_rooms FOR DELETE
    USING (auth.uid() = host_id);


-- 3. SERVICE ROLE CONSTRAINTS & BACKGROUND ENGINE FUNCTIONS
-- ------------------------------------------------------------------------------

-- Restrict leaderboard calculation to service_role or admin triggers
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Ensure Leaderboard calculation function is protected
CREATE OR REPLACE FUNCTION public.calculate_leaderboard_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only allow execution by service_role
    IF auth.role() != 'service_role' AND auth.role() IS NOT NULL THEN
        RAISE EXCEPTION 'Access Denied: Service role execution required';
    END IF;

    -- Compute and update user rankings based on streak and review counts
    UPDATE public.user_profiles
    SET level = GREATEST(1, FLOOR(streak_days / 7) + 1);
END;
$$;

-- Ensure AI Session Cleanup is protected
CREATE OR REPLACE FUNCTION public.cleanup_stale_ai_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.role() != 'service_role' AND auth.role() IS NOT NULL THEN
        RAISE EXCEPTION 'Access Denied: Service role execution required';
    END IF;

    DELETE FROM public.chat_sessions
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$;
