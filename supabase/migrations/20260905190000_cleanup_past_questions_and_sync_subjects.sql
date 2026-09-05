-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: PURGE GENERIC PAST QUESTIONS & SYNC UNIFIED SUBJECTS
-- Standardize subject names and codes (MTH, ENG, PHY, CHM, etc.) across WAEC, JAMB, and NECO
-- ==============================================================================

-- 1. Purge all generic past questions that were previously curated without headway
DELETE FROM public.past_questions;

-- 2. Remove legacy high school course entries with W- or J- prefixes
DELETE FROM public.curated_courses 
WHERE course_code LIKE 'W-%' 
   OR course_code LIKE 'J-%'
   OR id LIKE 'waec-%'
   OR id LIKE 'jamb-%';

-- 3. Upsert unified subjects across WAEC, JAMB, and NECO
-- Every exam shares the EXACT same courseCode (e.g. MTH, ENG, PHY) and title.
DO $$
DECLARE
    exams TEXT[] := ARRAY['WAEC', 'JAMB', 'NECO'];
    e TEXT;
    exam_lower TEXT;
BEGIN
    FOREACH e IN ARRAY exams
    LOOP
        exam_lower := lower(e);

        -- Core
        INSERT INTO public.curated_courses (id, course_code, title, department, total_materials, has_active_past_papers, icon_name, color_hex, syllabus_coverage, academic_level, field_category)
        VALUES 
        (exam_lower || '-mth', 'MTH', 'Mathematics', e || ' - Core', 48, true, 'calculate', '#6366F1', 0.95, 'high_school', 'Exam Prep'),
        (exam_lower || '-eng', 'ENG', 'English Language', e || ' - Core', 52, true, 'auto_stories', '#F59E0B', 0.92, 'high_school', 'Exam Prep'),
        (exam_lower || '-civ', 'CIV', 'Civic Education', e || ' - Core', 26, true, 'policy', '#10B981', 0.88, 'high_school', 'Exam Prep'),
        (exam_lower || '-dpr', 'DPR', 'Data Processing', e || ' - Core', 28, true, 'terminal', '#8B5CF6', 0.85, 'high_school', 'Exam Prep'),
        (exam_lower || '-cmp', 'CMP', 'Computer Studies', e || ' - Core', 30, true, 'laptop', '#06B6D4', 0.87, 'high_school', 'Exam Prep')
        ON CONFLICT (id) DO UPDATE SET
            course_code = EXCLUDED.course_code,
            title = EXCLUDED.title,
            department = EXCLUDED.department;

        -- Sciences
        INSERT INTO public.curated_courses (id, course_code, title, department, total_materials, has_active_past_papers, icon_name, color_hex, syllabus_coverage, academic_level, field_category)
        VALUES 
        (exam_lower || '-phy', 'PHY', 'Physics', e || ' - Sciences', 44, true, 'bolt', '#06B6D4', 0.90, 'high_school', 'Exam Prep'),
        (exam_lower || '-chm', 'CHM', 'Chemistry', e || ' - Sciences', 40, true, 'biotech', '#EC4899', 0.89, 'high_school', 'Exam Prep'),
        (exam_lower || '-bio', 'BIO', 'Biology', e || ' - Sciences', 46, true, 'eco', '#10B981', 0.91, 'high_school', 'Exam Prep'),
        (exam_lower || '-fmth', 'FMTH', 'Further Mathematics', e || ' - Sciences', 35, true, 'functions', '#4F46E5', 0.85, 'high_school', 'Exam Prep'),
        (exam_lower || '-agr', 'AGR', 'Agricultural Science', e || ' - Sciences', 29, true, 'agriculture', '#84CC16', 0.86, 'high_school', 'Exam Prep'),
        (exam_lower || '-td', 'TD', 'Technical Drawing', e || ' - Sciences', 24, true, 'architecture', '#F97316', 0.82, 'high_school', 'Exam Prep'),
        (exam_lower || '-anh', 'ANH', 'Animal Husbandry', e || ' - Sciences', 25, true, 'pets', '#A855F7', 0.84, 'high_school', 'Exam Prep'),
        (exam_lower || '-phe', 'PHE', 'Physical Education', e || ' - Sciences', 22, true, 'fitness_center', '#14B8A6', 0.80, 'high_school', 'Exam Prep')
        ON CONFLICT (id) DO UPDATE SET
            course_code = EXCLUDED.course_code,
            title = EXCLUDED.title,
            department = EXCLUDED.department;

        -- Commercial
        INSERT INTO public.curated_courses (id, course_code, title, department, total_materials, has_active_past_papers, icon_name, color_hex, syllabus_coverage, academic_level, field_category)
        VALUES 
        (exam_lower || '-ecn', 'ECN', 'Economics', e || ' - Commercial', 38, true, 'trending_up', '#3B82F6', 0.87, 'high_school', 'Exam Prep'),
        (exam_lower || '-com', 'COM', 'Commerce', e || ' - Commercial', 30, true, 'storefront', '#0284C7', 0.82, 'high_school', 'Exam Prep'),
        (exam_lower || '-acc', 'ACC', 'Accounts - Principles of Accounts', e || ' - Commercial', 34, true, 'receipt_long', '#2563EB', 0.84, 'high_school', 'Exam Prep'),
        (exam_lower || '-bkp', 'BKP', 'Book Keeping', e || ' - Commercial', 26, true, 'menu_book', '#0D9488', 0.81, 'high_school', 'Exam Prep'),
        (exam_lower || '-mkt', 'MKT', 'Marketing', e || ' - Commercial', 27, true, 'campaign', '#E11D48', 0.83, 'high_school', 'Exam Prep'),
        (exam_lower || '-ins', 'INS', 'Insurance', e || ' - Commercial', 24, true, 'shield', '#6D28D9', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-ofp', 'OFP', 'Office Practice', e || ' - Commercial', 22, true, 'business_center', '#475569', 0.79, 'high_school', 'Exam Prep')
        ON CONFLICT (id) DO UPDATE SET
            course_code = EXCLUDED.course_code,
            title = EXCLUDED.title,
            department = EXCLUDED.department;

        -- Arts & Humanities
        INSERT INTO public.curated_courses (id, course_code, title, department, total_materials, has_active_past_papers, icon_name, color_hex, syllabus_coverage, academic_level, field_category)
        VALUES 
        (exam_lower || '-lit', 'LIT', 'Literature in English', e || ' - Arts', 36, true, 'menu_book', '#D97706', 0.89, 'high_school', 'Exam Prep'),
        (exam_lower || '-gov', 'GOV', 'Government', e || ' - Arts', 32, true, 'account_balance', '#8B5CF6', 0.86, 'high_school', 'Exam Prep'),
        (exam_lower || '-geo', 'GEO', 'Geography', e || ' - Arts', 28, true, 'public', '#0D9488', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-his', 'HIS', 'History', e || ' - Arts', 25, true, 'history_edu', '#78350F', 0.82, 'high_school', 'Exam Prep'),
        (exam_lower || '-crk', 'CRK', 'Christian Religious Knowledge (CRK)', e || ' - Arts', 29, true, 'church', '#B45309', 0.85, 'high_school', 'Exam Prep'),
        (exam_lower || '-irk', 'IRK', 'Islamic Religious Knowledge (IRK)', e || ' - Arts', 29, true, 'mosque', '#047857', 0.85, 'high_school', 'Exam Prep'),
        (exam_lower || '-fre', 'FRE', 'French', e || ' - Arts', 26, true, 'translate', '#3B82F6', 0.81, 'high_school', 'Exam Prep'),
        (exam_lower || '-yor', 'YOR', 'Yoruba', e || ' - Arts', 24, true, 'language', '#EA580C', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-igb', 'IGB', 'Igbo', e || ' - Arts', 24, true, 'language', '#16A34A', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-hau', 'HAU', 'Hausa', e || ' - Arts', 24, true, 'language', '#9333EA', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-ara', 'ARA', 'Arabic', e || ' - Arts', 22, true, 'translate', '#059669', 0.78, 'high_school', 'Exam Prep'),
        (exam_lower || '-art', 'ART', 'Fine Arts', e || ' - Arts', 25, true, 'palette', '#BE185D', 0.83, 'high_school', 'Exam Prep'),
        (exam_lower || '-mus', 'MUS', 'Music', e || ' - Arts', 23, true, 'music_note', '#6366F1', 0.80, 'high_school', 'Exam Prep'),
        (exam_lower || '-hec', 'HEC', 'Home Economics', e || ' - Arts', 25, true, 'home', '#CA8A04', 0.81, 'high_school', 'Exam Prep'),
        (exam_lower || '-fdn', 'FDN', 'Food and Nutrition', e || ' - Arts', 26, true, 'restaurant', '#E11D48', 0.82, 'high_school', 'Exam Prep'),
        (exam_lower || '-ccp', 'CCP', 'Catering Craft Practice', e || ' - Arts', 24, true, 'dinner_dining', '#D97706', 0.79, 'high_school', 'Exam Prep'),
        (exam_lower || '-hmg', 'HMG', 'Home Management', e || ' - Arts', 23, true, 'roofing', '#475569', 0.78, 'high_school', 'Exam Prep')
        ON CONFLICT (id) DO UPDATE SET
            course_code = EXCLUDED.course_code,
            title = EXCLUDED.title,
            department = EXCLUDED.department;

    END LOOP;
END $$;

-- 4. Update auto_curate_exam_courses RPC function to match clean unified course codes & titles
CREATE OR REPLACE FUNCTION public.auto_curate_exam_courses(
    p_exam_name TEXT,
    p_subjects TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_subject TEXT;
    v_matched_id TEXT;
    v_enrolled_count INT := 0;
    v_exam_prefix TEXT := 'waec-';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    IF lower(p_exam_name) LIKE '%jamb%' OR lower(p_exam_name) LIKE '%utme%' THEN
        v_exam_prefix := 'jamb-';
    ELSIF lower(p_exam_name) LIKE '%neco%' THEN
        v_exam_prefix := 'neco-';
    ELSE
        v_exam_prefix := 'waec-';
    END IF;

    FOREACH v_subject IN ARRAY p_subjects
    LOOP
        v_matched_id := NULL;

        -- Find matching course for this exact exam track
        SELECT id INTO v_matched_id
        FROM public.curated_courses
        WHERE id LIKE v_exam_prefix || '%'
          AND (
              lower(title) LIKE '%' || lower(v_subject) || '%'
              OR lower(v_subject) LIKE '%' || lower(title) || '%'
              OR lower(course_code) = lower(v_subject)
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
