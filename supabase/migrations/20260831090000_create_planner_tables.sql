-- Migration: Exam Countdown & Dynamic Cram Planner Engine
-- Creates exam_events table, RLS policies, indexing, and pacing recalculation RPC.

-- 1. Create exam_events table
CREATE TABLE IF NOT EXISTS public.exam_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exam_name TEXT NOT NULL,
    target_date DATE NOT NULL,
    subject_track TEXT NOT NULL DEFAULT 'General',
    total_cards_count INT NOT NULL DEFAULT 0,
    mastered_cards_count INT NOT NULL DEFAULT 0,
    total_lapses INT NOT NULL DEFAULT 0,
    daily_target INT NOT NULL DEFAULT 20,
    target_score_percent FLOAT NOT NULL DEFAULT 0.85,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes for fast user queries and deadline lookups
CREATE INDEX IF NOT EXISTS idx_exam_events_user_id ON public.exam_events(user_id);
CREATE INDEX IF NOT EXISTS idx_exam_events_target_date ON public.exam_events(target_date);
CREATE INDEX IF NOT EXISTS idx_exam_events_subject_track ON public.exam_events(subject_track);

-- 3. Enable RLS & Realtime
ALTER TABLE public.exam_events ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE public.exam_events;

-- 4. Strict Row Level Security Policies
DROP POLICY IF EXISTS "Users can view own exam events" ON public.exam_events;
DROP POLICY IF EXISTS "Users can insert own exam events" ON public.exam_events;
DROP POLICY IF EXISTS "Users can update own exam events" ON public.exam_events;
DROP POLICY IF EXISTS "Users can delete own exam events" ON public.exam_events;

CREATE POLICY "Users can view own exam events"
    ON public.exam_events FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own exam events"
    ON public.exam_events FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own exam events"
    ON public.exam_events FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own exam events"
    ON public.exam_events FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 5. Stored Function for Recalculating Cram Pacing on Missed Days
CREATE OR REPLACE FUNCTION public.recalculate_cram_pacing(
    p_exam_id UUID,
    p_lapses INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_exam RECORD;
    v_days_remaining INT;
    v_remaining_cards INT;
    v_new_daily_target INT;
    v_result JSONB;
BEGIN
    SELECT * INTO v_exam
    FROM public.exam_events
    WHERE id = p_exam_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Exam event not found or unauthorized';
    END IF;

    v_days_remaining := GREATEST(1, (v_exam.target_date - CURRENT_DATE));
    v_remaining_cards := GREATEST(0, v_exam.total_cards_count - v_exam.mastered_cards_count);
    
    -- Formula: ceil((Remaining Cards + (Lapses * 1.5)) / Days Remaining)
    v_new_daily_target := CEIL((v_remaining_cards + (p_lapses * 1.5)) / v_days_remaining);

    UPDATE public.exam_events
    SET
        total_lapses = p_lapses,
        daily_target = v_new_daily_target,
        updated_at = now()
    WHERE id = p_exam_id;

    SELECT to_jsonb(e) INTO v_result
    FROM public.exam_events e
    WHERE e.id = p_exam_id;

    RETURN v_result;
END;
$$;
