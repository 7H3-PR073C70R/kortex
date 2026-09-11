#!/usr/bin/env python3
"""
scripts/sync_myschool_subjects.py
=================================
Backend synchronization script for official secondary school subjects from MySchool.ng API.
Fetches all 37 official secondary school subjects, parses their titles/slugs/icons,
and generates the Supabase migration & seed payload for WAEC, JAMB, and NECO tracks.

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
    "Mathematics": ("Core", "calculate", "#6366F1", 48, 0.95),
    "English Language": ("Core", "auto_stories", "#F59E0B", 52, 0.92),
    "Civic Education": ("Core", "policy", "#10B981", 26, 0.88),
    "Data Processing": ("Core", "terminal", "#8B5CF6", 28, 0.85),
    "Computer Studies": ("Core", "laptop", "#06B6D4", 30, 0.87),

    # Sciences
    "Physics": ("Sciences", "bolt", "#06B6D4", 44, 0.90),
    "Chemistry": ("Sciences", "biotech", "#EC4899", 40, 0.89),
    "Biology": ("Sciences", "eco", "#10B981", 46, 0.91),
    "Further Mathematics": ("Sciences", "functions", "#4F46E5", 35, 0.85),
    "Agricultural Science": ("Sciences", "agriculture", "#84CC16", 29, 0.86),
    "Technical Drawing": ("Sciences", "architecture", "#F97316", 24, 0.82),
    "Animal Husbandry": ("Sciences", "pets", "#A855F7", 25, 0.84),
    "Physical Education": ("Sciences", "fitness_center", "#14B8A6", 22, 0.80),

    # Commercial
    "Economics": ("Commercial", "trending_up", "#3B82F6", 38, 0.87),
    "Commerce": ("Commercial", "storefront", "#0284C7", 30, 0.82),
    "Accounts - Principles of Accounts": ("Commercial", "receipt_long", "#2563EB", 34, 0.84),
    "Book Keeping": ("Commercial", "menu_book", "#0D9488", 26, 0.81),
    "Marketing": ("Commercial", "campaign", "#E11D48", 27, 0.83),
    "Insurance": ("Commercial", "shield", "#6D28D9", 24, 0.80),
    "Office Practice": ("Commercial", "business_center", "#475569", 22, 0.79),

    # Arts & Humanities
    "Literature in English": ("Arts", "menu_book", "#D97706", 36, 0.89),
    "Government": ("Arts", "account_balance", "#8B5CF6", 32, 0.86),
    "Geography": ("Arts", "public", "#0D9488", 28, 0.80),
    "History": ("Arts", "history_edu", "#78350F", 25, 0.82),
    "Christian Religious Knowledge (CRK)": ("Arts", "church", "#B45309", 29, 0.85),
    "Islamic Religious Knowledge (IRK)": ("Arts", "mosque", "#047857", 29, 0.85),
    "French": ("Arts", "translate", "#3B82F6", 26, 0.81),
    "Yoruba": ("Arts", "language", "#EA580C", 24, 0.80),
    "Igbo": ("Arts", "language", "#16A34A", 24, 0.80),
    "Hausa": ("Arts", "language", "#9333EA", 24, 0.80),
    "Arabic": ("Arts", "translate", "#059669", 22, 0.78),
    "Fine Arts": ("Arts", "palette", "#BE185D", 25, 0.83),
    "Music": ("Arts", "music_note", "#6366F1", 23, 0.80),
    "Home Economics": ("Arts", "home", "#CA8A04", 25, 0.81),
    "Food and Nutrition": ("Arts", "restaurant", "#E11D48", 26, 0.82),
    "Catering Craft Practice": ("Arts", "dinner_dining", "#D97706", 24, 0.79),
    "Home Management": ("Arts", "roofing", "#475569", 23, 0.78),
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
                sys.exit(1)
    except Exception as e:
        print(f"[-] Error fetching subjects: {e}")
        sys.exit(1)

def generate_sql_migration(subjects, output_file: str):
    print(f"[*] Generating SQL migration: {output_file}")
    
    sql_lines = [
        "-- ==============================================================================",
        "-- KORTEX SUPABASE MIGRATION: MYSCHOOL.NG OFFICIAL SUBJECT SYNC",
        "-- Auto-generated by scripts/sync_myschool_subjects.py",
        "-- Tracks: WAEC, JAMB, NECO across all 37 official secondary school subjects.",
        "-- ==============================================================================",
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
    ]

    for item in subjects:
        title = item["title"].strip()
        code = derive_code(title)
        stream_info = SUBJECT_STREAM_MAP.get(title, ("Secondary Curriculum", "school", "#4F46E5", 30, 0.85))
        stream, icon, color, materials, coverage = stream_info

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
