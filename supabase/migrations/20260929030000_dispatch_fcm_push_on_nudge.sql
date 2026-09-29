-- Migration: 20260929030000_dispatch_fcm_push_on_nudge.sql
-- Dispatches FCM push notifications when pod members are nudged using pg_net and send-push-notification edge function.

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
    v_notif_title TEXT;
    v_notif_body TEXT;
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

    v_notif_title := format('⚡ Focus Nudge from %s!', v_sender_name);
    v_notif_body := format('%s nudged your "%s" pod! Time to hit your weekly focus targets.', v_sender_name, v_circle.name);

    -- Insert notifications for all other members in the pod & dispatch FCM push notifications
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
            v_notif_title,
            v_notif_body,
            'room_invite',
            jsonb_build_object(
                'circle_id', p_circle_id,
                'circle_name', v_circle.name,
                'sender_id', v_sender_id,
                'sender_name', v_sender_name,
                'route', '/community'
            )
        );

        -- Dispatch FCM push notification via send-push-notification edge function using pg_net
        IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
            BEGIN
                PERFORM net.http_post(
                    url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/send-push-notification',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer ' || COALESCE(
                            current_setting('request.jwt.claim.sub', true),
                            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpemFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTIwMTQsImV4cCI6MjA3MTk2ODAxNH0.eO6nK0j1x1k0d0i0j0k0l0m0n0o0p0q0r0s0t0u0v0w'
                        )
                    ),
                    body := jsonb_build_object(
                        'userId', v_member.user_id,
                        'title', v_notif_title,
                        'body', v_notif_body,
                        'category', 'room_invite',
                        'data', jsonb_build_object(
                            'circle_id', p_circle_id,
                            'circle_name', v_circle.name,
                            'sender_id', v_sender_id,
                            'sender_name', v_sender_name,
                            'route', '/community'
                        )
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'FCM push dispatch failed for user %: %', v_member.user_id, SQLERRM;
            END;
        END IF;

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
