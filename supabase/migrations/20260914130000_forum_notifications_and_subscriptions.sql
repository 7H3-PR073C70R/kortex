-- Migration: 20260914130000_forum_notifications_and_subscriptions.sql
-- Description: Add forum_post_subscriptions table, toggle RPC, and push notification triggers for thread replies

-- 1. Create forum_post_subscriptions table
CREATE TABLE IF NOT EXISTS public.forum_post_subscriptions (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_post_subs_post_id ON public.forum_post_subscriptions(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_post_subs_user_id ON public.forum_post_subscriptions(user_id);

-- Enable RLS
ALTER TABLE public.forum_post_subscriptions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their forum post subscriptions" ON public.forum_post_subscriptions;
    DROP POLICY IF EXISTS "Users can insert their forum post subscriptions" ON public.forum_post_subscriptions;
    DROP POLICY IF EXISTS "Users can delete their forum post subscriptions" ON public.forum_post_subscriptions;

    CREATE POLICY "Users can view their forum post subscriptions"
        ON public.forum_post_subscriptions FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their forum post subscriptions"
        ON public.forum_post_subscriptions FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can delete their forum post subscriptions"
        ON public.forum_post_subscriptions FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- 2. Toggle subscription RPC
CREATE OR REPLACE FUNCTION public.toggle_forum_post_subscription(p_post_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_exists BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to subscribe to forum threads';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.forum_post_subscriptions 
        WHERE user_id = v_user_id AND post_id = p_post_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.forum_post_subscriptions 
        WHERE user_id = v_user_id AND post_id = p_post_id;
        RETURN false;
    ELSE
        INSERT INTO public.forum_post_subscriptions (user_id, post_id)
        VALUES (v_user_id, p_post_id)
        ON CONFLICT DO NOTHING;
        RETURN true;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Check subscription status RPC
CREATE OR REPLACE FUNCTION public.is_forum_post_subscribed(p_post_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS(
        SELECT 1 FROM public.forum_post_subscriptions 
        WHERE user_id = v_user_id AND post_id = p_post_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. Trigger: Send in-app & push notification when a reply is posted
CREATE OR REPLACE FUNCTION public.trg_notify_on_forum_reply_created()
RETURNS TRIGGER AS $$
DECLARE
    v_post_title TEXT;
    v_post_author_id UUID;
    v_parent_author_id UUID;
    r RECORD;
BEGIN
    -- Fetch post details
    SELECT title, author_id INTO v_post_title, v_post_author_id
    FROM public.forum_posts
    WHERE id = NEW.post_id;

    -- If replying to another comment, fetch parent comment author
    IF NEW.parent_reply_id IS NOT NULL THEN
        SELECT author_id INTO v_parent_author_id
        FROM public.forum_replies
        WHERE id = NEW.parent_reply_id;
    END IF;

    -- Collect all recipients to notify
    FOR r IN
        SELECT DISTINCT u.user_id
        FROM (
            -- 1. Post author
            SELECT v_post_author_id AS user_id WHERE v_post_author_id IS NOT NULL
            UNION
            -- 2. Subscribed users
            SELECT user_id FROM public.forum_post_subscriptions WHERE post_id = NEW.post_id
            UNION
            -- 3. Parent reply author
            SELECT v_parent_author_id AS user_id WHERE v_parent_author_id IS NOT NULL
        ) u
        JOIN public.notification_preferences np ON np.user_id = u.user_id
        WHERE u.user_id != NEW.author_id
          AND np.forum_activity = true
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            r.user_id,
            CASE 
                WHEN r.user_id = v_parent_author_id THEN '💬 ' || COALESCE(NEW.author_name, 'A scholar') || ' replied to your comment'
                ELSE '💬 New reply in ' || COALESCE(v_post_title, 'Discussion')
            END,
            COALESCE(substring(NEW.content from 1 for 120), 'Check the latest discussion.'),
            'forum_reply',
            jsonb_build_object(
                'postId', NEW.post_id,
                'replyId', NEW.id,
                'parentReplyId', NEW.parent_reply_id,
                'route', '/forum/thread'
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_forum_reply_created_notification ON public.forum_replies;
CREATE TRIGGER trg_forum_reply_created_notification
    AFTER INSERT ON public.forum_replies
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_forum_reply_created();

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
