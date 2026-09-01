# Kortex Open Web PDF Past Questions Crawler & Ingestion Engine

A Python document-crawling CLI tool that discovers, downloads, and processes 5-year past examination **PDF documents** (2020–2024), parses structured multiple-choice questions with `pypdf`, deduplicates content using SHA-256 fingerprints, and synchronizes directly to Supabase.

---

## 1. How It Works

```
┌────────────────────────────────────────────────────────┐
│             OPEN WEB EXAM ARCHIVES & PDFS              │
└──────────────────────────┬─────────────────────────────┘
                           │
                           │ (1. Download & Stage PDFs)
                           ▼
┌────────────────────────────────────────────────────────┐
│               LOCAL PDF STAGING REPO                   │
│         storage/crawled_pdfs/{exam}/{year}/            │
└──────────────────────────┬─────────────────────────────┘
                           │
                           │ (2. Extract Text & Parse Questions via pypdf)
                           ▼
┌────────────────────────────────────────────────────────┐
│           PDF PROCESSING & DEDUPLICATION ENGINE        │
│  - Compute Document content_hash (SHA-256)             │
│  - Compute Question fingerprint (SHA-256)              │
│  - Extract Options, Answers, LaTeX & Explanations      │
└──────────────────────────┬─────────────────────────────┘
                           │
                           │ (3. Direct PostgREST Database Sync)
                           ▼
┌────────────────────────────────────────────────────────┐
│                  SUPABASE DATABASE                     │
│  - public.past_questions (Extracted & Deduplicated Qs) │
│  - public.documents (PDF Files & Metadata)             │
└────────────────────────────────────────────────────────┘
```

---

## 2. Requirements & Setup

Install the required Python packages:

```bash
python3 -m pip install -r scripts/crawler/requirements.txt
```

---

## 3. Usage Commands

### A. Preview PDF Discovery & Document Extraction (Dry Run)
```bash
python3 scripts/crawler/crawler.py --dry-run
```

### B. Ingest and Synchronize to Supabase
```bash
python3 scripts/crawler/crawler.py --sync-db
```

### C. Filter by Specific Exam or Year
```bash
# Only process WAEC 2024 PDF exam papers:
python3 scripts/crawler/crawler.py --exam WAEC --year 2024 --sync-db

# Only process SAT papers:
python3 scripts/crawler/crawler.py --exam SAT --sync-db
```
