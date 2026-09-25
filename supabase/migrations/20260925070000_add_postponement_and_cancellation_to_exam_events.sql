-- Add postponement and cancellation tracking columns to public.exam_events

ALTER TABLE IF EXISTS public.exam_events
    ADD COLUMN IF NOT EXISTS is_postponed BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS original_target_date TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS postponed_reason TEXT NULL,
    ADD COLUMN IF NOT EXISTS is_cancelled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_exam_events_is_postponed ON public.exam_events(is_postponed);
CREATE INDEX IF NOT EXISTS idx_exam_events_is_cancelled ON public.exam_events(is_cancelled);

COMMENT ON COLUMN public.exam_events.is_postponed IS 'Flag indicating if the exam date was postponed from original_target_date';
COMMENT ON COLUMN public.exam_events.is_cancelled IS 'Flag indicating if the exam was cancelled';

-- Update recalculate_cram_pacing to set daily_target to 0 for cancelled exams
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

    IF v_exam.is_cancelled THEN
        v_new_daily_target := 0;
    ELSE
        v_days_remaining := GREATEST(1, (v_exam.target_date::date - CURRENT_DATE));
        v_remaining_cards := GREATEST(0, v_exam.total_cards_count - v_exam.mastered_cards_count);
        v_new_daily_target := CEIL((v_remaining_cards + (p_lapses * 1.5)) / v_days_remaining);
    END IF;

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
