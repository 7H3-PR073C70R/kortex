# Kortex Supabase Backend Architecture & Migrations

This directory contains the production-grade PostgreSQL / Supabase migration files, schema definitions, Row Level Security (RLS) policies, `pgvector` HNSW indexes, and RPC functions designed to support the active Kortex Flutter mobile application.

---

## 1. Directory Structure

```text
supabase/
├── migrations/
│   ├── 20260831000001_extensions_and_auth_schema.sql       # Extensions, profiles, user_calibrations, auth triggers
│   ├── 20260831000002_decks_and_flashcards_schema.sql       # Decks, flashcards, session_results, SM-2 functions, HNSW vector index
│   └── 20260831000003_dashboard_and_analytics_schema.sql    # User analytics, heatmap, curated courses, countdown, RPC dashboard feed
├── seed.sql                                                  # Seed catalog (STEM & High School curated courses)
├── deploy.sh                                                 # Deployment helper script
└── README.md                                                 # Backend documentation
```

---

## 2. Table Schemas & Relationships

### `public.profiles`
- **`id`**: `UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
- **`email`**: `TEXT NOT NULL`
- **`display_name`**: `TEXT`
- **`photo_url`**: `TEXT`
- **`academic_institution`**: `TEXT`
- **RLS**: `auth.uid() = id`

### `public.user_calibrations`
- **`id`**: `UUID PRIMARY KEY`
- **`user_id`**: `UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE`
- **`focus`**: `TEXT ('higherEducation' | 'highSchool')`
- **`higher_ed_level`**, **`higher_ed_field`**, **`higher_ed_goals`**: Degrees and study targets.
- **`high_school_exam`**, **`high_school_subjects`**, **`high_school_timeline`**: Standardized testing targets.
- **`is_calibrated`**: `BOOLEAN DEFAULT false`
- **RLS**: `auth.uid() = user_id`

### `public.decks`
- **`id`**: `UUID PRIMARY KEY`
- **`user_id`**: `UUID REFERENCES auth.users(id) ON DELETE CASCADE`
- **`title`**, **`subject`**, **`category`**: Deck taxonomy.
- **`total_cards`**, **`due_cards`**, **`mastery_rate`**, **`retention_rate`**: Calculated SM-2 stats.
- **`last_studied`**: `TIMESTAMPTZ`
- **RLS**: `auth.uid() = user_id`

### `public.flashcards`
- **`id`**: `UUID PRIMARY KEY`
- **`deck_id`**: `UUID REFERENCES public.decks(id) ON DELETE CASCADE`
- **`user_id`**: `UUID REFERENCES auth.users(id) ON DELETE CASCADE`
- **`front`**, **`back`**, **`front_latex`**, **`back_latex`**: Card prompt with LaTeX math support.
- **`interval`**, **`repetitions`**, **`ease_factor`**, **`next_due_date`**: SM-2 memory parameters.
- **`embedding`**: `vector(1536)` indexed via HNSW (`vector_cosine_ops`).
- **RLS**: `auth.uid() = user_id`

### `public.session_results`
- **`id`**: `UUID PRIMARY KEY`
- **`deck_id`**, **`user_id`**, **`cards_reviewed`**, **`duration_seconds`**, **`retention_score`**, **`xp_earned`**
- **RLS**: `auth.uid() = user_id`

### `public.user_analytics` & `public.heatmap_activity`
- **`user_analytics`**: Streaks (`current_streak_days`, `longest_streak_days`), XP points, rank (`academic_rank`), retention rate.
- **`heatmap_activity`**: Daily activity matrix indexed by `(user_id, activity_date)`.
- **RLS**: `auth.uid() = user_id`

### `public.curated_courses` & `public.target_exam_countdowns`
- **`curated_courses`**: Pre-indexed course catalog with HNSW vector embedding for recommendation queries.
- **`target_exam_countdowns`**: Dynamic countdown to target exam dates with readiness score.

---

## 3. PostgreSQL RPC Functions

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `public.process_card_sm2_review` | `p_card_id UUID, p_quality INT` | Computes new interval & ease factor, updates card and refreshes deck due counts. |
| `public.record_study_session` | `p_deck_id UUID, p_cards_reviewed INT, p_duration_seconds INT, p_retention_score FLOAT` | Stores session results, increments daily heatmap, awards XP, and updates streaks. |
| `public.get_dashboard_feed` | *(no args, uses `auth.uid()`)* | Returns aggregated dashboard JSON for `DashboardFeedModel`. |
| `public.search_flashcards_semantic` | `p_query_embedding vector(1536), p_match_threshold FLOAT, p_match_count INT` | Cosine similarity HNSW vector search on user's flashcards. |
| `public.search_courses_semantic` | `p_query_embedding vector(1536), p_match_threshold FLOAT, p_match_count INT` | Semantic vector search on curated courses. |

---

## 4. Running Migrations Locally

```bash
# 1. Start local Supabase instance
npx supabase start

# 2. Apply all migrations
npx supabase migration up

# 3. Seed database
npx supabase db reset
```

## 5. Applying to Remote Supabase Project

```bash
# Link project
npx supabase link --project-ref <your-project-ref>

# Push migrations
npx supabase db push
```
