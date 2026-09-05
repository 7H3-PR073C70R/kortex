-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: COURSE CURATION SYSTEM
-- Multi-disciplinary Catalog, Smart Course Syncing, and Exam Auto-Curation
-- ==============================================================================

-- 1. Ensure RLS DELETE policy exists on public.user_curated_courses
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_curated_courses' AND policyname = 'Users can delete own enrolled courses'
    ) THEN
        CREATE POLICY "Users can delete own enrolled courses"
            ON public.user_curated_courses
            FOR DELETE
            TO authenticated
            USING (auth.uid() = user_id);
    END IF;
END $$;

-- 2. Insert Multi-Disciplinary Seed Catalog Courses (All fields: Arts, Law, Business, Med, STEM, Prep)
INSERT INTO public.curated_courses (
    id,
    course_code,
    title,
    department,
    total_materials,
    has_active_past_papers,
    icon_name,
    color_hex,
    pdf_download_url,
    syllabus_coverage,
    academic_level,
    field_category
)
VALUES
-- Arts & Humanities
(
    '00000000-0000-0000-0001-000000000001',
    'ENG 101',
    'Academic Writing, Rhetoric & Critical Analysis',
    'English & Literary Studies',
    14,
    true,
    'menu_book',
    '#F59E0B',
    NULL,
    0.80,
    'bsc',
    'Arts & Humanities'
),
(
    '00000000-0000-0000-0001-000000000002',
    'HIS 102',
    'Modern African & World Civilization',
    'History & International Relations',
    16,
    true,
    'public',
    '#D97706',
    NULL,
    0.70,
    'bsc',
    'Arts & Humanities'
),

-- Social Sciences
(
    '00000000-0000-0000-0002-000000000001',
    'ECN 101',
    'Principles of Microeconomics & Market Dynamics',
    'Economics',
    22,
    true,
    'trending_up',
    '#10B981',
    NULL,
    0.85,
    'bsc',
    'Social Sciences'
),
(
    '00000000-0000-0000-0002-000000000002',
    'SOC 101',
    'Introduction to Social Structure & Human Behavior',
    'Sociology',
    15,
    false,
    'groups',
    '#059669',
    NULL,
    0.72,
    'bsc',
    'Social Sciences'
),
(
    '00000000-0000-0000-0002-000000000003',
    'POL 201',
    'Comparative Government & Political Institutions',
    'Political Science',
    18,
    true,
    'account_balance',
    '#047857',
    NULL,
    0.75,
    'bsc',
    'Social Sciences'
),

-- Law & Legal Studies
(
    '00000000-0000-0000-0003-000000000001',
    'LAW 101',
    'Nigerian & Common Legal Systems, Precedence & Method',
    'Faculty of Law',
    28,
    true,
    'gavel',
    '#8B5CF6',
    NULL,
    0.82,
    'bsc',
    'Law & Legal Studies'
),
(
    '00000000-0000-0000-0003-000000000002',
    'LAW 201',
    'Law of Contract & Commercial Obligations',
    'Faculty of Law',
    25,
    true,
    'policy',
    '#7C3AED',
    NULL,
    0.88,
    'bsc',
    'Law & Legal Studies'
),

-- Business, Finance & Accounting
(
    '00000000-0000-0000-0004-000000000001',
    'ACC 101',
    'Financial Accounting Principles & Balance Sheets',
    'Accounting',
    26,
    true,
    'receipt_long',
    '#3B82F6',
    NULL,
    0.80,
    'bsc',
    'Business & Management'
),
(
    '00000000-0000-0000-0004-000000000002',
    'MGT 201',
    'Organizational Behavior & Strategic Leadership',
    'Business Administration',
    19,
    false,
    'corporate_fare',
    '#2563EB',
    NULL,
    0.74,
    'bsc',
    'Business & Management'
),

-- Medicine & Health Sciences
(
    '00000000-0000-0000-0005-000000000001',
    'ANAT 201',
    'Gross Human Anatomy: Thorax, Abdomen & Musculoskeletal',
    'Medicine & Surgery',
    34,
    true,
    'accessibility_new',
    '#EC4899',
    NULL,
    0.90,
    'bsc',
    'Medicine & Health'
),
(
    '00000000-0000-0000-0005-000000000002',
    'NURS 101',
    'Foundations of Nursing Practice & Patient Care Ethics',
    'Nursing Sciences',
    20,
    true,
    'medical_services',
    '#DB2777',
    NULL,
    0.84,
    'bsc',
    'Medicine & Health'
),

