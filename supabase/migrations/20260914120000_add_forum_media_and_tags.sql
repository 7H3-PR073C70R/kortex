-- Migration: 20260914120000_add_forum_media_and_tags.sql
-- Description: Add tags, media_urls, voice_note_url, voice_note_duration_seconds, and is_anonymous columns to forum_posts and forum_replies

-- 1. Add columns to forum_posts
ALTER TABLE IF EXISTS public.forum_posts 
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS voice_note_url TEXT,
ADD COLUMN IF NOT EXISTS voice_note_duration_seconds INTEGER,
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

-- 2. Add columns to forum_replies
ALTER TABLE IF EXISTS public.forum_replies 
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS voice_note_url TEXT,
ADD COLUMN IF NOT EXISTS voice_note_duration_seconds INTEGER,
ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

-- 3. Create index for tags if not exists
CREATE INDEX IF NOT EXISTS idx_forum_posts_tags ON public.forum_posts USING GIN (tags);

-- 4. Reload PostgREST schema cache to immediately expose the new columns
NOTIFY pgrst, 'reload schema';
