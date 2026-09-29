-- Migration: 20260929010000_fix_notifications_category_check.sql
-- Fixes notifications_category_check constraint on public.notifications table by expanding allowed categories including 'social_alerts', 'forum_reply', etc.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_category_check' 
          AND table_name = 'notifications'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_category_check;
    END IF;
END $$;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_category_check
CHECK (category IN (
    'spaced_repetition',
    'streak_protection',
    'exam_countdown',
    'memory_decay',
    'ai_ingestion',
    'room_invite',
    'leaderboard',
    'deck_cloned',
    'security',
    'general',
    'social_alerts',
    'forum_reply',
    'social',
    'community',
    'circle',
    'forum',
    'quiz_duel_challenge',
    'quiz_duel_result',
    'streak_milestone',
    'daily_streak_reminder',
    'exam_milestones',
    'exam',
    'planner',
    'welcome'
));

-- Re-apply updated nudge_study_circle_rpc to ensure clean insertion
CREATE OR REPLACE FUNCTION public.nudge_study_circle_rpc(
    p_circle_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_id UUID;
    v_sender_name TEXT;
    v_circle RECORD;
    v_member RECORD;
    v_nudged_count INT := 0;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Retrieve sender display name
    SELECT COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', email, 'A scholar')
    INTO v_sender_name
    FROM auth.users
    WHERE id = v_sender_id;

    -- Retrieve circle info
    SELECT * INTO v_circle
    FROM study_circles
    WHERE id = p_circle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study Circle not found';
    END IF;

    -- Verify sender is a member of this circle (if members exist)
    IF EXISTS (
        SELECT 1 FROM study_circle_members WHERE circle_id = p_circle_id
    ) AND NOT EXISTS (
        SELECT 1 FROM study_circle_members
        WHERE circle_id = p_circle_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION 'You must be a member of this circle to nudge your pod';
    END IF;

    -- Insert notifications for all other members in the pod
    FOR v_member IN
        SELECT user_id FROM study_circle_members
        WHERE circle_id = p_circle_id AND user_id <> v_sender_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            v_member.user_id,
            format('⚡ Focus Nudge from %s!', v_sender_name),
            format('%s nudged your "%s" pod! Time to hit your weekly focus targets.', v_sender_name, v_circle.name),
            'room_invite',
            jsonb_build_object(
                'circle_id', p_circle_id,
                'circle_name', v_circle.name,
                'sender_id', v_sender_id,
                'sender_name', v_sender_name
            )
        );
        v_nudged_count := v_nudged_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'nudged_members_count', v_nudged_count,
        'circle_name', v_circle.name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.nudge_study_circle_rpc(UUID) TO authenticated, anon, service_role;
NOTIFY pgrst, 'reload schema';
