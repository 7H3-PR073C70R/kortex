
ALTER TABLE IF EXISTS public.forum_posts 
ADD COLUMN IF NOT EXISTS downvotes INTEGER NOT NULL DEFAULT 0;

ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS downvotes INTEGER NOT NULL DEFAULT 0;

ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS parent_reply_id UUID REFERENCES public.forum_replies(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_forum_replies_parent_reply_id 
ON public.forum_replies(parent_reply_id);

DO $$
BEGIN
    DROP POLICY IF EXISTS "Authors can update their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can update forum posts" ON public.forum_posts;

    CREATE POLICY "Authenticated users can update forum posts"
        ON public.forum_posts FOR UPDATE
        TO authenticated
        USING (true)
        WITH CHECK (true);

    DROP POLICY IF EXISTS "Authenticated users can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can update own replies" ON public.forum_replies;

    CREATE POLICY "Authenticated users can update forum replies"
        ON public.forum_replies FOR UPDATE
        TO authenticated
        USING (true)
        WITH CHECK (true);
END $$;

NOTIFY pgrst, 'reload schema';
