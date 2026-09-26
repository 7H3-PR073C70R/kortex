-- Migration: Unify High School Subjects into Single Track-Agnostic Courses & Prevent Duplicate Subject Enrollments
-- Date: 2026-09-26

-- 1. Ensure canonical single-subject courses exist in public.curated_courses
INSERT INTO public.curated_courses (
    id,
    course_code,
    title,
    department,
    total_materials,
    has_active_past_papers,
    icon_name,
    color_hex,
    syllabus_coverage,
    academic_level,
    field_category
)
VALUES
(
    '00000000-0000-0000-0006-000000000001',
    'MTH',
    'Mathematics',
    'Secondary School Board',
    48,
    true,
    'calculate',
    '#6366F1',
    0.95,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000002',
    'ENG',
    'English Language',
    'Secondary School Board',
    52,
    true,
    'auto_stories',
    '#F59E0B',
    0.92,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000003',
    'PHY',
    'Physics',
    'Secondary School Board',
    44,
    true,
    'bolt',
    '#06B6D4',
    0.90,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000004',
    'CHM',
    'Chemistry',
    'Secondary School Board',
    40,
    true,
    'biotech',
    '#EC4899',
    0.89,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000005',
    'BIO',
    'Biology',
    'Secondary School Board',
    46,
    true,
    'eco',
    '#10B981',
    0.91,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000006',
    'GOV',
    'Government',
    'Secondary School Board',
    32,
    true,
    'account_balance',
    '#8B5CF6',
    0.86,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000007',
    'LIT',
    'Literature in English',
    'Secondary School Board',
    36,
    true,
    'menu_book',
    '#D97706',
    0.89,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000008',
    'ECN',
    'Economics',
    'Secondary School Board',
    38,
    true,
    'trending_up',
    '#3B82F6',
    0.87,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000009',
    'CIV',
    'Civic Education',
    'Secondary School Board',
    26,
    true,
    'policy',
    '#10B981',
    0.88,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000010',
    'AGR',
    'Agricultural Science',
    'Secondary School Board',
    29,
    true,
    'agriculture',
    '#84CC16',
    0.86,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000011',
    'FMTH',
    'Further Mathematics',
    'Secondary School Board',
    35,
    true,
    'functions',
    '#4F46E5',
    0.85,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000012',
    'COM',
    'Commerce',
    'Secondary School Board',
    30,
    true,
    'storefront',
    '#0284C7',
    0.82,
    'high_school',
    'Exam Prep'
),
(
    '00000000-0000-0000-0006-000000000013',
    'ACC',
    'Accounts - Principles of Accounts',
    'Secondary School Board',
    34,
    true,
    'receipt_long',
    '#2563EB',
    0.84,
    'high_school',
    'Exam Prep'
)
ON CONFLICT (id) DO UPDATE SET 
    course_code = EXCLUDED.course_code,
    title = EXCLUDED.title,
    department = EXCLUDED.department,
    updated_at = now();

-- 2. Deduplicate user enrollments: point legacy track-specific courses (e.g. W-ENG, J-ENG, N-ENG) to canonical courses
DO $$
DECLARE
    rec RECORD;
    v_canonical_id UUID;
