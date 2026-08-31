-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 018 - Idempotent FSRS Sync & Out-of-Order Resolution
-- ==============================================================================

-- 1. Alter Flashcards table to add FSRS vector columns and epoch timestamp tracking
ALTER TABLE public.flashcards
ADD COLUMN IF NOT EXISTS stability DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS difficulty DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS elapsed_days INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS scheduled_days INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS lapses INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS state INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_reviewed_epoch BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_transaction_id UUID;

-- 2. Create Study Review Logs table for granular audit trails & multi-device sync
CREATE TABLE IF NOT EXISTS public.study_review_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_uuid UUID NOT NULL,
    card_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 4),
    stability DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    difficulty DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    elapsed_days INT NOT NULL DEFAULT 0,
    scheduled_days INT NOT NULL DEFAULT 0,
    state INT NOT NULL DEFAULT 0,
    reviewed_at_utc TIMESTAMPTZ NOT NULL,
    reviewed_at_epoch BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_study_review_transaction UNIQUE (user_id, transaction_uuid)
);

CREATE INDEX IF NOT EXISTS idx_study_review_logs_user_id ON public.study_review_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_study_review_logs_card_id ON public.study_review_logs(card_id);
CREATE INDEX IF NOT EXISTS idx_study_review_logs_reviewed_at ON public.study_review_logs(reviewed_at_utc);

-- Enable RLS on study_review_logs
ALTER TABLE public.study_review_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own review logs"
    ON public.study_review_logs
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own review logs"
    ON public.study_review_logs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 3. RPC Function: Idempotent Batch FSRS Review Sync with Last-Write-Wins
CREATE OR REPLACE FUNCTION public.upsert_fsrs_review_batch(
    reviews JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_review RECORD;
    v_card RECORD;
    v_synced_count INT := 0;
    v_skipped_count INT := 0;
    v_out_of_order_count INT := 0;
    v_trans_uuid UUID;
    v_card_id UUID;
    v_rating INT;
    v_stability DOUBLE PRECISION;
    v_difficulty DOUBLE PRECISION;
    v_elapsed_days INT;
    v_scheduled_days INT;
    v_state INT;
    v_reviewed_utc TIMESTAMPTZ;
    v_reviewed_epoch BIGINT;
    v_next_due TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated Supabase JWT required.';
    END IF;

    IF reviews IS NULL OR jsonb_array_length(reviews) = 0 THEN
        RETURN jsonb_build_object(
            'status', 'success',
            'synced_count', 0,
            'skipped_count', 0
        );
    END IF;

    FOR v_review IN SELECT * FROM jsonb_to_recordset(reviews) AS x(
        transaction_uuid UUID,
        card_id UUID,
        rating INT,
        stability DOUBLE PRECISION,
        difficulty DOUBLE PRECISION,
        elapsed_days INT,
        scheduled_days INT,
        state INT,
        reviewed_at_utc TEXT,
        reviewed_at_epoch BIGINT
    )
    LOOP
        v_trans_uuid := v_review.transaction_uuid;
        v_card_id := v_review.card_id;
        v_rating := v_review.rating;
        v_stability := COALESCE(v_review.stability, 0.0);
        v_difficulty := COALESCE(v_review.difficulty, 0.0);
        v_elapsed_days := COALESCE(v_review.elapsed_days, 0);
        v_scheduled_days := COALESCE(v_review.scheduled_days, 1);
        v_state := COALESCE(v_review.state, 0);
        v_reviewed_utc := v_review.reviewed_at_utc::TIMESTAMPTZ;
        v_reviewed_epoch := COALESCE(v_review.reviewed_at_epoch, (EXTRACT(EPOCH FROM v_reviewed_utc) * 1000)::BIGINT);

        -- Check for duplicate transaction UUID (idempotency guard)
        IF EXISTS (
            SELECT 1 FROM public.study_review_logs 
            WHERE user_id = v_user_id AND transaction_uuid = v_trans_uuid
        ) THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;

        -- Record the review in the immutable audit log
        INSERT INTO public.study_review_logs (
            user_id,
            transaction_uuid,
            card_id,
            rating,
            stability,
            difficulty,
            elapsed_days,
            scheduled_days,
            state,
            reviewed_at_utc,
            reviewed_at_epoch
        ) VALUES (
            v_user_id,
            v_trans_uuid,
            v_card_id,
            v_rating,
            v_stability,
            v_difficulty,
            v_elapsed_days,
            v_scheduled_days,
            v_state,
            v_reviewed_utc,
            v_reviewed_epoch
        );

        -- Fetch current card state
        SELECT * INTO v_card
        FROM public.flashcards
        WHERE id = v_card_id AND user_id = v_user_id;

        IF FOUND THEN
            -- Check Last-Write-Wins policy based on reviewed_at_epoch
            IF v_card.last_reviewed_epoch IS NULL OR v_reviewed_epoch >= v_card.last_reviewed_epoch THEN
                v_next_due := v_reviewed_utc + (v_scheduled_days || ' days')::INTERVAL;

                UPDATE public.flashcards
                SET stability = v_stability,
                    difficulty = v_difficulty,
                    interval = v_scheduled_days,
                    repetitions = v_card.repetitions + 1,
                    lapses = CASE WHEN v_rating = 1 THEN v_card.lapses + 1 ELSE v_card.lapses END,
                    state = v_state,
                    last_reviewed = v_reviewed_utc,
                    last_reviewed_epoch = v_reviewed_epoch,
                    next_due_date = v_next_due,
                    last_transaction_id = v_trans_uuid,
                    updated_at = now()
                WHERE id = v_card_id;
            ELSE
                -- Out-of-order review: logged into audit trail, but card state is preserved
                v_out_of_order_count := v_out_of_order_count + 1;
            END IF;
        END IF;

        v_synced_count := v_synced_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'synced_count', v_synced_count,
        'skipped_duplicates', v_skipped_count,
        'out_of_order_logged', v_out_of_order_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
