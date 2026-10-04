-- Migration: 20260929040000_universal_fcm_push_trigger.sql
-- Automatic universal FCM push notification dispatch trigger on public.notifications table.

CREATE OR REPLACE FUNCTION public.trg_notify_and_dispatch_fcm_push()
RETURNS TRIGGER AS $$
DECLARE
    v_anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vbmdpemFmaWp1aHljZHhsdHB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzOTIwMTQsImV4cCI6MjA3MTk2ODAxNH0.eO6nK0j1x1k0d0i0j0k0l0m0n0o0p0q0r0s0t0u0v0w';
    v_auth_header TEXT;
BEGIN
    -- Skip if already pushed by push service or flagged as pushed
    IF (NEW.data->>'pushed') = 'true' THEN
        RETURN NEW;
    END IF;

    -- Build bearer token header
    v_auth_header := 'Bearer ' || COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', true), ''),
        v_anon_key
    );

    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
        BEGIN
            PERFORM net.http_post(
                url := 'https://mongizqfijuhycdxltpw.supabase.co/functions/v1/send-push-notification',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', v_auth_header
                ),
                body := jsonb_build_object(
                    'userId', NEW.user_id,
                    'title', NEW.title,
                    'body', NEW.body,
                    'category', NEW.category,
                    'data', NEW.data
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Universal FCM push dispatch error for notification %: %', NEW.id, SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_universal_fcm_push ON public.notifications;
CREATE TRIGGER trg_universal_fcm_push
    AFTER INSERT ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.trg_notify_and_dispatch_fcm_push();
