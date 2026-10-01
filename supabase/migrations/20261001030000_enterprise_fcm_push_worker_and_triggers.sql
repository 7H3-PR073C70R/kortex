-- Migration: 20261001030000_enterprise_fcm_push_worker_and_triggers.sql
-- Description: Establishes universal server-side FCM push notification dispatch,
-- transactional outbox queueing, quiz duel triggers, optimized study circle nudges,
-- and automated 24/7 background worker scheduling.

-- 1. Ensure notification preferences has all required alert category columns
ALTER TABLE IF EXISTS public.notification_preferences
ADD COLUMN IF NOT EXISTS duel_alerts BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS forum_activity BOOLEAN NOT NULL DEFAULT true;

-- 2. Update notifications category check constraint to include all system and feature categories
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
    'quiz_duel',
    'quiz_duel_challenge',
    'quiz_duel_result',
    'streak_milestone',
    'daily_streak_reminder',
    'exam_milestones',
    'exam',
    'planner',
    'welcome',
    'subscription',
    'subscription_activated',
    'subscription_expiry'
));

-- 3. Replace direct fragile pg_net trigger on notifications with Universal Outbox Enqueue Trigger
-- Any notification inserted into public.notifications is reliably queued for FCM push dispatch.
DROP TRIGGER IF EXISTS trg_universal_fcm_push ON public.notifications;

CREATE OR REPLACE FUNCTION public.trg_enqueue_notification_to_outbox()
RETURNS TRIGGER AS $$
DECLARE
    v_anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpemFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTIwMTQsImV4cCI6MjA3MTk2ODAxNH0.eO6nK0j1x1k0d0i0j0k0l0m0n0o0p0q0r0s0t0u0v0w';
BEGIN
    -- Skip if already marked as pushed or flagged as skip_push
    IF (NEW.data->>'pushed') = 'true' OR (NEW.data->>'skip_push') = 'true' THEN
        RETURN NEW;
    END IF;

    -- Enqueue into notification_outbox for worker to deliver via FCM
    INSERT INTO public.notification_outbox (
        user_id,
        notification_type,
        title,
        body,
        data,
        status,
        scheduled_for
    ) VALUES (
        NEW.user_id,
        NEW.category,
        NEW.title,
        NEW.body,
        NEW.data || jsonb_build_object('notification_id', NEW.id),
        'pending',
        now()
    );

    -- Immediately trigger background worker if pg_net is available for sub-second delivery
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
        BEGIN
            PERFORM net.http_post(
                url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/trigger-notifications',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_anon_key,
                    'X-Server-Trigger', 'kortex-internal-worker'
                ),
                body := jsonb_build_object(
                    'action', 'process_outbox',
                    'batchSize', 25
                )
            );
        EXCEPTION WHEN OTHERS THEN
            -- Cron worker will still process pending queue on schedule
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_enqueue_notification_to_outbox ON public.notifications;
CREATE TRIGGER trg_enqueue_notification_to_outbox
    AFTER INSERT ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.trg_enqueue_notification_to_outbox();

-- 4. Quiz Duel Challenge Trigger
-- Fires when a user initiates a duel against an opponent (player2_id is set).
CREATE OR REPLACE FUNCTION public.trg_notify_on_quiz_duel_created()
RETURNS TRIGGER AS $$
DECLARE
    v_p1_name TEXT;
    v_pref_allowed BOOLEAN := true;
