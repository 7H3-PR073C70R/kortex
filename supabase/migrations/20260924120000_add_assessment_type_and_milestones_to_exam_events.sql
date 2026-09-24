-- Add assessment_type and multi-milestone scoped columns to public.exam_events

ALTER TABLE IF EXISTS public.exam_events 
    ADD COLUMN IF NOT EXISTS assessment_type TEXT NOT NULL DEFAULT 'finalExam',
    ADD COLUMN IF NOT EXISTS scoped_deck_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS scoped_topics JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS weight_percent DOUBLE PRECISION NULL,
    ADD COLUMN IF NOT EXISTS is_completed BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS achieved_score_percent DOUBLE PRECISION NULL,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_exam_events_assessment_type ON public.exam_events(assessment_type);
CREATE INDEX IF NOT EXISTS idx_exam_events_is_completed ON public.exam_events(is_completed);

-- Refresh schema cache comment
COMMENT ON COLUMN public.exam_events.assessment_type IS 'Assessment type: quiz, classTest, midterm, finalExam, mockExam, custom';
