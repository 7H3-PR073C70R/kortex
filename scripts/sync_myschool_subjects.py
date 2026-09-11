#!/usr/bin/env python3
"""
scripts/sync_myschool_subjects.py
=================================
Backend synchronization script for official secondary school subjects from MySchool.ng API.
Fetches all 37 official secondary school subjects, parses their titles/slugs/icons,
creates the required database tables (`public.subjects`, `public.app_curriculum_metadata`, `public.curated_courses`),
and synchronizes the subjects across:
1. `public.subjects` (Universal Subject Directory)
2. `public.app_curriculum_metadata` (Dynamic Backend-Driven Onboarding & Calibration)
3. `public.curated_courses` (WAEC, JAMB, NECO Active-Recall Catalog)

Usage:
    python3 scripts/sync_myschool_subjects.py
    python3 scripts/sync_myschool_subjects.py --output supabase/migrations/20260911000000_sync_myschool_subjects.sql
"""

import sys
import os
import json
import urllib.request
import urllib.error
import re

MYSCHOOL_API_ENDPOINT = "https://myschool.ng/api/web/v1/classroom/subjects"

SUBJECT_STREAM_MAP = {
    # Core
    "Mathematics": ("Core", "calculate", "#6366F1", 48, 0.95, "Algebra, Geometry, Trigonometry, Statistics & Probability"),
    "English Language": ("Core", "auto_stories", "#F59E0B", 52, 0.92, "Comprehension, Summary, Lexis & Structure, Oral English"),
    "Civic Education": ("Core", "policy", "#10B981", 26, 0.88, "Citizenship, Democratic Values, Human Rights & Duties"),
    "Data Processing": ("Core", "terminal", "#8B5CF6", 28, 0.85, "Data Management, Spreadsheets, Databases & Computer Ethics"),
    "Computer Studies": ("Core", "laptop", "#06B6D4", 30, 0.87, "Hardware, Systems Architecture, Basic Programming & Logic"),

    # Sciences
    "Physics": ("Sciences", "bolt", "#06B6D4", 44, 0.90, "Mechanics, Optics, Waves, Electromagnetism, Modern Physics"),
    "Chemistry": ("Sciences", "biotech", "#EC4899", 40, 0.89, "Inorganic, Organic Reactions, Stoichiometry, Electrolysis"),
    "Biology": ("Sciences", "eco", "#10B981", 46, 0.91, "Cell Structure, Genetics, Ecology, Human Physiology"),
    "Further Mathematics": ("Sciences", "functions", "#4F46E5", 35, 0.85, "Calculus, Vectors, Matrices, Mechanics & Pure Math"),
    "Agricultural Science": ("Sciences", "agriculture", "#84CC16", 29, 0.86, "Soil Science, Crop Production, Animal Nutrition & Farm Tools"),
    "Technical Drawing": ("Sciences", "architecture", "#F97316", 24, 0.82, "Orthographic Projections, Isometric Drafting & Geometric Curves"),
    "Animal Husbandry": ("Sciences", "pets", "#A855F7", 25, 0.84, "Livestock Management, Animal Health, Breeding & Processing"),
    "Physical Education": ("Sciences", "fitness_center", "#14B8A6", 22, 0.80, "Anatomy, Sports Psychology, First Aid & Athletic Rules"),

    # Commercial
    "Economics": ("Commercial", "trending_up", "#3B82F6", 38, 0.87, "Micro & Macro Economics, Demand, Supply, Public Finance"),
    "Commerce": ("Commercial", "storefront", "#0284C7", 30, 0.82, "Trade, Banking, Insurance, Transport, Warehousing & E-commerce"),
    "Accounts - Principles of Accounts": ("Commercial", "receipt_long", "#2563EB", 34, 0.84, "Final Accounts, Balance Sheet, Ledger, Depreciation & Ratios"),
    "Book Keeping": ("Commercial", "menu_book", "#0D9488", 26, 0.81, "Double-entry, Cash Book, Petty Cash & Journal Entries"),
    "Marketing": ("Commercial", "campaign", "#E11D48", 27, 0.83, "Market Research, Pricing, Distribution & Consumer Behavior"),
    "Insurance": ("Commercial", "shield", "#6D28D9", 24, 0.80, "Risk Management, Underwriting, Life & Non-life Policies"),
    "Office Practice": ("Commercial", "business_center", "#475569", 22, 0.79, "Administrative Procedures, Filing, Business Communication"),

    # Arts & Humanities
    "Literature in English": ("Arts", "menu_book", "#D97706", 36, 0.89, "African & Non-African Prose, Poetry, Drama & Literary Criticism"),
    "Government": ("Arts", "account_balance", "#8B5CF6", 32, 0.86, "Political Systems, Constitutions, Electoral Process, Foreign Policy"),
    "Geography": ("Arts", "public", "#0D9488", 28, 0.80, "Physical Geography, Climatology, Map Reading, Regional Studies"),
    "History": ("Arts", "history_edu", "#78350F", 25, 0.82, "West African Kingdoms, Nigerian History, Colonial Era & World Wars"),
    "Christian Religious Knowledge (CRK)": ("Arts", "church", "#B45309", 29, 0.85, "Old & New Testament, Christian Ethics, Apostles & Early Church"),
    "Islamic Religious Knowledge (IRK)": ("Arts", "mosque", "#047857", 29, 0.85, "Quran Studies, Hadith, Fiqh, Islamic History & Pillars of Faith"),
    "French": ("Arts", "translate", "#3B82F6", 26, 0.81, "Grammar, Reading Comprehension, Oral Conversation & Writing"),
    "Yoruba": ("Arts", "language", "#EA580C", 24, 0.80, "Awon Asa, Ewi, Itan, Akoto & Onka Yoruba"),
    "Igbo": ("Arts", "language", "#16A34A", 24, 0.80, "Omenala, Abu, Agumagu & Nsupe Igbo"),
    "Hausa": ("Arts", "language", "#9333EA", 24, 0.80, "Al'adun Hausawa, Rubutu, Adabi & Nahawun Hausa"),
    "Arabic": ("Arts", "translate", "#059669", 22, 0.78, "Arabic Grammar, Classical Texts, Comprehension & Composition"),
    "Fine Arts": ("Arts", "palette", "#BE185D", 25, 0.83, "Art History, Painting, Sculpture, Graphics & African Crafts"),
    "Music": ("Arts", "music_note", "#6366F1", 23, 0.80, "Rudiments of Music, Western Harmony, African Rhythms & Ear Training"),
    "Home Economics": ("Arts", "home", "#CA8A04", 25, 0.81, "Family Living, Food Science, Clothing Construction & Resource Management"),
    "Food and Nutrition": ("Arts", "restaurant", "#E11D48", 26, 0.82, "Nutritional Science, Food Chemistry, Meal Planning & Preservation"),
    "Catering Craft Practice": ("Arts", "dinner_dining", "#D97706", 24, 0.79, "Culinary Arts, Kitchen Safety, Food Service & Pastry Production"),
    "Home Management": ("Arts", "roofing", "#475569", 23, 0.78, "Interior Decoration, Consumer Education, Home Maintenance & Budgeting"),
}

