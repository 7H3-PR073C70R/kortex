-- Migration: Sync user curated courses & expose get_user_curated_courses RPC
-- Ensures curated courses are linked with onboarding status and retrievable on fresh devices

-- 1. Create get_user_curated_courses RPC
CREATE OR REPLACE FUNCTION public.get_user_curated_courses()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_courses JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

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
            'syllabusCoverage', COALESCE(uc.syllabus_coverage, c.syllabus_coverage, 0.75)
        )
    ), '[]'::jsonb)
    INTO v_courses
    FROM public.user_curated_courses uc
    JOIN public.curated_courses c ON c.id = uc.course_id
    WHERE uc.user_id = v_user_id
    ORDER BY uc.enrolled_at DESC;

    RETURN v_courses;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_user_curated_courses() TO authenticated;

-- 2. Update sync_or_create_user_courses to also mark user profile as onboarded
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

    -- Mark user profile as onboarded if enrolled in at least one course
    IF coalesce(cardinality(v_enrolled_ids), 0) > 0 THEN
        UPDATE public.profiles
        SET is_onboarded = true,
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

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

GRANT EXECUTE ON FUNCTION public.sync_or_create_user_courses(JSONB) TO authenticated;

-- 3. Update auto_curate_exam_courses to also mark user profile as onboarded
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

    FOREACH v_subject IN ARRAY p_subjects
    LOOP
        v_matched_id := NULL;

        -- 1. Try finding matching course specifically for this exam track
        SELECT id INTO v_matched_id
        FROM public.curated_courses
        WHERE (academic_level = 'high_school' OR field_category = 'Exam Prep')
          AND department ILIKE '%' || p_exam_name || '%'
          AND (
              lower(title) = lower(v_subject)
              OR lower(title) LIKE '%' || lower(v_subject) || '%'
              OR lower(v_subject) LIKE '%' || lower(title) || '%'
              OR lower(course_code) = lower(v_subject)
          )
        ORDER BY total_materials DESC
        LIMIT 1;

        -- 2. Fallback to generic subject match across all exam preps if not found
        IF v_matched_id IS NULL THEN
            SELECT id INTO v_matched_id
            FROM public.curated_courses
            WHERE (academic_level = 'high_school' OR field_category = 'Exam Prep')
              AND (
                  lower(title) = lower(v_subject)
                  OR lower(title) LIKE '%' || lower(v_subject) || '%'
                  OR lower(v_subject) LIKE '%' || lower(title) || '%'
                  OR lower(course_code) = lower(v_subject)
              )
            ORDER BY total_materials DESC
            LIMIT 1;
        END IF;

        IF v_matched_id IS NOT NULL THEN
            INSERT INTO public.user_curated_courses (user_id, course_id, syllabus_coverage)
            VALUES (v_user_id, v_matched_id, 0.0)
            ON CONFLICT (user_id, course_id) DO NOTHING;

            v_enrolled_count := v_enrolled_count + 1;
        END IF;
    END LOOP;

    -- Mark user profile as onboarded if enrolled in at least one course
    IF v_enrolled_count > 0 THEN
        UPDATE public.profiles
        SET is_onboarded = true,
            target_track = COALESCE(NULLIF(p_exam_name, ''), target_track),
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'exam', p_exam_name,
        'enrolledCount', v_enrolled_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.auto_curate_exam_courses(TEXT, TEXT[]) TO authenticated;