BEGIN
    -- Map legacy courses to canonical single-subject IDs
    FOR rec IN 
        SELECT id, course_code, title 
        FROM public.curated_courses 
        WHERE id NOT IN (
            '00000000-0000-0000-0006-000000000001',
            '00000000-0000-0000-0006-000000000002',
            '00000000-0000-0000-0006-000000000003',
            '00000000-0000-0000-0006-000000000004',
            '00000000-0000-0000-0006-000000000005',
            '00000000-0000-0000-0006-000000000006',
            '00000000-0000-0000-0006-000000000007',
            '00000000-0000-0000-0006-000000000008',
            '00000000-0000-0000-0006-000000000009',
            '00000000-0000-0000-0006-000000000010',
            '00000000-0000-0000-0006-000000000011',
            '00000000-0000-0000-0006-000000000012',
            '00000000-0000-0000-0006-000000000013'
        )
    LOOP
        v_canonical_id := NULL;

        IF lower(rec.title) LIKE '%english%' OR rec.course_code IN ('ENG', 'W-ENG', 'J-ENG', 'N-ENG') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000002';
        ELSIF lower(rec.title) LIKE '%math%' AND lower(rec.title) NOT LIKE '%further%' OR rec.course_code IN ('MTH', 'W-MATH', 'J-MATH', 'N-MATH') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000001';
        ELSIF lower(rec.title) LIKE '%physic%' OR rec.course_code IN ('PHY', 'W-PHY', 'J-PHY', 'N-PHY') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000003';
        ELSIF lower(rec.title) LIKE '%chemis%' OR rec.course_code IN ('CHM', 'W-CHEM', 'J-CHEM', 'N-CHEM') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000004';
        ELSIF lower(rec.title) LIKE '%biolog%' OR rec.course_code IN ('BIO', 'W-BIO', 'J-BIO', 'N-BIO') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000005';
        ELSIF lower(rec.title) LIKE '%govern%' OR rec.course_code IN ('GOV', 'W-GOV', 'J-GOV', 'N-GOV') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000006';
        ELSIF lower(rec.title) LIKE '%literat%' OR rec.course_code IN ('LIT', 'W-LIT', 'J-LIT', 'N-LIT') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000007';
        ELSIF lower(rec.title) LIKE '%econom%' OR rec.course_code IN ('ECN', 'W-ECN', 'J-ECN', 'N-ECN') THEN
            v_canonical_id := '00000000-0000-0000-0006-000000000008';
        END IF;

        IF v_canonical_id IS NOT NULL THEN
            -- Re-link decks
            UPDATE public.decks SET course_id = v_canonical_id WHERE course_id = rec.id;

            -- Migrate user enrollments to canonical course
            INSERT INTO public.user_curated_courses (user_id, course_id, syllabus_coverage)
            SELECT user_id, v_canonical_id, syllabus_coverage
            FROM public.user_curated_courses
            WHERE course_id = rec.id
            ON CONFLICT (user_id, course_id) DO NOTHING;

            -- Remove old enrollment rows
            DELETE FROM public.user_curated_courses WHERE course_id = rec.id;

            -- Delete legacy course row
            DELETE FROM public.curated_courses WHERE id = rec.id;
        END IF;
    END LOOP;
END $$;

-- 3. Clean up any remaining duplicate enrollments in public.user_curated_courses
DELETE FROM public.user_curated_courses a
USING public.user_curated_courses b
WHERE a.user_id = b.user_id
  AND a.course_id = b.course_id
  AND a.ctid < b.ctid;