CODE_MAP = {
    "Mathematics": "MTH",
    "English Language": "ENG",
    "Civic Education": "CIV",
    "Data Processing": "DPR",
    "Computer Studies": "CMP",
    "Physics": "PHY",
    "Chemistry": "CHM",
    "Biology": "BIO",
    "Further Mathematics": "FMTH",
    "Agricultural Science": "AGR",
    "Technical Drawing": "TD",
    "Animal Husbandry": "ANH",
    "Physical Education": "PHE",
    "Economics": "ECN",
    "Commerce": "COM",
    "Accounts - Principles of Accounts": "ACC",
    "Book Keeping": "BKP",
    "Marketing": "MKT",
    "Insurance": "INS",
    "Office Practice": "OFP",
    "Literature in English": "LIT",
    "Government": "GOV",
    "Geography": "GEO",
    "History": "HIS",
    "Christian Religious Knowledge (CRK)": "CRK",
    "Islamic Religious Knowledge (IRK)": "IRK",
    "French": "FRE",
    "Yoruba": "YOR",
    "Igbo": "IGB",
    "Hausa": "HAU",
    "Arabic": "ARA",
    "Fine Arts": "ART",
    "Music": "MUS",
    "Home Economics": "HEC",
    "Food and Nutrition": "FDN",
    "Catering Craft Practice": "CCP",
    "Home Management": "HMG",
}

