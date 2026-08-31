-- Migration: AI Practice Quiz & Mock Exam Tables
-- Creates quizzes and quiz_results tables with Row Level Security.

CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    deck_id UUID REFERENCES public.decks(id) ON DELETE SET NULL,
    document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
    total_questions INT NOT NULL DEFAULT 10,
    correct_answers INT NOT NULL DEFAULT 0,
    score_percent INT NOT NULL DEFAULT 0,
    duration_seconds INT NOT NULL DEFAULT 0,
    weak_subtopics TEXT[] DEFAULT '{}',
    completed_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for querying by user and deck
CREATE INDEX IF NOT EXISTS idx_quizzes_user_id ON public.quizzes(user_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_deck_id ON public.quizzes(deck_id);

-- Enable RLS and Realtime
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quizzes;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Users can insert own quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Users can update own quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Users can delete own quizzes" ON public.quizzes;

CREATE POLICY "Users can view own quizzes"
    ON public.quizzes FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own quizzes"
    ON public.quizzes FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own quizzes"
    ON public.quizzes FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own quizzes"
    ON public.quizzes FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
