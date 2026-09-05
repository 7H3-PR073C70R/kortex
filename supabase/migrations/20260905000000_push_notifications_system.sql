-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 024 - Phone Push Notifications & Notification System
-- ==============================================================================

-- 1. Create user_devices table for storing FCM registration tokens
CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'macos', 'web', 'windows')),
    device_name TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_device_token UNIQUE (user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_active_token ON public.user_devices(user_id, is_active);

-- Enable RLS on user_devices
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own devices" ON public.user_devices;
CREATE POLICY "Users can view own devices"
    ON public.user_devices FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own devices" ON public.user_devices;
CREATE POLICY "Users can insert own devices"
    ON public.user_devices FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own devices" ON public.user_devices;
CREATE POLICY "Users can update own devices"
    ON public.user_devices FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own devices" ON public.user_devices;
CREATE POLICY "Users can delete own devices"
    ON public.user_devices FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages all user devices" ON public.user_devices;
CREATE POLICY "Service role manages all user devices"
    ON public.user_devices FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Create notification_preferences table
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    study_reminders BOOLEAN NOT NULL DEFAULT true,
    streak_alerts BOOLEAN NOT NULL DEFAULT true,
    exam_alerts BOOLEAN NOT NULL DEFAULT true,
    social_alerts BOOLEAN NOT NULL DEFAULT true,
    ai_ingestion_alerts BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_start TIME DEFAULT '22:00:00',
    quiet_hours_end TIME DEFAULT '07:00:00',
    preferred_study_time TIME DEFAULT '20:00:00',
    timezone TEXT NOT NULL DEFAULT 'UTC',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can view own notification preferences"
    ON public.notification_preferences FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can upsert own notification preferences" ON public.notification_preferences;
CREATE POLICY "Users can upsert own notification preferences"
    ON public.notification_preferences FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages all notification preferences" ON public.notification_preferences;
CREATE POLICY "Service role manages all notification preferences"
    ON public.notification_preferences FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 3. Create in-app notifications inbox table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'spaced_repetition',
        'streak_protection',
        'exam_countdown',
        'memory_decay',
        'ai_ingestion',
        'room_invite',
        'leaderboard',
        'deck_cloned',
        'security',
        'general'
    )),
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
    ON public.notifications FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications read status" ON public.notifications;
CREATE POLICY "Users can update own notifications read status"
    ON public.notifications FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages all notifications" ON public.notifications;
