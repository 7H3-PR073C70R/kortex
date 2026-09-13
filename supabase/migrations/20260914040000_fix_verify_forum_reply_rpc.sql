-- Migration: Fix verify_forum_reply RPC schema reference
-- Resolves Postgres error 42P01: relation "public.forum_topics" does not exist

CREATE OR REPLACE FUNCTION public.verify_forum_reply(
    p_post_id UUID,
    p_reply_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_post RECORD;
    v_reply RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Fetch post from forum_posts (not legacy forum_topics)
    SELECT * INTO v_post FROM public.forum_posts WHERE id = p_post_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Post not found';
    END IF;

    -- Only author can mark verified solution
    IF v_post.author_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the post author can verify a solution';
    END IF;

    -- Fetch reply from forum_replies
    SELECT * INTO v_reply FROM public.forum_replies WHERE id = p_reply_id AND post_id = p_post_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reply not found';
    END IF;

    -- Unmark any previously verified replies for this post
    UPDATE public.forum_replies
    SET is_verified_solution = false
    WHERE post_id = p_post_id;

    -- Mark this reply as verified
    UPDATE public.forum_replies
    SET is_verified_solution = true
    WHERE id = p_reply_id;

    -- Update post status
    UPDATE public.forum_posts
    SET is_verified_solution = true,
        verified_by = v_user_id,
        updated_at = now()
    WHERE id = p_post_id;

    -- Award +100 XP to solver
    UPDATE public.profiles
    SET xp_points = xp_points + 100
    WHERE id = v_reply.author_id;

    UPDATE public.leaderboards
    SET weekly_xp = weekly_xp + 100,
        updated_at = now()
    WHERE user_id = v_reply.author_id;

    RETURN jsonb_build_object(
        'success', true,
        'post_id', p_post_id,
        'verified_reply_id', p_reply_id,
        'solver_id', v_reply.author_id,
        'xp_awarded', 100
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_forum_reply(UUID, UUID) TO authenticated, service_role, anon;
