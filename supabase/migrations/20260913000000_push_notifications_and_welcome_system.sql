-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 031 - Push Notifications, Key Event Triggers & Welcome System
-- Extensions: pg_net, pg_cron
-- Listeners: New User Welcome, Verified Forum Solutions, Live Study Rooms, Document Ingestion
-- ==============================================================================

-- 1. Ensure required extensions exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- 2. Enhanced handle_new_user() trigger with automated welcome notification
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_display_name TEXT;
    v_target_track TEXT;
    v_daily_target INT;
    v_retention FLOAT;
    v_avatar_url TEXT;
BEGIN
    v_display_name := COALESCE(
        NEW.raw_user_meta_data->>'display_name',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        split_part(COALESCE(NEW.email, 'scholar'), '@', 1)
    );

    v_target_track := COALESCE(NEW.raw_user_meta_data->>'target_track', 'WAEC');
    v_avatar_url := NEW.raw_user_meta_data->>'avatar_url';

    BEGIN
        v_daily_target := (NEW.raw_user_meta_data->>'daily_card_target')::int;
    EXCEPTION WHEN OTHERS THEN
        v_daily_target := 20;
    END;

    BEGIN
        v_retention := (NEW.raw_user_meta_data->>'retention_benchmark')::float;
    EXCEPTION WHEN OTHERS THEN
        v_retention := 0.85;
    END;

    -- Insert or update public.profiles
    INSERT INTO public.profiles (
        id,
        email,
        display_name,
        photo_url,
        target_track,
        daily_card_target,
        retention_benchmark,
        level,
        streak_days,
        is_onboarded,
        subscription_tier
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        v_display_name,
        v_avatar_url,
        COALESCE(v_target_track, 'WAEC'),
        COALESCE(v_daily_target, 20),
        COALESCE(v_retention, 0.85),
        1,
        0,
        false,
        'free'
    )
    ON CONFLICT (id) DO UPDATE SET
        display_name = COALESCE(EXCLUDED.display_name, public.profiles.display_name),
        photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url);

    -- Ensure initial user calibration exists
    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

    -- Ensure default notification preferences exist for user
    INSERT INTO public.notification_preferences (
        user_id,
        study_reminders,
        streak_alerts,
        exam_alerts,
        social_alerts,
        ai_ingestion_alerts
    )
    VALUES (
        NEW.id,
        true,
        true,
        true,
        true,
        true
    )
    ON CONFLICT (user_id) DO NOTHING;

    -- Insert tailored Welcome Notification into notifications inbox
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        NEW.id,
        '👋 Welcome to Kortex, ' || v_display_name || '!',
        'Your AI study companion is ready. Upload study materials or explore curated exam tracks to start mastering your courses.',
        'general',
        jsonb_build_object(
            'type', 'welcome',
            'route', '/dashboard',
            'created_at', now()
        )
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log warning but never abort user registration
    RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- Rebind trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 3. Trigger: Notify user when their forum reply is verified as the solution
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_forum_solution_verified()
RETURNS TRIGGER AS $$
DECLARE
    v_topic_title TEXT;
