-- Migration: 20260914110000_fix_forum_posts_and_replies_rls.sql
-- Description: Fix RLS insert, update, and select policies on forum_posts and forum_replies to support anonymous posts and authenticated creators

-- 1. Ensure author_id column has default auth.uid()
ALTER TABLE IF EXISTS public.forum_posts 
ALTER COLUMN author_id SET DEFAULT auth.uid();

ALTER TABLE IF EXISTS public.forum_replies 
ALTER COLUMN author_id SET DEFAULT auth.uid();

-- 2. Audit and update RLS policies on forum_posts
DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can view forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can create forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Anyone can create forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can update forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Anyone can update forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can delete their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can delete own forum posts" ON public.forum_posts;

    -- SELECT: Public can view all forum posts
    CREATE POLICY "Anyone can view forum posts"
        ON public.forum_posts FOR SELECT
        TO public
        USING (true);

    -- INSERT: Authenticated & anon users can create posts (supports anonymous posts with null author_id)
    CREATE POLICY "Anyone can create forum posts"
        ON public.forum_posts FOR INSERT
        TO public
        WITH CHECK (
            author_id IS NULL 
            OR auth.uid() = author_id 
            OR auth.uid() IS NULL
        );

    -- UPDATE: Allow voting & author editing
    CREATE POLICY "Anyone can update forum posts"
        ON public.forum_posts FOR UPDATE
        TO public
        USING (true)
        WITH CHECK (true);

    -- DELETE: Authors can delete their own posts
    CREATE POLICY "Authors can delete their forum posts"
        ON public.forum_posts FOR DELETE
        TO authenticated
        USING (auth.uid() = author_id);
END $$;

-- 3. Audit and update RLS policies on forum_replies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can view forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can create forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Anyone can create forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Anyone can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can update own replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can delete own replies" ON public.forum_replies;

    -- SELECT: Public can view all replies
    CREATE POLICY "Anyone can view forum replies"
        ON public.forum_replies FOR SELECT
        TO public
        USING (true);

    -- INSERT: Authenticated & anon users can add replies
    CREATE POLICY "Anyone can create forum replies"
        ON public.forum_replies FOR INSERT
        TO public
        WITH CHECK (
            author_id IS NULL 
            OR auth.uid() = author_id 
            OR auth.uid() IS NULL
        );

    -- UPDATE: Allow voting & solution verification
    CREATE POLICY "Anyone can update forum replies"
        ON public.forum_replies FOR UPDATE
        TO public
        USING (true)
        WITH CHECK (true);

    -- DELETE: Authors can delete their own replies
    CREATE POLICY "Authors can delete own replies"
        ON public.forum_replies FOR DELETE
        TO authenticated
        USING (auth.uid() = author_id);
END $$;

-- 4. Notify PostgREST to reload schema and RLS cache immediately
NOTIFY pgrst, 'reload schema';