BEGIN
    IF NEW.player2_id IS NOT NULL AND NEW.player2_id <> NEW.player1_id THEN
        -- Check player2 notification preferences
        SELECT COALESCE(duel_alerts, social_alerts, true) INTO v_pref_allowed
        FROM public.notification_preferences
        WHERE user_id = NEW.player2_id;

        IF v_pref_allowed IS NOT FALSE THEN
            SELECT COALESCE(display_name, 'A scholar') INTO v_p1_name
            FROM public.profiles
            WHERE id = NEW.player1_id;

            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                category,
                data
            ) VALUES (
                NEW.player2_id,
                '⚔️ Quiz Duel Challenge!',
                format('%s challenged you to a %s quiz duel! Tap to accept and defend your rank.', COALESCE(v_p1_name, 'A scholar'), NEW.subject),
                'quiz_duel_challenge',
                jsonb_build_object(
                    'duelId', NEW.duel_id,
                    'challengerId', NEW.player1_id,
                    'challengerName', COALESCE(v_p1_name, 'A scholar'),
                    'subject', NEW.subject,
                    'route', '/quiz-duel',
                    'action', 'quiz_duel_challenge'
                )
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_quiz_duel_created_notification ON public.quiz_duels;
CREATE TRIGGER trg_quiz_duel_created_notification
    AFTER INSERT ON public.quiz_duels
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_on_quiz_duel_created();

-- 5. Updated fn_process_quiz_duel_outcome: Dispatches result notifications with ELO diffs
CREATE OR REPLACE FUNCTION public.fn_process_quiz_duel_outcome(
    p_duel_id TEXT,
    p_player1_id UUID,
    p_player2_id UUID,
    p_player1_score INT,
    p_player2_score INT,
    p_winner_id UUID DEFAULT NULL,
    p_is_draw BOOLEAN DEFAULT FALSE,
    p_is_forfeit BOOLEAN DEFAULT FALSE,
    p_forfeit_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_p1_elo INT := 1200;
    v_p2_elo INT := 1200;
    v_expected_p1 FLOAT;
    v_expected_p2 FLOAT;
    v_actual_p1 FLOAT;
    v_actual_p2 FLOAT;
    v_k_factor CONSTANT INT := 32;
    v_new_p1_elo INT;
    v_new_p2_elo INT;
    v_subject TEXT := 'Quiz Duel';
    v_result JSONB;
BEGIN
    -- Fetch existing ELO for Player 1
    SELECT COALESCE(elo_rating, 1200) INTO v_p1_elo
    FROM public.profiles
    WHERE id = p_player1_id;

    -- Fetch existing ELO for Player 2 (if real user)
    IF p_player2_id IS NOT NULL THEN
        SELECT COALESCE(elo_rating, 1200) INTO v_p2_elo
        FROM public.profiles
        WHERE id = p_player2_id;
    ELSE
        v_p2_elo := 1200;
    END IF;

    -- Fetch subject if recorded in duel
    SELECT COALESCE(subject, 'Quiz Duel') INTO v_subject
    FROM public.quiz_duels
    WHERE duel_id = p_duel_id
    LIMIT 1;

    -- Calculate expected scores using standard Elo rating formula
    v_expected_p1 := 1.0 / (1.0 + POWER(10.0, (v_p2_elo - v_p1_elo)::FLOAT / 400.0));
    v_expected_p2 := 1.0 / (1.0 + POWER(10.0, (v_p1_elo - v_p2_elo)::FLOAT / 400.0));

    -- Determine actual scores (1 = Win, 0.5 = Draw, 0 = Loss)
    IF p_is_draw THEN
        v_actual_p1 := 0.5;
        v_actual_p2 := 0.5;
    ELSIF p_winner_id = p_player1_id THEN
        v_actual_p1 := 1.0;
        v_actual_p2 := 0.0;
    ELSE
        v_actual_p1 := 0.0;
        v_actual_p2 := 1.0;
    END IF;

    -- Calculate new ELO ratings
    v_new_p1_elo := GREATEST(100, ROUND(v_p1_elo + v_k_factor * (v_actual_p1 - v_expected_p1)));
    v_new_p2_elo := GREATEST(100, ROUND(v_p2_elo + v_k_factor * (v_actual_p2 - v_expected_p2)));

    -- Update user profiles with new ELO
    UPDATE public.profiles
    SET elo_rating = v_new_p1_elo
    WHERE id = p_player1_id;

    IF p_player2_id IS NOT NULL THEN
        UPDATE public.profiles
        SET elo_rating = v_new_p2_elo
        WHERE id = p_player2_id;
    END IF;

    -- Dispatch Player 1 outcome notification
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        p_player1_id,
        CASE
            WHEN p_is_draw THEN '🤝 Quiz Duel Draw!'
            WHEN p_winner_id = p_player1_id THEN '🏆 You won the Quiz Duel!'
            ELSE '📚 Quiz Duel Complete'
        END,
        CASE
            WHEN p_is_draw THEN format('Close battle in %s! Final score: %s - %s. New ELO: %s.', v_subject, p_player1_score, p_player2_score, v_new_p1_elo)
            WHEN p_winner_id = p_player1_id THEN format('Victory in %s! Score: %s - %s. New ELO: %s (+%s).', v_subject, p_player1_score, p_player2_score, v_new_p1_elo, v_new_p1_elo - v_p1_elo)
            ELSE format('Good match in %s! Score: %s - %s. New ELO: %s (%s). Tap to review missed questions.', v_subject, p_player1_score, p_player2_score, v_new_p1_elo, v_new_p1_elo - v_p1_elo)
        END,
        'quiz_duel_result',
        jsonb_build_object(
            'duelId', p_duel_id,
            'result', CASE WHEN p_is_draw THEN 'draw' WHEN p_winner_id = p_player1_id THEN 'win' ELSE 'loss' END,
            'eloBefore', v_p1_elo,
            'eloAfter', v_new_p1_elo,
            'route', '/quiz-duel',
            'action', 'quiz_duel_result'
        )
    );

    -- Dispatch Player 2 outcome notification (if real user)
    IF p_player2_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            p_player2_id,
            CASE
                WHEN p_is_draw THEN '🤝 Quiz Duel Draw!'
                WHEN p_winner_id = p_player2_id THEN '🏆 You won the Quiz Duel!'
                ELSE '📚 Quiz Duel Complete'
            END,
            CASE
                WHEN p_is_draw THEN format('Close battle in %s! Final score: %s - %s. New ELO: %s.', v_subject, p_player2_score, p_player1_score, v_new_p2_elo)
                WHEN p_winner_id = p_player2_id THEN format('Victory in %s! Score: %s - %s. New ELO: %s (+%s).', v_subject, p_player2_score, p_player1_score, v_new_p2_elo, v_new_p2_elo - v_p2_elo)
                ELSE format('Good match in %s! Score: %s - %s. New ELO: %s (%s). Tap to review missed questions.', v_subject, p_player2_score, p_player1_score, v_new_p2_elo, v_new_p2_elo - v_p2_elo)
            END,
            'quiz_duel_result',
            jsonb_build_object(
                'duelId', p_duel_id,
                'result', CASE WHEN p_is_draw THEN 'draw' WHEN p_winner_id = p_player2_id THEN 'win' ELSE 'loss' END,
                'eloBefore', v_p2_elo,
                'eloAfter', v_new_p2_elo,
                'route', '/quiz-duel',
                'action', 'quiz_duel_result'
            )
        );
    END IF;

    -- Return outcome summary JSON
    v_result := jsonb_build_object(
        'duel_id', p_duel_id,
        'player1_id', p_player1_id,
        'player1_elo_before', v_p1_elo,
        'player1_elo_after', v_new_p1_elo,
        'player1_elo_diff', v_new_p1_elo - v_p1_elo,
        'player2_id', p_player2_id,
        'player2_elo_before', v_p2_elo,
        'player2_elo_after', v_new_p2_elo,
        'player2_elo_diff', v_new_p2_elo - v_p2_elo
    );

    RETURN v_result;
