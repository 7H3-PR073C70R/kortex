ALTER TABLE public.decks ADD COLUMN IF NOT EXISTS course_id TEXT;
ALTER TABLE public.decks ADD COLUMN IF NOT EXISTS course_code TEXT;

CREATE INDEX IF NOT EXISTS idx_decks_course_code ON public.decks(course_code);
CREATE INDEX IF NOT EXISTS idx_decks_course_id ON public.decks(course_id);