BEGIN
    IF NEW.is_verified_solution = true AND (OLD.is_verified_solution IS NULL OR OLD.is_verified_solution = false) THEN
        -- Get the topic title
        SELECT title INTO v_topic_title
        FROM public.forum_topics
        WHERE id = NEW.topic_id;

        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            NEW.author_id,
            '⭐ Solution Verified!',
            format('Your answer in "%s" was accepted as the verified solution! You earned +100 XP.', COALESCE(v_topic_title, 'the community forum')),
            'leaderboard',
            jsonb_build_object(
                'topicId', NEW.topic_id,
                'replyId', NEW.id,
                'route', '/community'
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_forum_solution_verified_notification ON public.forum_replies;
CREATE TRIGGER trg_forum_solution_verified_notification
    AFTER UPDATE OF is_verified_solution ON public.forum_replies
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_forum_solution_verified();

-- ==============================================================================
-- 4. Trigger: Notify peers when a live study room starts in their track/subject
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_study_room_created()
RETURNS TRIGGER AS $$
DECLARE
    r RECORD;
    v_creator_name TEXT;
BEGIN
    SELECT display_name INTO v_creator_name
    FROM public.profiles
    WHERE id = NEW.created_by;

    -- Notify active peers (limit to 25 to avoid broadcast floods)
    FOR r IN
        SELECT p.id AS user_id
        FROM public.profiles p
        JOIN public.notification_preferences np ON np.user_id = p.id
        WHERE p.id != NEW.created_by
          AND np.social_alerts = true
          AND (p.target_track = NEW.category OR NEW.category IS NULL)
        LIMIT 25
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            r.user_id,
            '👥 Live Study Room: ' || NEW.title,
            format('%s started a live study session in %s. Join your peers now!', COALESCE(v_creator_name, 'A student'), NEW.subject),
            'room_invite',
            jsonb_build_object(
                'roomId', NEW.id,
                'subject', NEW.subject,
                'route', '/study-room'
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_study_room_created_notification ON public.study_rooms;
CREATE TRIGGER trg_study_room_created_notification
    AFTER INSERT ON public.study_rooms
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_study_room_created();

-- ==============================================================================
-- 5. Stored Procedure: Send Tailored Notification RPC
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.send_tailored_notification(
    p_target_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_category TEXT DEFAULT 'general',
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_notif_id UUID;
    v_pref_allowed BOOLEAN := true;
BEGIN
    -- Check user notification preferences
    IF p_category = 'spaced_repetition' THEN
        SELECT study_reminders INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'streak_protection' THEN
        SELECT streak_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'exam_countdown' THEN
        SELECT exam_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'room_invite' OR p_category = 'social_alerts' THEN
        SELECT social_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'ai_ingestion' THEN
        SELECT ai_ingestion_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    END IF;

    IF v_pref_allowed IS FALSE THEN
        RETURN jsonb_build_object('success', false, 'reason', 'User opted out of this category');
    END IF;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        p_target_user_id,
        p_title,
        p_body,
        p_category,
        p_data
    )
    RETURNING id INTO v_notif_id;

    RETURN jsonb_build_object(
        'success', true,
        'notificationId', v_notif_id,
        'createdAt', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.send_tailored_notification(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;

-- ==============================================================================
-- 6. Trigger: Automatically notify user when an exam is scheduled/calibrated
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.trg_notify_on_exam_event_created()
RETURNS TRIGGER AS $$
DECLARE
    v_days_left INT;
BEGIN
    v_days_left := (NEW.target_date - CURRENT_DATE)::INT;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        NEW.user_id,
        '🎯 Exam Calibrated: ' || NEW.exam_name,
        CASE 
            WHEN v_days_left > 0 THEN format('%s days left. Daily target: %s cards to stay on track!', v_days_left, NEW.daily_target)
            ELSE 'Your exam is scheduled for today! Good luck!'
        END,
        'exam_countdown',
        jsonb_build_object(
            'examId', NEW.id,
            'examName', NEW.exam_name,
            'daysRemaining', v_days_left,
            'dailyTarget', NEW.daily_target,
            'route', '/planner'
        )
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_exam_event_created_notification ON public.exam_events;
CREATE TRIGGER trg_exam_event_created_notification
    AFTER INSERT ON public.exam_events
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_exam_event_created();

-- ==============================================================================
-- 7. Automated Welcome Push Dispatch on Device Token Registration
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_fcm_token TEXT,
    p_platform TEXT,
    p_device_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_device_id UUID;
    v_display_name TEXT;
    v_welcome_notif RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to register device token';
    END IF;

    -- Upsert the token for this user
    INSERT INTO public.user_devices (user_id, fcm_token, platform, device_name, is_active, updated_at)
    VALUES (v_user_id, p_fcm_token, p_platform, p_device_name, true, now())
    ON CONFLICT (fcm_token) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        platform = EXCLUDED.platform,
        device_name = COALESCE(EXCLUDED.device_name, public.user_devices.device_name),
        is_active = true,
        updated_at = now()
    RETURNING id INTO v_device_id;

    -- Ensure default notification preferences exist for user
    INSERT INTO public.notification_preferences (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Check if a welcome notification exists that has not been pushed yet
    SELECT id, title, body, category, data INTO v_welcome_notif
    FROM public.notifications
    WHERE user_id = v_user_id 
      AND (data->>'type') = 'welcome'
      AND (data->>'pushed') IS NULL
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_welcome_notif.id IS NOT NULL THEN
        -- Mark as pushed to avoid duplicate deliveries
        UPDATE public.notifications
        SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{pushed}', 'true'::jsonb)
        WHERE id = v_welcome_notif.id;

        -- Dispatch through Edge Function via pg_net if available
        IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
            BEGIN
                PERFORM net.http_post(
                    url := 'http://localhost:54321/functions/v1/send-push-notification',
                    headers := jsonb_build_object('Content-Type', 'application/json'),
                    body := jsonb_build_object(
                        'userId', v_user_id,
                        'title', v_welcome_notif.title,
                        'body', v_welcome_notif.body,
                        'category', v_welcome_notif.category,
                        'data', v_welcome_notif.data
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                -- Non-blocking pg_net dispatch error
                RAISE WARNING 'pg_net welcome push dispatch failed: %', SQLERRM;
            END;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'deviceId', v_device_id,
        'registeredAt', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT, TEXT) TO authenticated, service_role;

