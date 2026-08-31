-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 008 - Master Row Level Security (RLS) Audit
-- Modules: Auth, Dashboard, Decks & SM-2/FSRS, Syllabot RAG, Ingestion, Community
-- ==============================================================================

-- 1. Enable RLS unconditionally on all user and study tables
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_calibrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.heatmap_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shared_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.leaderboards ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 2. Audit & Enforce User Isolation Policies (Private Tables)
-- ==============================================================================

-- Profiles Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

    CREATE POLICY "Users can view own profile"
        ON public.profiles FOR SELECT
        TO authenticated
        USING (auth.uid() = id);

    CREATE POLICY "Users can update own profile"
        ON public.profiles FOR UPDATE
        TO authenticated
        USING (auth.uid() = id)
        WITH CHECK (auth.uid() = id);

    CREATE POLICY "Users can insert own profile"
        ON public.profiles FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = id);
END $$;

-- Document Chunks & Vector Search Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can query their own document chunks" ON public.document_chunks;
    DROP POLICY IF EXISTS "Users can insert their own document chunks" ON public.document_chunks;
    DROP POLICY IF EXISTS "Users can delete their own document chunks" ON public.document_chunks;

    CREATE POLICY "Users can query their own document chunks"
        ON public.document_chunks FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their own document chunks"
        ON public.document_chunks FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete their own document chunks"
        ON public.document_chunks FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- Decks & Flashcards Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own decks" ON public.decks;
    DROP POLICY IF EXISTS "Users can manage their own flashcards" ON public.flashcards;

    CREATE POLICY "Users can manage their own decks"
        ON public.decks FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can manage their own flashcards"
        ON public.flashcards FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;

-- ==============================================================================
-- 3. Audit & Enforce Community Public-Read / Owner-Write Policies
-- ==============================================================================

-- Forum Posts Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can create forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can delete their forum posts" ON public.forum_posts;

    -- Public Read
    CREATE POLICY "Anyone can view forum posts"
        ON public.forum_posts FOR SELECT
        TO authenticated
        USING (true);

    -- Owner Write
    CREATE POLICY "Authenticated users can create forum posts"
        ON public.forum_posts FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = author_id);

    CREATE POLICY "Authors can update their forum posts"
        ON public.forum_posts FOR UPDATE
        TO authenticated
        USING (auth.uid() = author_id)
        WITH CHECK (auth.uid() = author_id);

    CREATE POLICY "Authors can delete their forum posts"
        ON public.forum_posts FOR DELETE
        TO authenticated
        USING (auth.uid() = author_id);
END $$;

-- Shared Decks Marketplace Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view shared decks" ON public.shared_decks;
    DROP POLICY IF EXISTS "Authenticated users can publish shared decks" ON public.shared_decks;
    DROP POLICY IF EXISTS "Owners can update shared decks" ON public.shared_decks;
    DROP POLICY IF EXISTS "Owners can delete shared decks" ON public.shared_decks;

    -- Public Read
    CREATE POLICY "Anyone can view shared decks"
        ON public.shared_decks FOR SELECT
        TO authenticated
        USING (true);

    -- Owner Write
    CREATE POLICY "Authenticated users can publish shared decks"
        ON public.shared_decks FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = owner_id);

    CREATE POLICY "Owners can update shared decks"
        ON public.shared_decks FOR UPDATE
        TO authenticated
        USING (auth.uid() = owner_id)
        WITH CHECK (auth.uid() = owner_id);

    CREATE POLICY "Owners can delete shared decks"
        ON public.shared_decks FOR DELETE
        TO authenticated
        USING (auth.uid() = owner_id);
END $$;

-- Leaderboards Policy Audit
DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view leaderboard standings" ON public.leaderboards;
    DROP POLICY IF EXISTS "System and user can update leaderboard" ON public.leaderboards;

    CREATE POLICY "Anyone can view leaderboard standings"
        ON public.leaderboards FOR SELECT
        TO authenticated
        USING (true);

    CREATE POLICY "Users can manage their own leaderboard entry"
        ON public.leaderboards FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;
