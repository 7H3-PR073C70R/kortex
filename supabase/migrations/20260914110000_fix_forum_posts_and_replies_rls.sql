
ALTER TABLE IF EXISTS public.forum_posts 
ALTER COLUMN author_id SET DEFAULT auth.uid();

ALTER TABLE IF EXISTS public.forum_replies 
ALTER COLUMN author_id SET DEFAULT auth.uid();

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

    CREATE POLICY "Anyone can view forum posts"
        ON public.forum_posts FOR SELECT
        TO public
        USING (true);

    CREATE POLICY "Anyone can create forum posts"
        ON public.forum_posts FOR INSERT
        TO public
        WITH CHECK (
            author_id IS NULL 
            OR auth.uid() = author_id 
            OR auth.uid() IS NULL
        );

    CREATE POLICY "Anyone can update forum posts"
        ON public.forum_posts FOR UPDATE
        TO public
        USING (true)
        WITH CHECK (true);

    CREATE POLICY "Authors can delete their forum posts"
        ON public.forum_posts FOR DELETE
        TO authenticated
        USING (auth.uid() = author_id);
END $$;

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

    CREATE POLICY "Anyone can view forum replies"
        ON public.forum_replies FOR SELECT
        TO public
        USING (true);

    CREATE POLICY "Anyone can create forum replies"
        ON public.forum_replies FOR INSERT
        TO public
        WITH CHECK (
            author_id IS NULL 
            OR auth.uid() = author_id 
            OR auth.uid() IS NULL
        );

    CREATE POLICY "Anyone can update forum replies"
        ON public.forum_replies FOR UPDATE
        TO public
        USING (true)
        WITH CHECK (true);

    CREATE POLICY "Authors can delete own replies"
        ON public.forum_replies FOR DELETE
        TO authenticated
        USING (auth.uid() = author_id);
END $$;

NOTIFY pgrst, 'reload schema';
