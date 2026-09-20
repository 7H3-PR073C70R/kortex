-- Add course_id and course_code columns to public.decks
ALTER TABLE public.decks ADD COLUMN IF NOT EXISTS course_id TEXT;
ALTER TABLE public.decks ADD COLUMN IF NOT EXISTS course_code TEXT;

-- Create indexes for efficient course-based deck queries
CREATE INDEX IF NOT EXISTS idx_decks_course_code ON public.decks(course_code);
CREATE INDEX IF NOT EXISTS idx_decks_course_id ON public.decks(course_id);
