
ALTER TABLE IF EXISTS public.notification_preferences
ADD COLUMN IF NOT EXISTS forum_activity BOOLEAN NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.trg_notify_on_forum_reply_created()
RETURNS TRIGGER AS $$
DECLARE
    v_post_title TEXT;
    v_post_author_id UUID;
    v_parent_author_id UUID;
    r RECORD;
BEGIN
    SELECT title, author_id INTO v_post_title, v_post_author_id
    FROM public.forum_posts
    WHERE id = NEW.post_id;

    IF NEW.parent_reply_id IS NOT NULL THEN
        SELECT author_id INTO v_parent_author_id
        FROM public.forum_replies
        WHERE id = NEW.parent_reply_id;
    END IF;

    FOR r IN
        SELECT DISTINCT u.user_id
        FROM (
            SELECT v_post_author_id AS user_id WHERE v_post_author_id IS NOT NULL
            UNION
            SELECT user_id FROM public.forum_post_subscriptions WHERE post_id = NEW.post_id
            UNION
            SELECT v_parent_author_id AS user_id WHERE v_parent_author_id IS NOT NULL
        ) u
        LEFT JOIN public.notification_preferences np ON np.user_id = u.user_id
        WHERE (NEW.author_id IS NULL OR u.user_id != NEW.author_id)
          AND COALESCE(np.forum_activity, np.social_alerts, true) = true
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

NOTIFY pgrst, 'reload schema';
