-- ==============================================================================
-- Migration: 20260914020000_fix_exam_events_user_id_defaults_and_rls.sql
-- Description: Set default user_id to auth.uid() on exam_events table to avoid
-- RLS violation (42501 / new row violates row-level security policy for table "exam_events")
-- when creating/inserting exam events from authenticated client sessions.
-- ==============================================================================

-- 1. Set column default to auth.uid()
ALTER TABLE IF EXISTS public.exam_events
    ALTER COLUMN user_id SET DEFAULT auth.uid();

-- 2. Audit and update Row Level Security (RLS) policies for exam_events
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view own exam events" ON public.exam_events;
    CREATE POLICY "Users can view own exam events"
        ON public.exam_events FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can insert own exam events" ON public.exam_events;
    CREATE POLICY "Users can insert own exam events"
        ON public.exam_events FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id OR user_id = auth.uid());

    DROP POLICY IF EXISTS "Users can update own exam events" ON public.exam_events;
    CREATE POLICY "Users can update own exam events"
        ON public.exam_events FOR UPDATE
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Users can delete own exam events" ON public.exam_events;
    CREATE POLICY "Users can delete own exam events"
        ON public.exam_events FOR DELETE
        TO authenticated
        USING (auth.uid() = user_id);
END $$;

-- 3. Explicitly grant table permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exam_events TO authenticated;
