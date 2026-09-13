-- Migration: 20260915000000_forum_phase2_scalability.sql
-- Description: Phase 2 Forum Scalability: Keyset cursor-based pagination, Socratic AI hint caching, hierarchical thread-tree RPC, and high-concurrency indexes.

-- 1. Add Socratic AI hint persistent caching columns on forum_posts
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'forum_posts'
          AND column_name = 'socratic_hint'
    ) THEN
        ALTER TABLE public.forum_posts
        ADD COLUMN socratic_hint TEXT,
        ADD COLUMN socratic_hint_generated_at TIMESTAMPTZ;
    END IF;
END $$;

-- 2. Create Keyset-Optimized Compound B-Tree Indexes
CREATE INDEX IF NOT EXISTS idx_forum_posts_keyset_track_created
ON public.forum_posts(track, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_forum_posts_keyset_all_created
ON public.forum_posts(created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_forum_posts_keyset_trending
ON public.forum_posts(track, upvotes DESC, replies_count DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_forum_replies_keyset_parent
ON public.forum_replies(post_id, parent_reply_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_forum_replies_keyset_top
ON public.forum_replies(post_id, upvotes DESC, created_at ASC, id ASC);

-- 3. High-Performance Keyset Pagination Stored Procedure
CREATE OR REPLACE FUNCTION public.fetch_forum_posts_keyset(
    p_track TEXT DEFAULT NULL,
    p_cursor_created_at TIMESTAMPTZ DEFAULT NULL,
    p_cursor_id UUID DEFAULT NULL,
    p_limit INT DEFAULT 15,
    p_sort TEXT DEFAULT 'latest',
    p_search_query TEXT DEFAULT NULL,
    p_questions_only BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
BEGIN
    v_user_id := auth.uid();

    WITH filtered_posts AS (
        SELECT
            p.id,
            p.author_id,
            p.author_name,
            p.author_avatar,
            p.track,
            p.title,
            p.content,
            p.latex_content,
            p.is_question,
            p.is_verified_solution,
            p.syllabus_tag,
            p.upvotes,
            p.downvotes,
            p.replies_count,
            p.tags,
            p.media_urls,
            p.voice_note_url,
            p.voice_note_duration_seconds,
            p.socratic_hint,
            p.socratic_hint_generated_at,
            p.created_at,
            COALESCE(pv.vote_direction, 0) AS user_vote,
            EXISTS(
                SELECT 1 FROM public.forum_post_subscriptions fps 
                WHERE fps.post_id = p.id AND fps.user_id = v_user_id
            ) AS is_subscribed
        FROM public.forum_posts p
        LEFT JOIN public.forum_post_votes pv 
            ON pv.post_id = p.id AND pv.user_id = v_user_id
        WHERE
            -- Track filter
            (p_track IS NULL OR p_track = '' OR p_track = 'All' OR p.track = p_track)
            -- Questions only filter
            AND (NOT p_questions_only OR p.is_question = TRUE)
            -- Full text search query
            AND (
                p_search_query IS NULL OR trim(p_search_query) = '' OR
                p.search_tsv @@ websearch_to_tsquery('english', p_search_query) OR
                p.title ILIKE '%' || p_search_query || '%' OR
                p.content ILIKE '%' || p_search_query || '%'
            )
            -- Keyset Cursor Condition
            AND (
                p_cursor_created_at IS NULL OR
                (p.created_at < p_cursor_created_at) OR
                (p.created_at = p_cursor_created_at AND (p_cursor_id IS NULL OR p.id < p_cursor_id))
            )
        ORDER BY
            CASE WHEN p_sort = 'trending' THEN p.upvotes END DESC NULLS LAST,
            CASE WHEN p_sort = 'trending' THEN p.replies_count END DESC NULLS LAST,
            p.created_at DESC,
            p.id DESC
        LIMIT LEAST(p_limit, 50)
    )
    SELECT coalesce(jsonb_agg(to_jsonb(fp)), '[]'::jsonb)
    INTO v_result
    FROM filtered_posts fp;

    RETURN v_result;
END;
$$;

-- 4. Hierarchical Thread Tree RPC for Single-Roundtrip Thread Loading
CREATE OR REPLACE FUNCTION public.fetch_forum_thread_tree(
    p_post_id UUID,
    p_limit INT DEFAULT 20,
    p_sub_reply_limit INT DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_post JSONB;
    v_replies JSONB;
BEGIN
    v_user_id := auth.uid();

    -- 1. Fetch Post with User State
    SELECT to_jsonb(p) || jsonb_build_object(
        'userVote', COALESCE(pv.vote_direction, 0),
        'isSubscribed', EXISTS(
            SELECT 1 FROM public.forum_post_subscriptions fps 
            WHERE fps.post_id = p.id AND fps.user_id = v_user_id
        )
    )
    INTO v_post
    FROM public.forum_posts p
    LEFT JOIN public.forum_post_votes pv 
        ON pv.post_id = p.id AND pv.user_id = v_user_id
    WHERE p.id = p_post_id;

    IF v_post IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Fetch Top-Level Replies with immediate sub-replies pre-nested
    WITH top_replies AS (
        SELECT 
            r.id,
            r.post_id,
            r.parent_reply_id,
            r.author_id,
            r.author_name,
            r.author_avatar,
            r.content,
            r.latex_content,
            r.is_verified_solution,
            r.upvotes,
            r.downvotes,
            r.replies_count,
            r.media_urls,
            r.voice_note_url,
            r.voice_note_duration_seconds,
            r.created_at,
            COALESCE(rv.vote_direction, 0) AS user_vote
        FROM public.forum_replies r
        LEFT JOIN public.forum_reply_votes rv
            ON rv.reply_id = r.id AND rv.user_id = v_user_id
        WHERE r.post_id = p_post_id AND (r.parent_reply_id IS NULL OR r.parent_reply_id = '')
        ORDER BY r.upvotes DESC, r.created_at ASC
        LIMIT LEAST(p_limit, 50)
    ),
    ranked_sub_replies AS (
        SELECT 
            sr.id,
            sr.post_id,
            sr.parent_reply_id,
            sr.author_id,
            sr.author_name,
            sr.author_avatar,
            sr.content,
            sr.latex_content,
            sr.is_verified_solution,
            sr.upvotes,
            sr.downvotes,
            sr.replies_count,
            sr.media_urls,
            sr.voice_note_url,
            sr.voice_note_duration_seconds,
            sr.created_at,
            COALESCE(srv.vote_direction, 0) AS user_vote,
            ROW_NUMBER() OVER (PARTITION BY sr.parent_reply_id ORDER BY sr.created_at ASC) as sub_rank
        FROM public.forum_replies sr
        LEFT JOIN public.forum_reply_votes srv
            ON srv.reply_id = sr.id AND srv.user_id = v_user_id
        WHERE sr.post_id = p_post_id 
          AND sr.parent_reply_id IN (SELECT id::text FROM top_replies)
    ),
    aggregated_sub_replies AS (
        SELECT 
            parent_reply_id,
            jsonb_agg(to_jsonb(rsr) - 'sub_rank') AS sub_replies
        FROM ranked_sub_replies rsr
        WHERE sub_rank <= p_sub_reply_limit
        GROUP BY parent_reply_id
    )
    SELECT coalesce(
        jsonb_agg(
            to_jsonb(tr) || jsonb_build_object(
                'subReplies', COALESCE(asr.sub_replies, '[]'::jsonb)
            )
        ), 
        '[]'::jsonb
    )
    INTO v_replies
    FROM top_replies tr
    LEFT JOIN aggregated_sub_replies asr ON asr.parent_reply_id = tr.id::text;

    RETURN jsonb_build_object(
        'post', v_post,
        'replies', v_replies
    );
END;
$$;

-- 5. Stored Procedure to Persist Socratic Hint
CREATE OR REPLACE FUNCTION public.save_forum_socratic_hint(
    p_post_id UUID,
    p_hint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.forum_posts
    SET 
        socratic_hint = p_hint,
        socratic_hint_generated_at = now()
    WHERE id = p_post_id;

    RETURN jsonb_build_object(
        'postId', p_post_id,
        'success', FOUND
    );
END;
$$;

-- 6. Grant Permissions
GRANT EXECUTE ON FUNCTION public.fetch_forum_posts_keyset TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fetch_forum_thread_tree TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.save_forum_socratic_hint TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
