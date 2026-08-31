-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 005 - User Profiles, Course Tracks & Goal Sync
-- ==============================================================================

-- 1. Enhance profiles table with track, daily targets, and onboarding status
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS target_track TEXT NOT NULL DEFAULT 'WAEC',
    ADD COLUMN IF NOT EXISTS daily_card_target INT NOT NULL DEFAULT 20,
    ADD COLUMN IF NOT EXISTS retention_benchmark FLOAT NOT NULL DEFAULT 0.85,
    ADD COLUMN IF NOT EXISTS level INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS streak_days INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_onboarded BOOLEAN NOT NULL DEFAULT false;

-- 2. Create Course Tracks Metadata Table for reference & syllabus scopes
CREATE TABLE IF NOT EXISTS public.course_tracks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon_name TEXT NOT NULL,
    default_daily_target INT NOT NULL DEFAULT 20,
    exam_countdown_days INT NOT NULL DEFAULT 60,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed standard STEM tracks
INSERT INTO public.course_tracks (id, name, description, icon_name, default_daily_target, exam_countdown_days)
VALUES
    ('WAEC', 'West African Senior School Certificate', 'Senior secondary core curriculum with heavy math & physics focus', 'school', 20, 68),
    ('JAMB', 'Unified Tertiary Matriculation Exam', 'High-speed multiple choice testing with speed recall drills', 'timer', 25, 45),
    ('SAT', 'Scholastic Assessment Test (STEM)', 'Advanced algebra, geometry, and critical evidence problem-solving', 'calculate', 15, 90),
    ('University', 'Undergraduate Engineering & Sciences', 'Multivariable calculus, thermodynamics, and organic synthesis', 'biotech', 30, 30)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    default_daily_target = EXCLUDED.default_daily_target,
    exam_countdown_days = EXCLUDED.exam_countdown_days;

-- Enable RLS on course_tracks
ALTER TABLE public.course_tracks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read course tracks"
    ON public.course_tracks FOR SELECT
    USING (true);

-- 3. Automatic User Profile Initialization Trigger on auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
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
        is_onboarded
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE(NEW.raw_user_meta_data->>'target_track', 'WAEC'),
        COALESCE((NEW.raw_user_meta_data->>'daily_card_target')::int, 20),
        COALESCE((NEW.raw_user_meta_data->>'retention_benchmark')::float, 0.85),
        1,
        0,
        COALESCE((NEW.raw_user_meta_data->>'is_onboarded')::boolean, false)
    )
    ON CONFLICT (id) DO UPDATE SET
        display_name = COALESCE(EXCLUDED.display_name, public.profiles.display_name),
        photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url);

    -- Ensure initial user_calibrations
    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. RPC to Update User Course Track and Daily Goal
CREATE OR REPLACE FUNCTION public.update_user_profile_track_and_goal(
    p_target_track TEXT,
    p_daily_card_target INT,
    p_retention_benchmark FLOAT DEFAULT 0.85,
    p_is_onboarded BOOLEAN DEFAULT true
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.profiles
    SET
        target_track = p_target_track,
        daily_card_target = p_daily_card_target,
        retention_benchmark = p_retention_benchmark,
        is_onboarded = p_is_onboarded,
        updated_at = now()
    WHERE id = v_user_id;

    SELECT to_jsonb(p) INTO v_result
    FROM public.profiles p
    WHERE p.id = v_user_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
