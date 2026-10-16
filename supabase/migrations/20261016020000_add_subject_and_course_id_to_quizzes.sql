-- ==============================================================================
-- Migration: Add subject and course_id columns to public.quizzes
-- Tracks subject-level performance and links quizzes to enrolled courses
-- ==============================================================================

ALTER TABLE public.quizzes
    ADD COLUMN IF NOT EXISTS subject TEXT,
    ADD COLUMN IF NOT EXISTS course_id TEXT,
    ADD COLUMN IF NOT EXISTS course_code TEXT;

CREATE INDEX IF NOT EXISTS idx_quizzes_subject ON public.quizzes(subject);
CREATE INDEX IF NOT EXISTS idx_quizzes_course_id ON public.quizzes(course_id);
CREATE INDEX IF NOT EXISTS idx_quizzes_course_code ON public.quizzes(course_code);
CREATE INDEX IF NOT EXISTS idx_quizzes_user_subject ON public.quizzes(user_id, subject);