END;
$$;

-- 6. Optimized Study Circle Nudge RPC with Single Batch Server FCM Push
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
    v_member_ids UUID[];
    v_notif_title TEXT;
    v_notif_body TEXT;
    v_anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpemFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTIwMTQsImV4cCI6MjA3MTk2ODAxNH0.eO6nK0j1x1k0d0i0j0k0l0m0n0o0p0q0r0s0t0u0v0w';
    v_uid UUID;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Retrieve sender display name
    SELECT COALESCE(display_name, raw_user_meta_data->>'full_name', email, 'A scholar')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = v_sender_id;

    -- Retrieve circle info
    SELECT * INTO v_circle
    FROM study_circles
    WHERE id = p_circle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study Circle not found';
    END IF;

    -- Collect all other members in the pod
    SELECT array_agg(user_id) INTO v_member_ids
    FROM study_circle_members
    WHERE circle_id = p_circle_id AND user_id <> v_sender_id;

    IF v_member_ids IS NULL OR array_length(v_member_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', true, 'nudged_count', 0, 'message', 'No other members to nudge');
    END IF;

    v_notif_title := format('⚡ Focus Nudge from %s!', v_sender_name);
    v_notif_body := format('%s nudged your "%s" pod! Time to hit your weekly focus targets.', v_sender_name, v_circle.name);

    -- Insert in-app notifications for all members (which automatically enqueue to outbox via trigger)
    FOREACH v_uid IN ARRAY v_member_ids
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            v_uid,
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
    END LOOP;

    -- Server directly dispatches batch FCM push to all members in one atomic call
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
        BEGIN
            PERFORM net.http_post(
                url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_anon_key,
                    'X-Server-Trigger', 'kortex-internal-worker'
                ),
                body := jsonb_build_object(
                    'userIds', v_member_ids,
                    'title', v_notif_title,
                    'body', v_notif_body,
                    'category', 'room_invite',
                    'skipInboxInsert', true,
                    'data', jsonb_build_object(
                        'circle_id', p_circle_id,
                        'circle_name', v_circle.name,
                        'sender_id', v_sender_id,
                        'sender_name', v_sender_name,
                        'route', '/community',
                        'pushed', true
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Nudge batch FCM push error: %', SQLERRM;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'nudged_count', array_length(v_member_ids, 1)
    );
END;
$$;

-- 7. Automated Server-Side Cron Schedules (24/7 autonomous FCM pushing)
DO $cron_setup$
DECLARE
    v_anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpemFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTIwMTQsImV4cCI6MjA3MTk2ODAxNH0.eO6nK0j1x1k0d0i0j0k0l0m0n0o0p0q0r0s0t0u0v0w';
    v_outbox_cmd TEXT;
    v_sweep_cmd TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Run the FCM outbox worker every 1 minute
        PERFORM cron.unschedule('process-notification-outbox')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-notification-outbox');

        IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
            v_outbox_cmd := format($cmd$
                SELECT net.http_post(
                    url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/trigger-notifications',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer %s',
                        'X-Server-Trigger', 'kortex-internal-worker'
                    ),
                    body := jsonb_build_object('action', 'process_outbox', 'batchSize', 100)
                );
            $cmd$, v_anon_key);

            PERFORM cron.schedule(
                'process-notification-outbox',
                '* * * * *',
                v_outbox_cmd
            );

            -- Run full academic intelligence worker sweep every 15 minutes
            PERFORM cron.unschedule('run-academic-worker-sweep')
            WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'run-academic-worker-sweep');

            v_sweep_cmd := format($cmd$
                SELECT net.http_post(
                    url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/trigger-notifications',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer %s',
                        'X-Server-Trigger', 'kortex-internal-worker'
                    ),
                    body := jsonb_build_object('action', 'run_worker', 'batchSize', 100)
                );
            $cmd$, v_anon_key);

            PERFORM cron.schedule(
                'run-academic-worker-sweep',
                '*/15 * * * *',
                v_sweep_cmd
            );
        END IF;

        -- Ensure daily streak reminder is scheduled at 19:30 UTC
        PERFORM cron.unschedule('check-daily-streaks-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-daily-streaks-and-notify');

        PERFORM cron.schedule(
            'check-daily-streaks-and-notify',
            '30 19 * * *',
            'SELECT public.check_daily_streaks_and_notify();'
        );

        -- Ensure spaced repetition due check is scheduled at 08:30 UTC
        PERFORM cron.unschedule('check-spaced-repetition-due-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-spaced-repetition-due-and-notify');

        PERFORM cron.schedule(
            'check-spaced-repetition-due-and-notify',
            '30 8 * * *',
            'SELECT public.check_spaced_repetition_due_and_notify();'
        );

        -- Ensure exam countdown milestones check is scheduled at 09:00 UTC
        PERFORM cron.unschedule('check-exam-milestones-and-notify')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-exam-milestones-and-notify');

        PERFORM cron.schedule(
            'check-exam-milestones-and-notify',
            '0 9 * * *',
            'SELECT public.check_exam_milestones_and_notify();'
        );
    END IF;
END $cron_setup$;

NOTIFY pgrst, 'reload schema';
