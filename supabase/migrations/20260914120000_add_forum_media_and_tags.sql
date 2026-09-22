
ALTER TABLE IF EXISTS public.forum_posts 
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS voice_note_url TEXT,
ADD COLUMN IF NOT EXISTS voice_note_duration_seconds INTEGER,
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS voice_note_url TEXT,
ADD COLUMN IF NOT EXISTS voice_note_duration_seconds INTEGER,
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_forum_posts_tags ON public.forum_posts USING GIN (tags);

NOTIFY pgrst, 'reload schema';
