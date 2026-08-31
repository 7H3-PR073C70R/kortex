-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 020 - Robust User Profile & Auth Trigger
-- Ensures seamless, fault-tolerant account creation on auth.users INSERT
-- ==============================================================================

-- 1. Ensure all columns exist on public.profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    photo_url TEXT,
    academic_institution TEXT,
    target_track TEXT NOT NULL DEFAULT 'WAEC',
    daily_card_target INT NOT NULL DEFAULT 20,
    retention_benchmark FLOAT NOT NULL DEFAULT 0.85,
    level INT NOT NULL DEFAULT 1,
    streak_days INT NOT NULL DEFAULT 0,
    is_onboarded BOOLEAN NOT NULL DEFAULT false,
    subscription_tier TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS target_track TEXT NOT NULL DEFAULT 'WAEC',
    ADD COLUMN IF NOT EXISTS daily_card_target INT NOT NULL DEFAULT 20,
    ADD COLUMN IF NOT EXISTS retention_benchmark FLOAT NOT NULL DEFAULT 0.85,
    ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS streak_days INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_onboarded BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free',
    ADD COLUMN IF NOT EXISTS photo_url TEXT,
    ADD COLUMN IF NOT EXISTS academic_institution TEXT;

-- 2. Ensure RLS is enabled on public.profiles with comprehensive policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users and triggers can insert own profile" ON public.profiles;
CREATE POLICY "Users and triggers can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id OR auth.role() = 'service_role' OR auth.role() = 'supabase_admin' OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');

-- 3. Ensure public.user_calibrations exists with policies
CREATE TABLE IF NOT EXISTS public.user_calibrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    focus TEXT NOT NULL DEFAULT 'higherEducation',
    higher_ed_level TEXT,
    higher_ed_field TEXT,
    higher_ed_goals TEXT[] NOT NULL DEFAULT '{}',
    high_school_exam TEXT,
    high_school_subjects TEXT[] NOT NULL DEFAULT '{}',
    high_school_timeline TEXT,
    is_calibrated BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_calibration UNIQUE(user_id)
);

ALTER TABLE public.user_calibrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own calibration" ON public.user_calibrations;
CREATE POLICY "Users can view own calibration"
    ON public.user_calibrations FOR SELECT
    USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users and triggers can insert own calibration" ON public.user_calibrations;
CREATE POLICY "Users and triggers can insert own calibration"
    ON public.user_calibrations FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role' OR auth.role() = 'supabase_admin' OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can update own calibration" ON public.user_calibrations;
CREATE POLICY "Users can update own calibration"
    ON public.user_calibrations FOR UPDATE
    USING (auth.uid() = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

-- 4. Grant table access
GRANT ALL ON public.profiles TO postgres, service_role, authenticated, anon;
GRANT ALL ON public.user_calibrations TO postgres, service_role, authenticated, anon;

-- 5. Fault-Tolerant handle_new_user trigger function
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

    -- Insert into public.profiles
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

    -- Insert into public.user_calibrations
    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

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
