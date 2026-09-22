
ALTER TABLE IF EXISTS public.exam_events
    ALTER COLUMN user_id SET DEFAULT auth.uid();

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

GRANT SELECT, INSERT, UPDATE, DELETE ON public.exam_events TO authenticated;
