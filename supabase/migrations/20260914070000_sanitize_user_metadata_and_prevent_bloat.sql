
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data - 'avatar_url' - 'photo_url'
WHERE (raw_user_meta_data->>'avatar_url' LIKE 'data:image%'
       OR raw_user_meta_data->>'photo_url' LIKE 'data:image%'
       OR length(raw_user_meta_data::text) > 1000);

CREATE OR REPLACE FUNCTION public.sanitize_user_metadata(p_user_id UUID DEFAULT NULL)
RETURNS void AS $$
BEGIN
    IF p_user_id IS NOT NULL THEN
        UPDATE auth.users
        SET raw_user_meta_data = raw_user_meta_data - 'avatar_url' - 'photo_url'
        WHERE id = p_user_id
          AND (raw_user_meta_data->>'avatar_url' LIKE 'data:image%'
               OR raw_user_meta_data->>'photo_url' LIKE 'data:image%'
               OR length(raw_user_meta_data::text) > 1000);
    ELSE
        UPDATE auth.users
        SET raw_user_meta_data = raw_user_meta_data - 'avatar_url' - 'photo_url'
        WHERE (raw_user_meta_data->>'avatar_url' LIKE 'data:image%'
               OR raw_user_meta_data->>'photo_url' LIKE 'data:image%'
               OR length(raw_user_meta_data::text) > 1000);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

GRANT EXECUTE ON FUNCTION public.sanitize_user_metadata(UUID) TO anon, authenticated, service_role;

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

    IF v_avatar_url LIKE 'data:image%' OR length(v_avatar_url) > 1000 THEN
        NEW.raw_user_meta_data := NEW.raw_user_meta_data - 'avatar_url' - 'photo_url';
    END IF;

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

    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user error for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;
