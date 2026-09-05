-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: APP CURRICULUM METADATA
-- Dynamic Backend-Driven Curriculum System for Academic Onboarding & Calibration
-- ==============================================================================

-- 1. Create table app_curriculum_metadata
CREATE TABLE IF NOT EXISTS public.app_curriculum_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    key TEXT NOT NULL,
    display_name TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_curriculum_category_key UNIQUE (category, key)
);

-- Indexing for category lookups and active items
CREATE INDEX IF NOT EXISTS idx_curriculum_metadata_category_active 
    ON public.app_curriculum_metadata(category, is_active);

CREATE INDEX IF NOT EXISTS idx_curriculum_metadata_key 
    ON public.app_curriculum_metadata(key);

-- Enable Row Level Security
ALTER TABLE public.app_curriculum_metadata ENABLE ROW LEVEL SECURITY;

-- 2. Allow public and authenticated read access for active curriculum items
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'app_curriculum_metadata' AND policyname = 'Allow read access to active curriculum metadata'
    ) THEN
        CREATE POLICY "Allow read access to active curriculum metadata"
            ON public.app_curriculum_metadata
            FOR SELECT
            TO anon, authenticated
            USING (is_active = true);
    END IF;
END $$;

-- 3. Seed Standardized Exams (category = 'standardized_exam')
INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active)
VALUES
(
    'standardized_exam',
    'jamb',
    'JAMB / UTME',
    '{"subtitle": "Unified Tertiary Matriculation Examination", "icon": "quiz_rounded", "country": "NG", "default_subjects": ["Mathematics (Core)", "English Language", "Physics", "Chemistry"]}'::jsonb,
    true
),
(
    'standardized_exam',
    'waec',
    'WAEC / WASSCE',
    '{"subtitle": "West African Senior School Certificate Examination", "icon": "school_rounded", "region": "West Africa"}'::jsonb,
    true
),
(
    'standardized_exam',
    'neco',
    'NECO / SSCE',
    '{"subtitle": "National Examination Council Senior School Certificate", "icon": "assignment_turned_in_rounded", "country": "NG"}'::jsonb,
    true
),
(
    'standardized_exam',
    'sat',
    'College Board SAT',
    '{"subtitle": "College Board SAT Reasoning & Subject Tests", "icon": "public_rounded", "region": "International"}'::jsonb,
    true
),
(
    'standardized_exam',
    'igcse',
    'Cambridge IGCSE / A-Levels',
    '{"subtitle": "Cambridge IGCSE, AS & A-Levels Syllabus", "icon": "military_tech_rounded", "region": "International"}'::jsonb,
    true
),
(
    'standardized_exam',
    'ielts',
    'IELTS / TOEFL',
    '{"subtitle": "English Language Proficiency Certification", "icon": "translate_rounded", "region": "International"}'::jsonb,
    true
)
ON CONFLICT (category, key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    metadata = EXCLUDED.metadata,
    is_active = EXCLUDED.is_active;

-- 4. Seed Faculty Tracks / Higher Ed Fields (category = 'faculty_track')
INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active)
VALUES
(
    'faculty_track',
    'cs',
    'Computer Science & Engineering',
    '{"subtitle": "Algorithms, Data Structures, AI/ML, Distributed Systems", "icon": "memory_rounded", "faculty": "Technology & Computing"}'::jsonb,
    true
),
(
    'faculty_track',
    'medicine',
    'Medicine & Health Sciences',
    '{"subtitle": "Anatomy, Biochemistry, Pharmacology, Pathology, Surgery", "icon": "medical_services_rounded", "faculty": "Medical Sciences"}'::jsonb,
    true
),
(
    'faculty_track',
    'law',
    'Law & Legal Studies',
    '{"subtitle": "Case Law, Constitutional Law, Jurisprudence, Legal Writing", "icon": "gavel_rounded", "faculty": "Law"}'::jsonb,
    true
),
(
    'faculty_track',
    'business',
    'Business & Economics',
    '{"subtitle": "Finance, Accounting, Economics, Management, Marketing", "icon": "business_center_rounded", "faculty": "Business & Management"}'::jsonb,
    true
),
(
    'faculty_track',
    'humanities',
    'Humanities & Arts',
    '{"subtitle": "Literature, History, Philosophy, Linguistics, Cultural Studies", "icon": "menu_book_rounded", "faculty": "Arts & Letters"}'::jsonb,
    true
),
(
    'faculty_track',
    'social_sciences',
    'Social Sciences',
    '{"subtitle": "Sociology, Political Science, Psychology, Geography", "icon": "groups_rounded", "faculty": "Social Sciences"}'::jsonb,
    true
),
(
    'faculty_track',
    'math',
    'Mathematics & Statistics',
    '{"subtitle": "Calculus, Linear Algebra, Statistics, Probability Theory", "icon": "functions_rounded", "faculty": "Physical Sciences"}'::jsonb,
    true
),
(
    'faculty_track',
    'physics',
    'Physics & Electronics',
    '{"subtitle": "Quantum Mechanics, Thermodynamics, Electromagnetism", "icon": "blur_on_rounded", "faculty": "Physical Sciences"}'::jsonb,
    true
),
(
    'faculty_track',
    'chemical_eng',
    'Chemical & Bio Engineering',
    '{"subtitle": "Organic Synthesis, Fluid Mechanics, Reaction Kinetics", "icon": "science_rounded", "faculty": "Engineering"}'::jsonb,
    true
),
(
    'faculty_track',
    'robotics',
    'Robotics & Mechatronics',
    '{"subtitle": "Control Theory, Mechatronics, Kinematics, Dynamics", "icon": "precision_manufacturing_rounded", "faculty": "Engineering"}'::jsonb,
    true
)
ON CONFLICT (category, key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    metadata = EXCLUDED.metadata,
    is_active = EXCLUDED.is_active;

-- 5. Seed Higher Ed Degree Levels (category = 'higher_ed_level')
INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active)
VALUES
(
    'higher_ed_level',
    'bsc',
    'Bachelor''s Degree (B.Sc / B.A)',
    '{"code": "bsc", "icon": "history_edu_rounded", "subtitle": "Undergraduate Degree Program"}'::jsonb,
    true
),
(
    'higher_ed_level',
    'msc',
    'Master''s Degree (M.Sc / M.A / MBA)',
    '{"code": "msc", "icon": "workspace_premium_rounded", "subtitle": "Postgraduate Master''s Program"}'::jsonb,
    true
),
(
    'higher_ed_level',
    'phd',
    'Doctorate Degree (Ph.D)',
    '{"code": "phd", "icon": "psychology_alt_rounded", "subtitle": "Doctoral Research Fellowship"}'::jsonb,
    true
),
(
    'higher_ed_level',
    'ond',
    'Ordinary National Diploma (OND)',
    '{"code": "ond", "icon": "menu_book_rounded", "subtitle": "Polytechnic 2-Year Program"}'::jsonb,
    true
),
(
    'higher_ed_level',
    'hnd',
    'Higher National Diploma (HND)',
    '{"code": "hnd", "icon": "auto_stories_rounded", "subtitle": "Advanced Polytechnic Program"}'::jsonb,
    true
)
ON CONFLICT (category, key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    metadata = EXCLUDED.metadata,
    is_active = EXCLUDED.is_active;

-- 6. Seed Academic Study Goals (category = 'study_goal')
INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active)
VALUES
(
    'study_goal',
    'thesis',
    'Thesis & Research Paper Mastery',
    '{"subtitle": "Literature citations, methodology synthesis, paper drafting", "icon": "article_rounded"}'::jsonb,
    true
),
(
    'study_goal',
    'case_law',
    'Legal Case Briefs & Jurisprudence',
    '{"subtitle": "Case briefs, statute analysis, essay argument structure", "icon": "gavel_rounded"}'::jsonb,
    true
),
(
    'study_goal',
    'socratic',
    'Socratic Problem Solving & Logic',
    '{"subtitle": "Interactive step-by-step problem solving without spoilers", "icon": "psychology_rounded"}'::jsonb,
    true
),
(
    'study_goal',
    'spaced_rep',
    'Spaced Repetition (SM-2) Flashcards',
    '{"subtitle": "Automated SM-2 review scheduling for lecture decks", "icon": "schedule_rounded"}'::jsonb,
    true
),
(
    'study_goal',
    'mock_exams',
    'Timed Mock Exams & Simulation',
    '{"subtitle": "Timed exam simulation calibrated to course syllabi", "icon": "timer_outlined"}'::jsonb,
    true
),
(
    'study_goal',
    'essay_prep',
    'Structured Essay & Argument Outlining',
    '{"subtitle": "Structured essay outlines, argument mapping, citation help", "icon": "edit_note_rounded"}'::jsonb,
    true
)
ON CONFLICT (category, key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    metadata = EXCLUDED.metadata,
    is_active = EXCLUDED.is_active;

-- 7. Seed High School Subject Modules (category = 'high_school_subject')
INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active)
VALUES
(
    'high_school_subject',
    'core_math',
    'General Mathematics (Core)',
    '{"track": "core", "subtitle": "Algebra, Geometry, Trigonometry, Statistics", "icon": "calculate_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'core_english',
    'English Language',
    '{"track": "core", "subtitle": "Comprehension, Grammar, Essay Writing, Oral English", "icon": "spellcheck_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'science_physics',
    'Physics',
    '{"track": "science", "subtitle": "Mechanics, Optics, Waves, Electromagnetism, Modern Physics", "icon": "flash_on_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'science_chemistry',
    'Chemistry',
    '{"track": "science", "subtitle": "Inorganic, Organic Reactions, Stoichiometry, Electrolysis", "icon": "science_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'science_biology',
    'Biology',
    '{"track": "science", "subtitle": "Cell Structure, Genetics, Ecology, Human Physiology", "icon": "biotech_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'science_further_math',
    'Further Mathematics',
    '{"track": "science", "subtitle": "Calculus, Vectors, Matrices, Complex Numbers", "icon": "functions_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'comm_accounting',
    'Financial Accounting',
    '{"track": "commercial", "subtitle": "Final Accounts, Ledgers, Trial Balance, Ratio Analysis", "icon": "account_balance_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'comm_economics',
    'Economics',
    '{"track": "commercial", "subtitle": "Micro & Macro Economics, Demand & Supply, Trade Theory", "icon": "trending_up_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'comm_commerce',
    'Commerce',
    '{"track": "commercial", "subtitle": "Trade, Banking, Insurance, Transport, Warehousing", "icon": "store_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_literature',
    'Literature in English',
    '{"track": "arts", "subtitle": "Prose, Poetry, Drama — Set Texts & Critical Analysis", "icon": "menu_book_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_government',
    'Government',
    '{"track": "arts", "subtitle": "Constitutions, Political Systems, Electoral Processes", "icon": "account_balance_wallet_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_history',
    'History',
    '{"track": "arts", "subtitle": "West African, Nigerian & World History, Colonialism", "icon": "history_edu_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_crk',
    'Christian Religious Studies',
    '{"track": "arts", "subtitle": "Old & New Testament Studies, Christian Ethics, Church History", "icon": "church_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_irk',
    'Islamic Studies',
    '{"track": "arts", "subtitle": "Tawhid, Fiqh, Quranic Exegesis, Hadith Literature", "icon": "auto_stories_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_geography',
    'Geography',
    '{"track": "arts", "subtitle": "Physical Geography, Map Reading, Settlement & Resources", "icon": "map_rounded"}'::jsonb,
    true
),
(
    'high_school_subject',
    'arts_civic',
    'Civic Education',
    '{"track": "arts", "subtitle": "Human Rights, Rule of Law, Democratic Values, National Values", "icon": "supervised_user_circle_rounded"}'::jsonb,
    true
)
ON CONFLICT (category, key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    metadata = EXCLUDED.metadata,
    is_active = EXCLUDED.is_active;