-- 4. Update sync_or_create_user_courses to enforce single canonical course per subject
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

    FOR v_course IN SELECT * FROM jsonb_array_elements(p_courses)
    LOOP
        v_course_id := NULL;
        v_raw_code := trim(COALESCE(v_course->>'courseCode', ''));
        v_title := trim(COALESCE(v_course->>'title', ''));
        v_department := trim(COALESCE(v_course->>'department', 'Secondary School Board'));
        v_field_category := trim(COALESCE(v_course->>'fieldCategory', 'Exam Prep'));

        -- Normalize subject code (e.g. W-ENG, J-ENG, WAEC English -> ENG)
        IF lower(v_title) LIKE '%english%' OR upper(v_raw_code) IN ('ENG', 'W-ENG', 'J-ENG', 'N-ENG') THEN
            v_norm_code := 'ENG';
        ELSIF (lower(v_title) LIKE '%math%' AND lower(v_title) NOT LIKE '%further%') OR upper(v_raw_code) IN ('MTH', 'W-MATH', 'J-MATH', 'N-MATH') THEN
            v_norm_code := 'MTH';
        ELSIF lower(v_title) LIKE '%physic%' OR upper(v_raw_code) IN ('PHY', 'W-PHY', 'J-PHY', 'N-PHY') THEN
            v_norm_code := 'PHY';
        ELSIF lower(v_title) LIKE '%chemis%' OR upper(v_raw_code) IN ('CHM', 'W-CHEM', 'J-CHEM', 'N-CHEM') THEN
            v_norm_code := 'CHM';
        ELSIF lower(v_title) LIKE '%biolog%' OR upper(v_raw_code) IN ('BIO', 'W-BIO', 'J-BIO', 'N-BIO') THEN
            v_norm_code := 'BIO';
        ELSIF lower(v_title) LIKE '%govern%' OR upper(v_raw_code) IN ('GOV', 'W-GOV', 'J-GOV', 'N-GOV') THEN
            v_norm_code := 'GOV';
        ELSIF lower(v_title) LIKE '%literat%' OR upper(v_raw_code) IN ('LIT', 'W-LIT', 'J-LIT', 'N-LIT') THEN
            v_norm_code := 'LIT';
        ELSIF lower(v_title) LIKE '%econom%' OR upper(v_raw_code) IN ('ECN', 'W-ECN', 'J-ECN', 'N-ECN') THEN
            v_norm_code := 'ECN';
        ELSE
            v_norm_code := regexp_replace(upper(v_raw_code), '[^A-Z0-9]', '', 'g');
        END IF;

        -- 1. Try matching canonical course by exact ID if UUID
        IF (v_course->>'id') IS NOT NULL AND (v_course->>'id') ~ '^[0-9a-fA-F-]{36}$' THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE id = (v_course->>'id')::UUID;
        END IF;

        -- 2. Try matching by normalized course code
        IF v_course_id IS NULL AND length(v_norm_code) >= 2 THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE regexp_replace(upper(course_code), '[^A-Z0-9]', '', 'g') = v_norm_code
            ORDER BY total_materials DESC
            LIMIT 1;
        END IF;

        -- 3. Try matching by title keyword
        IF v_course_id IS NULL AND length(v_title) >= 3 THEN
            SELECT id INTO v_course_id
            FROM public.curated_courses
            WHERE lower(title) = lower(v_title)
               OR lower(title) LIKE '%' || lower(v_title) || '%'
               OR lower(v_title) LIKE '%' || lower(title) || '%'
            ORDER BY total_materials DESC
            LIMIT 1;
        END IF;

        -- 4. Fallback: Create single course if not found
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
                CASE WHEN length(v_norm_code) > 0 THEN v_norm_code ELSE v_raw_code END,
                CASE WHEN length(v_title) > 0 THEN v_title ELSE v_raw_code END,
                'Secondary School Board',
                v_field_category,
                30,
                true,
                'school',
                '#6366F1',
                0.85
            )
            RETURNING id INTO v_course_id;
        END IF;

        IF v_course_id IS NOT NULL THEN
            IF NOT (v_course_id = ANY(v_enrolled_ids)) THEN
                INSERT INTO public.user_curated_courses (user_id, course_id, syllabus_coverage)
                VALUES (v_user_id, v_course_id, 0.0)
                ON CONFLICT (user_id, course_id) DO NOTHING;

                v_enrolled_ids := array_append(v_enrolled_ids, v_course_id);
            END IF;
        END IF;
    END LOOP;

    DELETE FROM public.user_curated_courses
    WHERE user_id = v_user_id
      AND NOT (course_id = ANY(v_enrolled_ids));

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

-- 5. Update auto_curate_exam_courses to link to unified canonical courses regardless of exam track
CREATE OR REPLACE FUNCTION public.auto_curate_exam_courses(
    p_exam_name TEXT,
    p_subjects TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_subject TEXT;
    v_matched_id UUID;
    v_norm_code TEXT;
    v_enrolled_count INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    FOREACH v_subject IN ARRAY p_subjects
    LOOP
        v_matched_id := NULL;

        IF lower(v_subject) LIKE '%english%' THEN
            v_norm_code := 'ENG';
        ELSIF lower(v_subject) LIKE '%math%' AND lower(v_subject) NOT LIKE '%further%' THEN
            v_norm_code := 'MTH';
        ELSIF lower(v_subject) LIKE '%physic%' THEN
            v_norm_code := 'PHY';
        ELSIF lower(v_subject) LIKE '%chemis%' THEN
            v_norm_code := 'CHM';
        ELSIF lower(v_subject) LIKE '%biolog%' THEN
            v_norm_code := 'BIO';
        ELSIF lower(v_subject) LIKE '%govern%' THEN
            v_norm_code := 'GOV';
        ELSIF lower(v_subject) LIKE '%literat%' THEN
            v_norm_code := 'LIT';
        ELSIF lower(v_subject) LIKE '%econom%' THEN
            v_norm_code := 'ECN';
        ELSE
            v_norm_code := regexp_replace(upper(v_subject), '[^A-Z0-9]', '', 'g');
        END IF;

        SELECT id INTO v_matched_id
        FROM public.curated_courses
        WHERE regexp_replace(upper(course_code), '[^A-Z0-9]', '', 'g') = v_norm_code
           OR lower(title) LIKE '%' || lower(v_subject) || '%'
           OR lower(v_subject) LIKE '%' || lower(title) || '%'
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
