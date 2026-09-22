
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

    INSERT INTO public.user_devices (user_id, fcm_token, platform, device_name, is_active, updated_at)
    VALUES (v_user_id, p_fcm_token, p_platform, p_device_name, true, now())
    ON CONFLICT (fcm_token) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        platform = EXCLUDED.platform,
        device_name = COALESCE(EXCLUDED.device_name, public.user_devices.device_name),
        is_active = true,
        updated_at = now()
    RETURNING id INTO v_device_id;

    INSERT INTO public.notification_preferences (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT id, title, body, category, data INTO v_welcome_notif
    FROM public.notifications
    WHERE user_id = v_user_id 
      AND (data->>'type') = 'welcome'
      AND (data->>'pushed') IS NULL
      AND created_at >= (now() - INTERVAL '5 minutes')
    ORDER BY created_at DESC
    LIMIT 1;

    UPDATE public.notifications
    SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{pushed}', 'true'::jsonb)
    WHERE user_id = v_user_id 
      AND (data->>'type') = 'welcome'
      AND (data->>'pushed') IS NULL
      AND created_at < (now() - INTERVAL '5 minutes');

    IF v_welcome_notif.id IS NOT NULL THEN
        UPDATE public.notifications
        SET data = jsonb_set(COALESCE(data, '{}'::jsonb), '{pushed}', 'true'::jsonb)
        WHERE id = v_welcome_notif.id;

        IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
            BEGIN
                PERFORM net.http_post(
                    url := 'http://localhost:54321/functions/v1/send-push-notification',
                    headers := jsonb_build_object('Content-Type', 'application/json'),
                    body := jsonb_build_object(
                        'userId', v_user_id,
                        'title', v_welcome_notif.title,
                        'body', v_welcome_notif.body,
                        'category', 'welcome',
                        'data', v_welcome_notif.data
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'deviceId', v_device_id,
        'userId', v_user_id,
        'registeredAt', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT, TEXT) TO authenticated;
