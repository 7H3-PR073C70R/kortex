# Kortex Past Questions Crawler & Ingestion Tool (Python)

A standalone Python CLI crawler that aggregates, deduplicates (via SHA-256 fingerprint hashing), and directly ingests 5-year past examination questions into your Supabase database (`past_questions` table).

---

## 1. Prerequisites & Installation

Make sure you have Python 3 installed. Install the dependencies:

```bash
pip install -r scripts/crawler/requirements.txt
```

---

## 2. Supabase Database Setup

Before running the sync for the first time, ensure the `past_questions` migration has been applied:

```bash
# Apply with Supabase CLI
supabase db push
# OR apply supabase/migrations/20260831170000_create_past_questions_table.sql directly in Supabase SQL editor
```

---

## 3. Running the Crawler

### A. Preview Crawled & Deduplicated Questions (Dry Run)
```bash
python3 scripts/crawler/crawler.py --dry-run
```

### B. Sync All Past Questions to Supabase
```bash
python3 scripts/crawler/crawler.py --sync-db
```

### C. Filter by Exam Type or Year
```bash
# Only harvest and sync WAEC 2024 questions
python3 scripts/crawler/crawler.py --exam WAEC --year 2024 --sync-db

# Only harvest and sync SAT questions
python3 scripts/crawler/crawler.py --exam SAT --sync-db
```

### D. Custom Supabase Credentials
By default, the crawler automatically loads `API_BASE_URL` and `SUPABASE_ANON_KEY` from `.env.development`. You can also supply them via CLI:
```bash
python3 scripts/crawler/crawler.py --url https://your-project.supabase.co --key your_service_role_key --sync-db
```
