-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 003 - Dashboard Feed, Analytics & Curated Courses
-- ==============================================================================

-- 1. User Analytics Summary Table
CREATE TABLE IF NOT EXISTS public.user_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak_days INT NOT NULL DEFAULT 0,
    longest_streak_days INT NOT NULL DEFAULT 0,
    weekly_minutes_studied INT NOT NULL DEFAULT 0,
    overall_retention_rate DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    total_cards_mastered INT NOT NULL DEFAULT 0,
    xp_points INT NOT NULL DEFAULT 0,
    academic_rank TEXT NOT NULL DEFAULT 'Novice Scholar',
    syllabot_daily_insight TEXT DEFAULT 'Consistency is key. Active recall strengthens neural pathways.',
    unread_notification_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_analytics UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_analytics_user_id ON public.user_analytics(user_id);

ALTER TABLE public.user_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analytics"
    ON public.user_analytics
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own analytics"
    ON public.user_analytics
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Daily HeatMap Activity Matrix Table
CREATE TABLE IF NOT EXISTS public.heatmap_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    intensity_level INT NOT NULL DEFAULT 0,
    cards_reviewed INT NOT NULL DEFAULT 0,
    minutes_studied INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_heatmap_date UNIQUE(user_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_heatmap_activity_user_date ON public.heatmap_activity(user_id, activity_date);

ALTER TABLE public.heatmap_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own heatmap activity"
    ON public.heatmap_activity
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own heatmap activity"
    ON public.heatmap_activity
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own heatmap activity"
    ON public.heatmap_activity
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Curated Courses Catalog Table
CREATE TABLE IF NOT EXISTS public.curated_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code TEXT NOT NULL,
    title TEXT NOT NULL,
    department TEXT NOT NULL,
    total_materials INT NOT NULL DEFAULT 0,
    has_active_past_papers BOOLEAN NOT NULL DEFAULT false,
    icon_name TEXT NOT NULL DEFAULT 'school',
    color_hex TEXT NOT NULL DEFAULT '#6366F1',
    pdf_download_url TEXT,
    syllabus_coverage DOUBLE PRECISION NOT NULL DEFAULT 0.75,
    academic_level TEXT,
    field_category TEXT,
    embedding vector(1536),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_curated_courses_code ON public.curated_courses(course_code);

-- HNSW Vector Index for Semantic Course Recommendations
CREATE INDEX IF NOT EXISTS idx_curated_courses_embedding_hnsw 
    ON public.curated_courses 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

ALTER TABLE public.curated_courses ENABLE ROW LEVEL SECURITY;

-- Curated courses can be viewed by all authenticated users
CREATE POLICY "Authenticated users can view curated courses"
    ON public.curated_courses
    FOR SELECT
    TO authenticated
    USING (true);

-- 4. User Curated Course Enrollments Table
CREATE TABLE IF NOT EXISTS public.user_curated_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.curated_courses(id) ON DELETE CASCADE,
    syllabus_coverage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_course UNIQUE(user_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_user_curated_courses_user ON public.user_curated_courses(user_id);

ALTER TABLE public.user_curated_courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own enrolled courses"
    ON public.user_curated_courses
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own enrolled courses"
    ON public.user_curated_courses
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own enrolled courses"
    ON public.user_curated_courses
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. Target Exam Countdowns Table
CREATE TABLE IF NOT EXISTS public.target_exam_countdowns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exam_title TEXT NOT NULL,
    exam_code TEXT NOT NULL,
    exam_date TIMESTAMPTZ NOT NULL,
    target_readiness DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    is_critical BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_countdown UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_target_exam_countdowns_user ON public.target_exam_countdowns(user_id);

ALTER TABLE public.target_exam_countdowns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own exam countdown"
    ON public.target_exam_countdowns
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update own exam countdown"
    ON public.target_exam_countdowns
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 6. Trigger: Extend handle_new_user to Initialize user_analytics
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Create public.profiles
    INSERT INTO public.profiles (id, email, display_name, photo_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;

    -- Create public.user_calibrations
    INSERT INTO public.user_calibrations (user_id, focus, is_calibrated)
    VALUES (NEW.id, 'higherEducation', false)
    ON CONFLICT (user_id) DO NOTHING;

    -- Create public.user_analytics
    INSERT INTO public.user_analytics (user_id, current_streak_days, xp_points, academic_rank)
    VALUES (NEW.id, 0, 0, 'Novice Scholar')
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC Function: Record Study Session & Update Gamification
CREATE OR REPLACE FUNCTION public.record_study_session(
    p_deck_id UUID,
    p_cards_reviewed INT,
    p_duration_seconds INT,
    p_retention_score DOUBLE PRECISION
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_xp_earned INT := GREATEST(10, p_cards_reviewed * 10);
    v_today DATE := CURRENT_DATE;
    v_new_intensity INT;
    v_new_rank TEXT;
    v_total_xp INT;
    v_minutes INT := CEIL(p_duration_seconds / 60.0);
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- 1. Insert Session Result
    INSERT INTO public.session_results (
        deck_id,
        user_id,
        cards_reviewed,
        duration_seconds,
        retention_score,
        xp_earned
    )
    VALUES (
        p_deck_id,
        v_user_id,
        p_cards_reviewed,
        p_duration_seconds,
        p_retention_score,
        v_xp_earned
    );

    -- 2. Upsert Daily Heatmap Activity
    INSERT INTO public.heatmap_activity (
        user_id,
        activity_date,
        intensity_level,
        cards_reviewed,
        minutes_studied
    )
    VALUES (
        v_user_id,
        v_today,
        1,
        p_cards_reviewed,
        v_minutes
    )
    ON CONFLICT (user_id, activity_date) DO UPDATE
    SET cards_reviewed = public.heatmap_activity.cards_reviewed + EXCLUDED.cards_reviewed,
        minutes_studied = public.heatmap_activity.minutes_studied + EXCLUDED.minutes_studied,
        intensity_level = LEAST(4, 1 + (public.heatmap_activity.cards_reviewed + EXCLUDED.cards_reviewed) / 10);

    -- 3. Calculate Academic Rank
    SELECT COALESCE(xp_points, 0) + v_xp_earned INTO v_total_xp
    FROM public.user_analytics
    WHERE user_id = v_user_id;

    IF v_total_xp >= 5000 THEN
        v_new_rank := 'Grandmaster Scholar';
    ELSIF v_total_xp >= 2000 THEN
        v_new_rank := 'Master Scholar';
    ELSIF v_total_xp >= 800 THEN
        v_new_rank := 'Advanced Scholar';
    ELSIF v_total_xp >= 300 THEN
        v_new_rank := 'Apprentice Scholar';
    ELSE
        v_new_rank := 'Novice Scholar';
    END IF;

    -- 4. Update User Analytics Summary
    UPDATE public.user_analytics
    SET xp_points = v_total_xp,
        academic_rank = v_new_rank,
        weekly_minutes_studied = weekly_minutes_studied + v_minutes,
        overall_retention_rate = ROUND(((overall_retention_rate * 0.7) + (p_retention_score * 0.3))::NUMERIC, 2),
        total_cards_mastered = (
            SELECT COUNT(*)
            FROM public.flashcards
            WHERE user_id = v_user_id AND repetitions >= 3
        ),
        current_streak_days = GREATEST(1, current_streak_days),
        updated_at = now()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'xpEarned', v_xp_earned,
        'totalXp', v_total_xp,
        'academicRank', v_new_rank
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC Function: Aggregated Dashboard Feed for Mobile App
CREATE OR REPLACE FUNCTION public.get_dashboard_feed()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_analytics JSONB;
    v_heatmap JSONB;
    v_due_decks JSONB;
    v_courses JSONB;
    v_countdown JSONB;
    v_unread_count INT := 0;
    v_insight TEXT := 'Maintain your daily active recall streak to maximize neuro-retention.';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- Analytics Summary & Heatmap
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'dateIso', to_char(activity_date, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'intensityLevel', intensity_level,
            'cardsReviewed', cards_reviewed,
            'minutesStudied', minutes_studied
        )
    ), '[]'::jsonb)
    INTO v_heatmap
    FROM (
        SELECT activity_date, intensity_level, cards_reviewed, minutes_studied
        FROM public.heatmap_activity
        WHERE user_id = v_user_id
          AND activity_date >= (CURRENT_DATE - INTERVAL '28 days')
        ORDER BY activity_date ASC
    ) h;

    SELECT jsonb_build_object(
        'currentStreakDays', COALESCE(a.current_streak_days, 0),
        'longestStreakDays', COALESCE(a.longest_streak_days, 0),
        'weeklyMinutesStudied', COALESCE(a.weekly_minutes_studied, 0),
        'overallRetentionRate', COALESCE(a.overall_retention_rate, 0.0),
        'totalCardsMastered', COALESCE(a.total_cards_mastered, 0),
        'heatMapData', v_heatmap,
        'xpPoints', COALESCE(a.xp_points, 0),
        'academicRank', COALESCE(a.academic_rank, 'Novice Scholar')
    )
    INTO v_analytics
    FROM public.user_analytics a
    WHERE a.user_id = v_user_id;

    -- Due Study Decks
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'title', d.title,
            'subject', d.subject,
            'totalCards', d.total_cards,
            'dueCards', d.due_cards,
            'retentionRate', d.retention_rate,
            'lastReviewedIso', to_char(COALESCE(d.last_studied, d.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'category', d.category,
            'coverImageUrl', d.cover_image_url,
            'estimatedMinutes', d.estimated_minutes,
            'colorHex', d.color_hex
        )
    ), '[]'::jsonb)
    INTO v_due_decks
    FROM (
        SELECT *
        FROM public.decks
        WHERE user_id = v_user_id AND due_cards > 0
        ORDER BY due_cards DESC
        LIMIT 5
    ) d;

    -- Curated Courses (User Enrolled or Catalog Top)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'courseCode', c.course_code,
            'title', c.title,
            'department', c.department,
            'totalMaterials', c.total_materials,
            'hasActivePastPapers', c.has_active_past_papers,
            'iconName', c.icon_name,
            'colorHex', c.color_hex,
            'pdfDownloadUrl', c.pdf_download_url,
            'syllabusCoverage', COALESCE(uc.syllabus_coverage, c.syllabus_coverage)
        )
    ), '[]'::jsonb)
    INTO v_courses
    FROM public.curated_courses c
    LEFT JOIN public.user_curated_courses uc 
      ON uc.course_id = c.id AND uc.user_id = v_user_id
    LIMIT 6;

    -- Target Exam Countdown
    SELECT jsonb_build_object(
        'id', e.id,
        'examTitle', e.exam_title,
        'examCode', e.exam_code,
        'examDateIso', to_char(e.exam_date, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'daysRemaining', GREATEST(0, EXTRACT(DAY FROM (e.exam_date - now()))::INT),
        'targetReadiness', e.target_readiness,
        'isCritical', e.is_critical
    )
    INTO v_countdown
    FROM public.target_exam_countdowns e
    WHERE e.user_id = v_user_id
    LIMIT 1;

    RETURN jsonb_build_object(
        'analyticsSummary', v_analytics,
        'dueStudyDecks', v_due_decks,
        'curatedCourses', v_courses,
        'targetExamCountdown', v_countdown,
        'unreadNotificationCount', v_unread_count,
        'syllabotDailyInsight', v_insight
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