-- Standardized Lower Exams (WAEC / JAMB / NECO / GCE / SAT)
(
    '00000000-0000-0000-0006-000000000001',
    'W-MATH',
    'WAEC/JAMB General Mathematics: Algebra, Calculus & Statistics',
    'Secondary School Board',
    42,
    true,
    'calculate',
    '#6366F1',
    NULL,
    0.95,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000002',
    'W-ENG',
    'WAEC/JAMB English Language: Lexis, Structure & Oral English',
    'Secondary School Board',
    38,
    true,
    'auto_stories',
    '#F59E0B',
    NULL,
    0.92,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000003',
    'W-PHY',
    'WAEC/JAMB Physics: Mechanics, Optics, Electricity & Modern Physics',
    'Secondary School Board',
    36,
    true,
    'bolt',
    '#06B6D4',
    NULL,
    0.90,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000004',
    'W-CHEM',
    'WAEC/JAMB Chemistry: Organic, Inorganic & Volumetric Analysis',
    'Secondary School Board',
    35,
    true,
    'science',
    '#10B981',
    NULL,
    0.91,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000005',
    'W-BIO',
    'WAEC/JAMB Biology: Genetics, Ecology, Cell Biology & Evolution',
    'Secondary School Board',
    32,
    true,
    'biotech',
    '#059669',
    NULL,
    0.88,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000006',
    'W-GOV',
    'WAEC/JAMB Government: Constitutional Development & Foreign Policy',
    'Secondary School Board',
    28,
    true,
    'account_balance',
    '#8B5CF6',
    NULL,
    0.85,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000007',
    'W-LIT',
    'WAEC/JAMB Literature in English: African & Non-African Prose & Drama',
    'Secondary School Board',
    25,
    true,
    'menu_book',
    '#EC4899',
    NULL,
    0.87,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000008',
    'W-ECN',
    'WAEC/JAMB Economics: Production, Macroeconomics & Public Finance',
    'Secondary School Board',
    30,
    true,
    'trending_up',
    '#3B82F6',
    NULL,
    0.89,
    'high_school',
    'Exam Prep'
)
ON CONFLICT (id) DO NOTHING;

