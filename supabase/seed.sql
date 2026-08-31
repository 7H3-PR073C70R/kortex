-- ==============================================================================
-- KORTEX SUPABASE SEED DATA (Curated Courses & Standard Catalog)
-- ==============================================================================

-- 1. Insert Curated Courses (STEM & Examination Catalog)
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
(
    '00000000-0000-0000-0000-000000000001',
    'MTH 301',
    'Advanced Engineering Mathematics & Laplace Calculus',
    'Electrical & Electronic Engineering',
    24,
    true,
    'calculate',
    '#6366F1',
    'https://cdn.kortex.app/materials/mth301_syllabus.pdf',
    0.85,
    'bsc',
    'Engineering'
),
(
    '00000000-0000-0000-0000-000000000002',
    'PHY 202',
    'Electromagnetism & Maxwell Equations',
    'Physics & Applied Sciences',
    18,
    true,
    'bolt',
    '#06B6D4',
    'https://cdn.kortex.app/materials/phy202_syllabus.pdf',
    0.78,
    'bsc',
    'Physics'
),
(
    '00000000-0000-0000-0000-000000000003',
    'MED 405',
    'Clinical Neurophysiology & Synaptic Transmission',
    'Medicine & Surgery (MBBS)',
    32,
    false,
    'psychology',
    '#EC4899',
    'https://cdn.kortex.app/materials/med405_syllabus.pdf',
    0.92,
    'bsc',
    'Medicine'
),
(
    '00000000-0000-0000-0000-000000000004',
    'CHM 201',
    'Organic Synthesis & Reaction Mechanisms',
    'Pure & Applied Chemistry',
    15,
    true,
    'science',
    '#10B981',
    'https://cdn.kortex.app/materials/chm201_syllabus.pdf',
    0.65,
    'bsc',
    'Chemistry'
),
(
    '00000000-0000-0000-0000-000000000005',
    'JAMB-MTH',
    'JAMB UTME Advanced Mathematics Drill 2026',
    'UTME Preparatory Suite',
    40,
    true,
    'school',
    '#F59E0B',
    'https://cdn.kortex.app/materials/jamb_mth_2026.pdf',
    0.90,
    'jamb',
    'HighSchool'
)
ON CONFLICT (id) DO NOTHING;
