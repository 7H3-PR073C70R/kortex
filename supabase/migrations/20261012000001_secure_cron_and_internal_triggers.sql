-- ==============================================================================
-- KORTEX SECURITY HARDENING: 20261012000001
-- Secure Cron Jobs & Internal Triggers
-- Removes insecure static 'X-Server-Trigger: kortex-internal-worker' and hardcoded
-- anon key headers from database triggers and pg_cron jobs.
-- Uses standard PostgreSQL setting 'app.cron_secret' with 'X-Cron-Secret'.
-- ==============================================================================

-- 1. Update trg_enqueue_notification_to_outbox to use app.cron_secret
CREATE OR REPLACE FUNCTION public.trg_enqueue_notification_to_outbox()
RETURNS TRIGGER AS $$
DECLARE
    v_supabase_url TEXT := current_setting('app.supabase_url', true);
    v_cron_secret  TEXT := current_setting('app.cron_secret', true);
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

    -- Trigger background worker only if pg_net is available and cron_secret is configured
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') AND v_supabase_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
        BEGIN
            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/trigger-notifications',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'X-Cron-Secret', v_cron_secret
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

-- 2. Update nudge_study_circle_members_rpc to remove static header
CREATE OR REPLACE FUNCTION public.nudge_study_circle_members_rpc(
    p_circle_id UUID,
    p_custom_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_sender_id UUID := auth.uid();
    v_sender_name TEXT;
    v_circle RECORD;
    v_member_ids UUID[];
    v_target_id UUID;
    v_notif_title TEXT;
    v_notif_body TEXT;
    v_last_nudge TIMESTAMPTZ;
    v_supabase_url TEXT := current_setting('app.supabase_url', true);
    v_cron_secret  TEXT := current_setting('app.cron_secret', true);
BEGIN
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated';
    END IF;

    -- Fetch circle & verify caller is a member
    SELECT id, name INTO v_circle
    FROM public.study_communities
    WHERE id = p_circle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study circle not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.study_community_members
        WHERE community_id = p_circle_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION 'Only active members can nudge their study circle';
    END IF;

    -- Rate-limit: 1 nudge per circle per 30 minutes
    SELECT MAX(created_at) INTO v_last_nudge
    FROM public.notifications
    WHERE category = 'study_circle_nudge'
      AND (data->>'circle_id')::UUID = p_circle_id
      AND (data->>'sender_id')::UUID = v_sender_id;

    IF v_last_nudge IS NOT NULL AND v_last_nudge > now() - INTERVAL '30 minutes' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'COOLDOWN_ACTIVE',
            'message', 'You can only nudge this circle once every 30 minutes.',
            'cooldown_remaining_seconds', EXTRACT(EPOCH FROM (v_last_nudge + INTERVAL '30 minutes' - now()))::INT
        );
    END IF;

    -- Get sender display name
    SELECT COALESCE(display_name, 'A study partner') INTO v_sender_name
    FROM public.profiles WHERE id = v_sender_id;

    -- Collect all other active members in the circle
    SELECT array_agg(user_id) INTO v_member_ids
    FROM public.study_community_members
    WHERE community_id = p_circle_id AND user_id != v_sender_id;

    IF v_member_ids IS NULL OR array_length(v_member_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'nudged_count', 0,
            'message', 'No other members in this circle to nudge.'
        );
    END IF;

    v_notif_title := '⚡ ' || v_circle.name || ' Study Alert!';
    v_notif_body  := COALESCE(
        NULLIF(trim(p_custom_message), ''),
        v_sender_name || ' is studying now in ' || v_circle.name || '. Jump in and keep the streak alive!'
    );

    -- Insert in-app notifications for each member (this automatically enqueues to outbox via trigger)
    FOREACH v_target_id IN ARRAY v_member_ids
    LOOP
        INSERT INTO public.notifications (
            user_id,
            category,
            title,
            body,
            data
        ) VALUES (
            v_target_id,
            'study_circle_nudge',
            v_notif_title,
            v_notif_body,
            jsonb_build_object(
                'circle_id', p_circle_id,
                'circle_name', v_circle.name,
                'sender_id', v_sender_id,
                'sender_name', v_sender_name,
                'route', '/community'
            )
        );
    END LOOP;

    -- Direct sub-second batch dispatch via pg_net only if secure secret is present
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') AND v_supabase_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN
        BEGIN
            PERFORM net.http_post(
                url := v_supabase_url || '/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'X-Cron-Secret', v_cron_secret
                ),
                body := jsonb_build_object(
                    'userIds', v_member_ids,
                    'title', v_notif_title,
                    'body', v_notif_body,
                    'category', 'study_circle_nudge',
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

-- 3. Reschedule pg_cron jobs using X-Cron-Secret
DO $$
DECLARE
    v_supabase_url TEXT := current_setting('app.supabase_url', true);
    v_cron_secret  TEXT := current_setting('app.cron_secret', true);
    v_outbox_cmd   TEXT;
    v_sweep_cmd    TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') AND
       EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') AND
       v_supabase_url IS NOT NULL AND v_cron_secret IS NOT NULL THEN

        -- Unschedule legacy jobs
        PERFORM cron.unschedule('process-notification-outbox')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-notification-outbox');

        PERFORM cron.unschedule('run-academic-worker-sweep')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'run-academic-worker-sweep');

        -- Reschedule with X-Cron-Secret
        v_outbox_cmd := format($cmd$
            SELECT net.http_post(
                url := %L || '/functions/v1/trigger-notifications',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'X-Cron-Secret', %L
                ),
                body := jsonb_build_object('action', 'process_outbox', 'batchSize', 100)
            );
        $cmd$, v_supabase_url, v_cron_secret);

        PERFORM cron.schedule(
            'process-notification-outbox',
            '* * * * *',
            v_outbox_cmd
        );

        v_sweep_cmd := format($cmd$
            SELECT net.http_post(
                url := %L || '/functions/v1/trigger-notifications',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'X-Cron-Secret', %L
                ),
                body := jsonb_build_object('action', 'run_worker', 'batchSize', 100)
            );
        $cmd$, v_supabase_url, v_cron_secret);

        PERFORM cron.schedule(
            'run-academic-worker-sweep',
            '*/15 * * * *',
            v_sweep_cmd
        );

        RAISE NOTICE 'Rescheduled notification cron jobs with X-Cron-Secret';
    END IF;
END $$;
