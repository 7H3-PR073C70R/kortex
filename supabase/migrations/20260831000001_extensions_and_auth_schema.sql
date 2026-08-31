-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 001 - Extensions, Auth Profiles & Calibration
-- ==============================================================================

-- 1. Enable Required PostgreSQL Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. User Profiles Table (Mirrors Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    photo_url TEXT,
    academic_institution TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on email
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles RLS Policies:
-- Users can read their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 3. Onboarding User Calibration Table
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

-- Index on user_id
CREATE INDEX IF NOT EXISTS idx_user_calibrations_user_id ON public.user_calibrations(user_id);

-- Enable RLS on user_calibrations
ALTER TABLE public.user_calibrations ENABLE ROW LEVEL SECURITY;

-- User Calibrations RLS Policies:
CREATE POLICY "Users can view own calibration"
    ON public.user_calibrations
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own calibration"
    ON public.user_calibrations
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own calibration"
    ON public.user_calibrations
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. Automatic User Profile Initialization Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create public.profiles record
    INSERT INTO public.profiles (id, email, display_name, photo_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    -- Create initial public.user_calibrations record
    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Updated Timestamp Trigger Function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_user_calibrations_updated_at ON public.user_calibrations;
CREATE TRIGGER set_user_calibrations_updated_at
    BEFORE UPDATE ON public.user_calibrations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
