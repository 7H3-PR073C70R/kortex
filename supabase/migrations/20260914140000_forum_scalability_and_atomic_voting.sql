-- Migration: 20260914140000_forum_scalability_and_atomic_voting.sql
-- Description: Implement normalized atomic voting, full-text search indexing, performance indexes, and asynchronous notification queuing for Forum & Community scaling

-- 1. Create Normalized Votes Tables
CREATE TABLE IF NOT EXISTS public.forum_post_votes (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
    vote_direction INT NOT NULL CHECK (vote_direction IN (-1, 0, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_post_votes_post_id ON public.forum_post_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_post_votes_user_id ON public.forum_post_votes(user_id);

ALTER TABLE public.forum_post_votes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view forum post votes" ON public.forum_post_votes;
    DROP POLICY IF EXISTS "Users can insert own forum post votes" ON public.forum_post_votes;
    DROP POLICY IF EXISTS "Users can update own forum post votes" ON public.forum_post_votes;
    DROP POLICY IF EXISTS "Users can delete own forum post votes" ON public.forum_post_votes;

    CREATE POLICY "Users can view forum post votes"
        ON public.forum_post_votes FOR SELECT
        TO authenticated
        USING (true);

    CREATE POLICY "Users can insert own forum post votes"
        ON public.forum_post_votes FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own forum post votes"
        ON public.forum_post_votes FOR UPDATE
        TO authenticated
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can delete own forum post votes"
        ON public.forum_post_votes FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

CREATE TABLE IF NOT EXISTS public.forum_reply_votes (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reply_id UUID NOT NULL REFERENCES public.forum_replies(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
    vote_direction INT NOT NULL CHECK (vote_direction IN (-1, 0, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, reply_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_reply_votes_reply_id ON public.forum_reply_votes(reply_id);
CREATE INDEX IF NOT EXISTS idx_forum_reply_votes_post_id ON public.forum_reply_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_reply_votes_user_id ON public.forum_reply_votes(user_id);

ALTER TABLE public.forum_reply_votes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view forum reply votes" ON public.forum_reply_votes;
    DROP POLICY IF EXISTS "Users can insert own forum reply votes" ON public.forum_reply_votes;
    DROP POLICY IF EXISTS "Users can update own forum reply votes" ON public.forum_reply_votes;
    DROP POLICY IF EXISTS "Users can delete own forum reply votes" ON public.forum_reply_votes;

    CREATE POLICY "Users can view forum reply votes"
        ON public.forum_reply_votes FOR SELECT
        TO authenticated
        USING (true);

    CREATE POLICY "Users can insert own forum reply votes"
        ON public.forum_reply_votes FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update own forum reply votes"
        ON public.forum_reply_votes FOR UPDATE
        TO authenticated
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can delete own forum reply votes"
        ON public.forum_reply_votes FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- 2. Atomic Stored Procedure: Vote on Forum Post
CREATE OR REPLACE FUNCTION public.vote_forum_post_atomic(
    p_post_id UUID,
    p_vote_direction INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_old_vote INT := 0;
    v_new_vote INT;
    v_delta_up INT := 0;
    v_delta_down INT := 0;
    v_res_upvotes INT;
    v_res_downvotes INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to vote on forum posts';
    END IF;

    IF p_vote_direction NOT IN (-1, 0, 1) THEN
        RAISE EXCEPTION 'Invalid vote direction: %', p_vote_direction;
    END IF;

    -- Fetch existing vote
    SELECT vote_direction INTO v_old_vote
    FROM public.forum_post_votes
    WHERE user_id = v_user_id AND post_id = p_post_id;

    IF NOT FOUND THEN
        v_old_vote := 0;
    END IF;

    -- Toggle behavior: if clicking the same vote again, reset to 0
    IF v_old_vote = p_vote_direction THEN
        v_new_vote := 0;
    ELSE
        v_new_vote := p_vote_direction;
    END IF;

    -- Compute atomic deltas
    IF v_old_vote = 1 THEN v_delta_up := v_delta_up - 1; END IF;
    IF v_old_vote = -1 THEN v_delta_down := v_delta_down - 1; END IF;
    IF v_new_vote = 1 THEN v_delta_up := v_delta_up + 1; END IF;
    IF v_new_vote = -1 THEN v_delta_down := v_delta_down + 1; END IF;

    -- Upsert vote record
    INSERT INTO public.forum_post_votes (user_id, post_id, vote_direction, created_at)
    VALUES (v_user_id, p_post_id, v_new_vote, now())
    ON CONFLICT (user_id, post_id)
    DO UPDATE SET vote_direction = v_new_vote, created_at = now();

    -- Atomically update counts on forum_posts
    UPDATE public.forum_posts
    SET 
        upvotes = GREATEST(0, upvotes + v_delta_up),
        downvotes = GREATEST(0, downvotes + v_delta_down),
        updated_at = now()
    WHERE id = p_post_id
    RETURNING upvotes, downvotes INTO v_res_upvotes, v_res_downvotes;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Forum post % not found', p_post_id;
    END IF;

    RETURN jsonb_build_object(
        'postId', p_post_id,
        'upvotes', v_res_upvotes,
        'downvotes', v_res_downvotes,
        'userVote', v_new_vote
    );
END;
$$;

-- 3. Atomic Stored Procedure: Vote on Forum Reply
CREATE OR REPLACE FUNCTION public.vote_forum_reply_atomic(
    p_post_id UUID,
    p_reply_id UUID,
    p_vote_direction INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_old_vote INT := 0;
    v_new_vote INT;
    v_delta_up INT := 0;
    v_delta_down INT := 0;
    v_res_upvotes INT;
    v_res_downvotes INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to vote on forum replies';
    END IF;

    IF p_vote_direction NOT IN (-1, 0, 1) THEN
        RAISE EXCEPTION 'Invalid vote direction: %', p_vote_direction;
    END IF;

    -- Fetch existing vote
    SELECT vote_direction INTO v_old_vote
    FROM public.forum_reply_votes
    WHERE user_id = v_user_id AND reply_id = p_reply_id;

    IF NOT FOUND THEN
        v_old_vote := 0;
    END IF;

    -- Toggle behavior
    IF v_old_vote = p_vote_direction THEN
        v_new_vote := 0;
    ELSE
        v_new_vote := p_vote_direction;
    END IF;

    -- Compute atomic deltas
    IF v_old_vote = 1 THEN v_delta_up := v_delta_up - 1; END IF;
    IF v_old_vote = -1 THEN v_delta_down := v_delta_down - 1; END IF;
    IF v_new_vote = 1 THEN v_delta_up := v_delta_up + 1; END IF;
    IF v_new_vote = -1 THEN v_delta_down := v_delta_down + 1; END IF;

    -- Upsert vote record
    INSERT INTO public.forum_reply_votes (user_id, reply_id, post_id, vote_direction, created_at)
    VALUES (v_user_id, p_reply_id, p_post_id, v_new_vote, now())
    ON CONFLICT (user_id, reply_id)
    DO UPDATE SET vote_direction = v_new_vote, created_at = now();

    -- Atomically update counts on forum_replies
    UPDATE public.forum_replies
    SET 
        upvotes = GREATEST(0, upvotes + v_delta_up),
        downvotes = GREATEST(0, downvotes + v_delta_down)
    WHERE id = p_reply_id
    RETURNING upvotes, downvotes INTO v_res_upvotes, v_res_downvotes;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Forum reply % not found', p_reply_id;
    END IF;

    RETURN jsonb_build_object(
        'postId', p_post_id,
        'replyId', p_reply_id,
        'upvotes', v_res_upvotes,
        'downvotes', v_res_downvotes,
        'userVote', v_new_vote
    );
END;
$$;

-- 4. Full-Text Search (FTS) with GIN Index on forum_posts
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'forum_posts' 
          AND column_name = 'search_tsv'
    ) THEN
        ALTER TABLE public.forum_posts 
        ADD COLUMN search_tsv TSVECTOR 
        GENERATED ALWAYS AS (
            setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
            setweight(to_tsvector('english', coalesce(syllabus_tag, '')), 'B') ||
            setweight(to_tsvector('english', coalesce(content, '')), 'C')
        ) STORED;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_forum_posts_search_tsv 
ON public.forum_posts USING GIN(search_tsv);

-- 5. High-Performance Compound Indexes for Sorting & Keyset Queries
CREATE INDEX IF NOT EXISTS idx_forum_posts_track_created 
ON public.forum_posts(track, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forum_posts_track_trending 
ON public.forum_posts(track, upvotes DESC, replies_count DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forum_posts_is_question_created 
ON public.forum_posts(is_question, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forum_posts_author_created 
ON public.forum_posts(author_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forum_replies_post_created 
ON public.forum_replies(post_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_forum_replies_post_upvotes 
ON public.forum_replies(post_id, upvotes DESC, created_at ASC);

-- 6. Rate Limiting Protection on Creation
CREATE OR REPLACE FUNCTION public.check_forum_post_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_recent_count INT;
BEGIN
    SELECT count(*) INTO v_recent_count
    FROM public.forum_posts
    WHERE author_id = NEW.author_id
      AND created_at > now() - INTERVAL '1 minute';

    IF v_recent_count >= 10 THEN
        RAISE EXCEPTION 'Rate limit exceeded. Please wait a moment before creating another post.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_check_forum_post_rate_limit ON public.forum_posts;
CREATE TRIGGER trg_check_forum_post_rate_limit
    BEFORE INSERT ON public.forum_posts
    FOR EACH ROW EXECUTE FUNCTION public.check_forum_post_rate_limit();

-- 7. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
