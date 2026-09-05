-- Migration: Past Questions & CBT Question Bank Schema
-- Table for storing deduplicated 5-year past examination questions across WAEC, JAMB, SAT, TOEFL, IELTS, and University departments.

CREATE TABLE IF NOT EXISTS public.past_questions (
    id TEXT PRIMARY KEY,
    fingerprint TEXT UNIQUE NOT NULL,
    exam_type TEXT NOT NULL,
    subject TEXT NOT NULL,
    year INT NOT NULL,
    question_number INT NOT NULL,
    prompt TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_option_index INT NOT NULL,
    correct_option_label TEXT NOT NULL,
    explanation TEXT NOT NULL,
    topic TEXT NOT NULL,
    passage TEXT,
    latex_formula TEXT,
    image_url TEXT,
    difficulty TEXT DEFAULT 'Medium',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for high-speed multi-attribute filtering & full-text search
CREATE INDEX IF NOT EXISTS idx_past_questions_exam_type ON public.past_questions(exam_type);
CREATE INDEX IF NOT EXISTS idx_past_questions_subject ON public.past_questions(subject);
CREATE INDEX IF NOT EXISTS idx_past_questions_year ON public.past_questions(year);
CREATE INDEX IF NOT EXISTS idx_past_questions_fingerprint ON public.past_questions(fingerprint);
CREATE INDEX IF NOT EXISTS idx_past_questions_lookup ON public.past_questions(exam_type, subject, year);

-- Enable RLS and Realtime
ALTER TABLE public.past_questions ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE public.past_questions;

-- RLS Policies: Allow read access to authenticated and anonymous users
DROP POLICY IF EXISTS "Public can read past questions" ON public.past_questions;
DROP POLICY IF EXISTS "Service role can insert/update past questions" ON public.past_questions;

CREATE POLICY "Public can read past questions"
    ON public.past_questions FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Service role can insert/update past questions"
    ON public.past_questions FOR ALL
    TO anon, authenticated, service_role
    USING (true)
    WITH CHECK (true);