def derive_code(title: str) -> str:
    if title in CODE_MAP:
        return CODE_MAP[title]
    clean = re.sub(r'[^A-Z]', '', title.upper())
    return clean[:4] if len(clean) >= 3 else title[:3].upper()

def fetch_subjects():
    print(f"[*] Fetching secondary subjects from: {MYSCHOOL_API_ENDPOINT}")
    req = urllib.request.Request(
        MYSCHOOL_API_ENDPOINT,
        headers={"User-Agent": "Kortex-Curriculum-Sync/1.0", "Accept": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data.get("status") == 1 and isinstance(data.get("data"), list):
                print(f"[+] Successfully retrieved {len(data['data'])} subjects from MySchool.ng API.")
                return data["data"]
            else:
                print(f"[-] Unexpected response format: {data}")
    except Exception as e:
        print(f"[-] Error fetching online subjects: {e}. Checking fallback seed JSON.")

    fallback_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "supabase", "seed_subjects.json")
    if os.path.exists(fallback_file):
        with open(fallback_file, "r", encoding="utf-8") as f:
            print(f"[+] Loaded {fallback_file} fallback seed.")
            return json.load(f)
    print("[-] No fallback seed found.")
    sys.exit(1)

def generate_sql_migration(subjects, output_file: str):
    print(f"[*] Generating SQL migration: {output_file}")
    
    sql_lines = [
        "-- ==============================================================================",
        "-- KORTEX SUPABASE MIGRATION: DEDICATED SUBJECTS TABLE & MYSCHOOL SYNC",
        "-- Auto-generated by scripts/sync_myschool_subjects.py",
        "-- Tracks: WAEC, JAMB, NECO across all 37 official secondary school subjects.",
        "-- ==============================================================================",
        "",
        "-- 1. Create Dedicated Subjects Table",
        "CREATE TABLE IF NOT EXISTS public.subjects (",
        "    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),",
        "    code TEXT NOT NULL UNIQUE,",
        "    title TEXT NOT NULL,",
        "    stream TEXT NOT NULL,",
        "    icon_name TEXT NOT NULL DEFAULT 'school',",
        "    color_hex TEXT NOT NULL DEFAULT '#6366F1',",
        "    total_materials INT NOT NULL DEFAULT 30,",
        "    syllabus_coverage DOUBLE PRECISION NOT NULL DEFAULT 0.85, ",
        "    description TEXT DEFAULT '',",
        "    slug TEXT,",
        "    myschool_id INT,",
        "    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),",
        "    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()",
        ");",
        "",
        "CREATE INDEX IF NOT EXISTS idx_subjects_code ON public.subjects(code);",
        "CREATE INDEX IF NOT EXISTS idx_subjects_stream ON public.subjects(stream);",
        "",
        "ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;",
        "",
        "DO $$",
        "BEGIN",
        "    IF NOT EXISTS (",
        "        SELECT 1 FROM pg_policies ",
        "        WHERE tablename = 'subjects' AND policyname = 'Allow public read subjects'",
        "    ) THEN",
        "        CREATE POLICY \"Allow public read subjects\"",
        "            ON public.subjects FOR SELECT",
        "            TO anon, authenticated",
        "            USING (true);",
        "    END IF;",
        "END $$;",
        "",
        "-- 2. Seed / Upsert all 37 subjects into public.subjects",
    ]

    for item in subjects:
        title = item["title"].strip()
        code = derive_code(title)
        slug = item.get("slug", "")
        myschool_id = item.get("id", "NULL")
        stream_info = SUBJECT_STREAM_MAP.get(title, ("Core", "school", "#4F46E5", 30, 0.85, ""))
        stream, icon, color, materials, coverage, desc = stream_info

        escaped_title = title.replace("'", "''")
        escaped_desc = desc.replace("'", "''")

        sql_lines.append(
            f"INSERT INTO public.subjects (code, title, stream, icon_name, color_hex, total_materials, syllabus_coverage, description, slug, myschool_id) "
            f"VALUES ('{code}', '{escaped_title}', '{stream}', '{icon}', '{color}', {materials}, {coverage}, '{escaped_desc}', '{slug}', {myschool_id}) "
            f"ON CONFLICT (code) DO UPDATE SET "
            f"title = EXCLUDED.title, stream = EXCLUDED.stream, icon_name = EXCLUDED.icon_name, color_hex = EXCLUDED.color_hex, "
            f"total_materials = EXCLUDED.total_materials, syllabus_coverage = EXCLUDED.syllabus_coverage, description = EXCLUDED.description, "
            f"slug = EXCLUDED.slug, myschool_id = EXCLUDED.myschool_id, updated_at = now();"
        )

    sql_lines.extend([
        "",
        "-- 3. Create app_curriculum_metadata Table if not exists & Sync High School Subjects",
        "CREATE TABLE IF NOT EXISTS public.app_curriculum_metadata (",
        "    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),",
        "    category TEXT NOT NULL,",
        "    key TEXT NOT NULL,",
        "    display_name TEXT NOT NULL,",
        "    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,",
        "    is_active BOOLEAN NOT NULL DEFAULT true,",
        "    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),",
        "    CONSTRAINT uq_curriculum_category_key UNIQUE (category, key)",
        ");",
        "",
        "CREATE INDEX IF NOT EXISTS idx_curriculum_metadata_category_active ",
        "    ON public.app_curriculum_metadata(category, is_active);",
        "",
        "CREATE INDEX IF NOT EXISTS idx_curriculum_metadata_key ",
        "    ON public.app_curriculum_metadata(key);",
        "",
        "ALTER TABLE public.app_curriculum_metadata ENABLE ROW LEVEL SECURITY;",
        "",
        "DO $$",
        "BEGIN",
        "    IF NOT EXISTS (",
        "        SELECT 1 FROM pg_policies ",
        "        WHERE tablename = 'app_curriculum_metadata' AND policyname = 'Allow read access to active curriculum metadata'",
        "    ) THEN",
        "        CREATE POLICY \"Allow read access to active curriculum metadata\"",
        "            ON public.app_curriculum_metadata",
        "            FOR SELECT",
        "            TO anon, authenticated",
        "            USING (is_active = true);",
        "    END IF;",
        "END $$;",
        "",
    ])

    for item in subjects:
        title = item["title"].strip()
        code = derive_code(title)
        stream_info = SUBJECT_STREAM_MAP.get(title, ("Core", "school", "#4F46E5", 30, 0.85, ""))
        stream, icon, color, materials, coverage, desc = stream_info
        escaped_title = title.replace("'", "''")
        escaped_desc = desc.replace("'", "''")
        meta_key = f"hs_{code.lower()}"
        icon_rounded = f"{icon}_rounded" if not icon.endswith("_rounded") else icon

        sql_lines.append(
            f"INSERT INTO public.app_curriculum_metadata (category, key, display_name, metadata, is_active) "
            f"VALUES ('high_school_subject', '{meta_key}', '{escaped_title}', "
            f"jsonb_build_object('code', '{code}', 'track', '{stream.lower()}', 'subtitle', '{escaped_desc}', 'icon', '{icon_rounded}', 'color', '{color}', 'total_materials', {materials}), true) "
            f"ON CONFLICT (category, key) DO UPDATE SET "
            f"display_name = EXCLUDED.display_name, metadata = EXCLUDED.metadata, is_active = EXCLUDED.is_active;"
        )

    sql_lines.extend([
        "",
        "-- 4. Create curated_courses Table if not exists & Sync into WAEC, JAMB, NECO",
        "CREATE TABLE IF NOT EXISTS public.curated_courses (",
        "    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),",
        "    course_code TEXT NOT NULL,",
        "    title TEXT NOT NULL,",
        "    department TEXT NOT NULL,",
        "    total_materials INT NOT NULL DEFAULT 0,",
        "    has_active_past_papers BOOLEAN NOT NULL DEFAULT false,",
        "    icon_name TEXT NOT NULL DEFAULT 'school',",
        "    color_hex TEXT NOT NULL DEFAULT '#6366F1',",
        "    pdf_download_url TEXT,",
        "    syllabus_coverage DOUBLE PRECISION NOT NULL DEFAULT 0.75,",
        "    academic_level TEXT,",
        "    field_category TEXT,",
        "    created_at TIMESTAMPTZ NOT NULL DEFAULT now()",
        ");",
        "",
        "CREATE INDEX IF NOT EXISTS idx_curated_courses_code ON public.curated_courses(course_code);",
        "",
        "ALTER TABLE public.curated_courses ENABLE ROW LEVEL SECURITY;",
        "",
        "DO $$",
        "BEGIN",
        "    IF NOT EXISTS (",
        "        SELECT 1 FROM pg_policies ",
        "        WHERE tablename = 'curated_courses' AND policyname = 'Authenticated users can view curated courses'",
        "    ) THEN",
        "        CREATE POLICY \"Authenticated users can view curated courses\"",
        "            ON public.curated_courses",
        "            FOR SELECT",
        "            TO anon, authenticated",
        "            USING (true);",
        "    END IF;",
        "END $$;",
        "",
        "DO $$",
        "DECLARE",
        "    exams TEXT[] := ARRAY['WAEC', 'JAMB', 'NECO'];",
        "    e TEXT;",
        "    exam_lower TEXT;",
        "BEGIN",
        "    FOREACH e IN ARRAY exams",
        "    LOOP",
        "        exam_lower := lower(e);",
        ""
    ])

    for item in subjects:
        title = item["title"].strip()
        code = derive_code(title)
        stream_info = SUBJECT_STREAM_MAP.get(title, ("Core", "school", "#4F46E5", 30, 0.85, ""))
        stream, icon, color, materials, coverage, _ = stream_info

        escaped_title = title.replace("'", "''")
        id_expr = f"md5(exam_lower || '-{code.lower()}')::uuid"
        dept_expr = f"e || ' - {stream}'"

        sql_lines.append(
            f"        INSERT INTO public.curated_courses ("
            f"id, course_code, title, department, total_materials, "
            f"has_active_past_papers, icon_name, color_hex, syllabus_coverage, academic_level, field_category) "
            f"VALUES ({id_expr}, '{code}', '{escaped_title}', {dept_expr}, {materials}, true, '{icon}', '{color}', {coverage}, 'high_school', 'Exam Prep') "
            f"ON CONFLICT (id) DO UPDATE SET "
            f"course_code = EXCLUDED.course_code, title = EXCLUDED.title, department = EXCLUDED.department, "
            f"total_materials = EXCLUDED.total_materials, icon_name = EXCLUDED.icon_name, color_hex = EXCLUDED.color_hex;"
        )

    sql_lines.extend([
        "",
        "    END LOOP;",
        "END $$;",
        "",
        "-- 5. Reload PostgREST schema cache so all tables and views are immediately live",
        "NOTIFY pgrst, 'reload schema';",
        ""
    ])

    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_lines))

    print(f"[+] SQL migration written to {output_file} ({len(sql_lines)} lines).")

def main():
    output_migration = "supabase/migrations/20260911000000_sync_myschool_subjects.sql"
    output_json = "supabase/seed_subjects.json"
    
    if len(sys.argv) > 2 and sys.argv[1] == "--output":
        output_migration = sys.argv[2]

    subjects = fetch_subjects()
    generate_sql_migration(subjects, output_migration)

    # Save backend seed JSON
    os.makedirs(os.path.dirname(output_json), exist_ok=True)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(subjects, f, indent=2)
    print(f"[+] Seed JSON written to {output_json}.")

    print("[✔] MySchool subject sync complete!")

if __name__ == "__main__":
    main()
