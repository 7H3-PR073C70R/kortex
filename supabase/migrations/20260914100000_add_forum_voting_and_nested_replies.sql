-- Migration: 20260914100000_add_forum_voting_and_nested_replies.sql
-- Description: Add downvotes to forum_posts and forum_replies, add parent_reply_id for nested replies, and ensure RLS and schema cache reload

-- 1. Add downvotes column to forum_posts
ALTER TABLE IF EXISTS public.forum_posts 
ADD COLUMN IF NOT EXISTS downvotes INTEGER NOT NULL DEFAULT 0;

-- 2. Add downvotes and parent_reply_id columns to forum_replies
ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS downvotes INTEGER NOT NULL DEFAULT 0;

ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS parent_reply_id UUID REFERENCES public.forum_replies(id) ON DELETE CASCADE;

-- 3. Create index for fast retrieval of nested reply trees
CREATE INDEX IF NOT EXISTS idx_forum_replies_parent_reply_id 
ON public.forum_replies(parent_reply_id);

-- 4. Ensure RLS policies permit authenticated users to interact with forum posts and replies
DO $$
BEGIN
    -- Forum Posts UPDATE policy for voting and editing
    DROP POLICY IF EXISTS "Authors can update their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can update forum posts" ON public.forum_posts;

    CREATE POLICY "Authenticated users can update forum posts"
        ON public.forum_posts FOR UPDATE
        TO authenticated
        USING (true)
        WITH CHECK (true);

    -- Forum Replies UPDATE policy for voting and verification
    DROP POLICY IF EXISTS "Authenticated users can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can update own replies" ON public.forum_replies;

    CREATE POLICY "Authenticated users can update forum replies"
        ON public.forum_replies FOR UPDATE
        TO authenticated
        USING (true)
        WITH CHECK (true);
END $$;

-- 5. Reload PostgREST schema cache to immediately reflect column additions
NOTIFY pgrst, 'reload schema';