CREATE POLICY "Service role manages all notifications"
    ON public.notifications FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 4. Stored Procedure: Register Device Token
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_fcm_token TEXT,
    p_platform TEXT,
    p_device_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_device_id UUID;
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

    RETURN jsonb_build_object(
        'success', true,
        'deviceId', v_device_id,
        'registeredAt', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- 5. Trigger: Unread notification count sync on user_analytics
CREATE OR REPLACE FUNCTION public.sync_unread_notifications_count()
RETURNS TRIGGER AS $$
DECLARE
    v_target_user_id UUID;
    v_count INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_target_user_id := NEW.user_id;
    ELSIF TG_OP = 'UPDATE' THEN
        v_target_user_id := NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        v_target_user_id := OLD.user_id;
    END IF;

    SELECT COUNT(*)::INT INTO v_count
    FROM public.notifications
    WHERE user_id = v_target_user_id AND read = false;

    UPDATE public.user_analytics
    SET unread_notification_count = v_count,
        updated_at = now()
    WHERE user_id = v_target_user_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_unread_notifications ON public.notifications;
CREATE TRIGGER trg_sync_unread_notifications
    AFTER INSERT OR UPDATE OF read OR DELETE ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.sync_unread_notifications_count();

-- 6. Trigger: Notify user when document ingestion completes
CREATE OR REPLACE FUNCTION public.trg_notify_on_document_ingestion_completed()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when transitioning into 'completed'
    IF NEW.processing_status = 'completed' AND (OLD.processing_status IS NULL OR OLD.processing_status != 'completed') THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            NEW.user_id,
            '✨ Your flashcards are ready!',
            format('Syllabot synthesized flashcards from "%s". Tap to begin studying.', NEW.filename),
            'ai_ingestion',
            jsonb_build_object(
                'documentId', NEW.id,
                'filename', NEW.filename,
                'route', '/deck-detail'
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_document_completed_notification ON public.documents;
CREATE TRIGGER trg_document_completed_notification
    AFTER UPDATE OF processing_status ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_document_ingestion_completed();

-- 7. Trigger: Notify deck author when their shared deck is downloaded/cloned
CREATE OR REPLACE FUNCTION public.trg_notify_on_shared_deck_cloned()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.downloads_count > OLD.downloads_count THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            NEW.owner_id,
            '⭐ Your deck is helping others!',
            format('%s students have now cloned your deck "%s". Keep up the great work!', NEW.downloads_count, NEW.title),
            'deck_cloned',
            jsonb_build_object(
                'deckId', NEW.id,
                'downloadsCount', NEW.downloads_count,
                'route', '/deck-detail'
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_shared_deck_cloned_notification ON public.shared_decks;
CREATE TRIGGER trg_shared_deck_cloned_notification
    AFTER UPDATE OF downloads_count ON public.shared_decks
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_shared_deck_cloned();

-- 8. Scheduled Check: Daily Study Streak Protection
CREATE OR REPLACE FUNCTION public.check_daily_streaks_and_notify()
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    -- Find users with active streak >= 2 who have NOT studied today
    FOR r IN
        SELECT 
            p.id AS user_id,
            p.streak_days,
            p.display_name
        FROM public.profiles p
        JOIN public.notification_preferences np ON np.user_id = p.id
        WHERE p.streak_days >= 2
          AND np.streak_alerts = true
          AND p.id NOT IN (
              SELECT DISTINCT user_id 
              FROM public.heatmap_activity 
              WHERE activity_date = CURRENT_DATE 
                AND (cards_reviewed > 0 OR minutes_studied > 0)
          )
    LOOP
        -- Avoid spamming if a streak warning was already sent today
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
            WHERE user_id = r.user_id
              AND category = 'streak_protection'
              AND created_at >= CURRENT_DATE::timestamptz
        ) THEN
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                category,
                data
            ) VALUES (
                r.user_id,
                '🔥 Protect your study streak!',
                format('You have a %s-day streak at risk today! Complete a quick 3-minute review to keep it alive.', r.streak_days),
                'streak_protection',
                jsonb_build_object(
                    'streakDays', r.streak_days,
                    'route', '/study-session'
                )
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 9. Scheduled Check: Spaced Repetition Due Queue
CREATE OR REPLACE FUNCTION public.check_spaced_repetition_due_and_notify()
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    -- Batch review due alerts by deck and user
    FOR r IN
        SELECT 
            f.user_id,
            d.title AS deck_title,
            d.id AS deck_id,
            COUNT(*)::INT AS due_count
        FROM public.flashcards f
        JOIN public.decks d ON d.id = f.deck_id
        JOIN public.notification_preferences np ON np.user_id = f.user_id
        WHERE f.next_due_date <= now()
          AND np.study_reminders = true
        GROUP BY f.user_id, d.title, d.id
        HAVING COUNT(*) >= 5
    LOOP
        -- Avoid duplicate due alerts for the same deck on the same day
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
            WHERE user_id = r.user_id
              AND category = 'spaced_repetition'
              AND (data->>'deckId')::uuid = r.deck_id
              AND created_at >= CURRENT_DATE::timestamptz
        ) THEN
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                category,
                data
            ) VALUES (
                r.user_id,
                format('🧠 %s cards due for review in %s', r.due_count, r.deck_title),
                'Review now to reinforce your memory retention before the decay curve takes over.',
                'spaced_repetition',
                jsonb_build_object(
                    'deckId', r.deck_id,
                    'deckTitle', r.deck_title,
                    'dueCount', r.due_count,
                    'route', '/study-session'
                )
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10. Scheduled Check: Exam Countdown Milestones
CREATE OR REPLACE FUNCTION public.check_exam_milestones_and_notify()
RETURNS void AS $$
DECLARE
    r RECORD;
    v_days_left INT;
BEGIN
    FOR r IN
        SELECT 
            e.id AS exam_id,
            e.user_id,
            e.exam_name,
            e.target_date,
            e.daily_target,
            (e.target_date - CURRENT_DATE)::INT AS days_remaining
        FROM public.exam_events e
        JOIN public.notification_preferences np ON np.user_id = e.user_id
        WHERE e.target_date >= CURRENT_DATE
          AND (e.target_date - CURRENT_DATE)::INT IN (30, 14, 7, 3, 1)
          AND np.exam_alerts = true
    LOOP
        v_days_left := r.days_remaining;

        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
            WHERE user_id = r.user_id
              AND category = 'exam_countdown'
              AND (data->>'examId')::uuid = r.exam_id
              AND created_at >= CURRENT_DATE::timestamptz
        ) THEN
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                category,
                data
            ) VALUES (
                r.user_id,
                format('⏳ %s %s until %s!', v_days_left, CASE WHEN v_days_left = 1 THEN 'day' ELSE 'days' END, r.exam_name),
                format('Stay on track to hit your mastery goal. Today''s recommended target is %s cards.', r.daily_target),
                'exam_countdown',
                jsonb_build_object(
                    'examId', r.exam_id,
                    'daysRemaining', v_days_left,
                    'dailyTarget', r.daily_target,
                    'route', '/planner'
                )
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 11. Register pg_cron jobs if available
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Daily Streak Loss Warning: 19:30 UTC daily (30 19 * * *)
        PERFORM cron.unschedule('check-daily-streaks-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-daily-streaks-and-notify');

        PERFORM cron.schedule(
            'check-daily-streaks-and-notify',
            '30 19 * * *',
            'SELECT public.check_daily_streaks_and_notify();'
        );

        -- Spaced Repetition Due Queue: 08:30 UTC daily (30 8 * * *)
        PERFORM cron.unschedule('check-spaced-repetition-due-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-spaced-repetition-due-and-notify');

        PERFORM cron.schedule(
            'check-spaced-repetition-due-and-notify',
            '30 8 * * *',
            'SELECT public.check_spaced_repetition_due_and_notify();'
        );

        -- Exam Countdown Milestones: 09:00 UTC daily (0 9 * * *)
        PERFORM cron.unschedule('check-exam-milestones-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-exam-milestones-and-notify');

        PERFORM cron.schedule(
            'check-exam-milestones-and-notify',
            '0 9 * * *',
            'SELECT public.check_exam_milestones_and_notify();'
        );
    END IF;
END $$;