-- 3. Smart Course Normalization and Enrollment RPC
-- Intelligently matches course codes and titles, provisions new courses dynamically,
-- and updates the student's enrollments.
CREATE OR REPLACE FUNCTION public.sync_or_create_user_courses(
    p_courses JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_course JSONB;
    v_course_id UUID;
    v_raw_code TEXT;
    v_norm_code TEXT;
    v_title TEXT;
    v_department TEXT;
    v_field_category TEXT;
    v_enrolled_ids UUID[] := ARRAY[]::UUID[];
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- Loop through each submitted course
    FOR v_course IN SELECT * FROM jsonb_array_elements(p_courses)
    LOOP
        v_course_id := NULL;
        v_raw_code := trim(COALESCE(v_course->>'courseCode', ''));
        v_title := trim(COALESCE(v_course->>'title', ''));
        v_department := trim(COALESCE(v_course->>'department', 'General Academics'));
        v_field_category := trim(COALESCE(v_course->>'fieldCategory', 'General'));

        -- Normalized code: uppercase, remove spaces, dashes, dots (e.g. "ECN 101" -> "ECN101")
        v_norm_code := regexp_replace(upper(v_raw_code), '[^A-Z0-9]', '', 'g');

        -- 1. If explicit UUID is provided, verify it exists
        IF (v_course->>'id') IS NOT NULL AND (v_course->>'id') ~ '^[0-9a-fA-F-]{36}$' THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE id = (v_course->>'id')::UUID;
        END IF;

        -- 2. If not matched, try matching normalized course_code
        IF v_course_id IS NULL AND length(v_norm_code) >= 3 THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE regexp_replace(upper(course_code), '[^A-Z0-9]', '', 'g') = v_norm_code
            LIMIT 1;
        END IF;

        -- 3. If not matched, try matching normalized course title
        IF v_course_id IS NULL AND length(v_title) >= 4 THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE lower(title) = lower(v_title)
               OR lower(title) LIKE '%' || lower(v_title) || '%'
            LIMIT 1;
        END IF;

        -- 4. If still not found, dynamically insert into curated_courses catalog
        IF v_course_id IS NULL AND (length(v_raw_code) > 0 OR length(v_title) > 0) THEN
            INSERT INTO public.curated_courses (
                course_code,
                title,
                department,
                field_category,
                total_materials,
                has_active_past_papers,
                icon_name,
                color_hex,
                syllabus_coverage
            )
            VALUES (
                CASE WHEN length(v_raw_code) > 0 THEN v_raw_code ELSE v_title END,
                CASE WHEN length(v_title) > 0 THEN v_title ELSE v_raw_code END,
                v_department,
                v_field_category,
                1,
                false,
                'school',
                '#6366F1',
                0.0
            )
            RETURNING id INTO v_course_id;
        END IF;

        -- Enroll the user in this course if valid
        IF v_course_id IS NOT NULL THEN
            INSERT INTO public.user_curated_courses (user_id, course_id, syllabus_coverage)
            VALUES (v_user_id, v_course_id, 0.0)
            ON CONFLICT (user_id, course_id) DO NOTHING;

            v_enrolled_ids := array_append(v_enrolled_ids, v_course_id);
        END IF;
    END LOOP;

    -- Remove any courses no longer selected by the user
    DELETE FROM public.user_curated_courses
    WHERE user_id = v_user_id
      AND NOT (course_id = ANY(v_enrolled_ids));

    -- Return the updated list of enrolled courses
    SELECT jsonb_build_object(
        'success', true,
        'enrolledCount', coalesce(cardinality(v_enrolled_ids), 0),
        'courses', (
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
                    'syllabusCoverage', COALESCE(uc.syllabus_coverage, 0.0)
                )
            ), '[]'::jsonb)
            FROM public.user_curated_courses uc
            JOIN public.curated_courses c ON c.id = uc.course_id
            WHERE uc.user_id = v_user_id
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Auto-Curation RPC for Lower Standardized Exams (WAEC, JAMB, NECO, GCE, SAT)
CREATE OR REPLACE FUNCTION public.auto_curate_exam_courses(
    p_exam_name TEXT,
    p_subjects TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_subject TEXT;
    v_matched_id UUID;
    v_enrolled_count INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- Map each selected subject to standardized catalog courses
    FOREACH v_subject IN ARRAY p_subjects
    LOOP
        v_matched_id := NULL;

        SELECT id INTO v_matched_id
        FROM public.curated_courses
        WHERE (academic_level = 'high_school' OR field_category = 'Exam Prep')
          AND (
              lower(title) LIKE '%' || lower(v_subject) || '%'
              OR lower(course_code) LIKE '%' || lower(v_subject) || '%'
          )
        ORDER BY total_materials DESC
        LIMIT 1;

        IF v_matched_id IS NOT NULL THEN
            INSERT INTO public.user_curated_courses (user_id, course_id, syllabus_coverage)
            VALUES (v_user_id, v_matched_id, 0.0)
            ON CONFLICT (user_id, course_id) DO NOTHING;

            v_enrolled_count := v_enrolled_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'exam', p_exam_name,
        'enrolledCount', v_enrolled_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Updated get_dashboard_feed() that accurately queries user's enrolled courses
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
        ORDER BY activity_date DESC
        LIMIT 28
    ) h;

    SELECT jsonb_build_object(
        'currentStreakDays', COALESCE(p.streak_days, 0),
        'longestStreakDays', GREATEST(COALESCE(p.streak_days, 0), 1),
        'weeklyMinutesStudied', COALESCE(p.weekly_minutes_studied, 0),
        'overallRetentionRate', COALESCE(p.overall_retention_rate, 0.85),
        'totalCardsMastered', COALESCE(p.total_cards_mastered, 0),
        'heatMapData', v_heatmap,
        'xpPoints', COALESCE(p.xp_points, 0),
        'academicRank', COALESCE(p.academic_rank, 'Neural Scholar I')
    )
    INTO v_analytics
    FROM public.profiles p
    WHERE p.id = v_user_id;

    -- Due Flashcard Decks for Review
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'title', d.title,
            'subject', d.subject,
            'dueCards', d.due_cards,
            'totalCards', d.total_cards,
            'retentionStability', d.retention_stability,
            'iconName', d.icon_name,
            'colorHex', d.color_hex
        )
    ), '[]'::jsonb)
    INTO v_due_decks
    FROM (
        SELECT 
            d.id,
            d.title,
            COALESCE(c.course_code, 'General') as subject,
            COUNT(f.id) as due_cards,
            COUNT(f.id) as total_cards,
            0.85 as retention_stability,
            'layers' as icon_name,
            '#6366F1' as color_hex
        FROM public.decks d
        LEFT JOIN public.curated_courses c ON c.id = d.course_id
        LEFT JOIN public.flashcards f ON f.deck_id = d.id AND f.user_id = v_user_id
        WHERE d.user_id = v_user_id
        GROUP BY d.id, d.title, c.course_code
        ORDER BY due_cards DESC
        LIMIT 5
    ) d;

    -- Enrolled Curated Courses for this User
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
            'syllabusCoverage', COALESCE(uc.syllabus_coverage, 0.0)
        )
    ), '[]'::jsonb)
    INTO v_courses
    FROM public.user_curated_courses uc
    JOIN public.curated_courses c ON c.id = uc.course_id
    WHERE uc.user_id = v_user_id
    ORDER BY uc.enrolled_at DESC;

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

    -- Unread Notifications Count
    SELECT COUNT(*) INTO v_unread_count
    FROM public.notifications
    WHERE user_id = v_user_id AND is_read = false;

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
