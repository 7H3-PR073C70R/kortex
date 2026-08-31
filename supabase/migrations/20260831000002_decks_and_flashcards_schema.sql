-- ==============================================================================
-- KORTEX SUPABASE MIGRATION: 002 - Decks, Flashcards & SM-2 Spaced Repetition
-- ==============================================================================

-- 1. Decks Table
CREATE TABLE IF NOT EXISTS public.decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    description TEXT,
    color_hex TEXT,
    icon_name TEXT,
    cover_image_url TEXT,
    total_cards INT NOT NULL DEFAULT 0,
    due_cards INT NOT NULL DEFAULT 0,
    mastery_rate DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    retention_rate DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    estimated_minutes INT NOT NULL DEFAULT 10,
    last_studied TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_decks_user_id ON public.decks(user_id);
CREATE INDEX IF NOT EXISTS idx_decks_category ON public.decks(category);

-- Enable RLS on decks
ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own decks"
    ON public.decks
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own decks"
    ON public.decks
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own decks"
    ON public.decks
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own decks"
    ON public.decks
    FOR DELETE
    USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS set_decks_updated_at ON public.decks;
CREATE TRIGGER set_decks_updated_at
    BEFORE UPDATE ON public.decks
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. Flashcards Table (with LaTeX & Vector Embedding)
CREATE TABLE IF NOT EXISTS public.flashcards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deck_id UUID NOT NULL REFERENCES public.decks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    front_latex TEXT,
    back_latex TEXT,
    interval INT NOT NULL DEFAULT 1,
    repetitions INT NOT NULL DEFAULT 0,
    ease_factor DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    last_reviewed TIMESTAMPTZ,
    next_due_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_topic TEXT,
    embedding vector(1536),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_flashcards_deck_id ON public.flashcards(deck_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_user_id ON public.flashcards(user_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_next_due_date ON public.flashcards(next_due_date);

-- HNSW Vector Index for Semantic Flashcard Search
CREATE INDEX IF NOT EXISTS idx_flashcards_embedding_hnsw 
    ON public.flashcards 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Enable RLS on flashcards
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own flashcards"
    ON public.flashcards
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own flashcards"
    ON public.flashcards
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flashcards"
    ON public.flashcards
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own flashcards"
    ON public.flashcards
    FOR DELETE
    USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS set_flashcards_updated_at ON public.flashcards;
CREATE TRIGGER set_flashcards_updated_at
    BEFORE UPDATE ON public.flashcards
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3. Session Results Table
CREATE TABLE IF NOT EXISTS public.session_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deck_id UUID NOT NULL REFERENCES public.decks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    cards_reviewed INT NOT NULL DEFAULT 0,
    duration_seconds INT NOT NULL DEFAULT 0,
    retention_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    xp_earned INT NOT NULL DEFAULT 50,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_results_user_id ON public.session_results(user_id);
CREATE INDEX IF NOT EXISTS idx_session_results_deck_id ON public.session_results(deck_id);

-- Enable RLS on session_results
ALTER TABLE public.session_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own session results"
    ON public.session_results
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session results"
    ON public.session_results
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 4. RPC Function: Process SM-2 Card Review
CREATE OR REPLACE FUNCTION public.process_card_sm2_review(
    p_card_id UUID,
    p_quality INT
)
RETURNS JSONB AS $$
DECLARE
    v_card RECORD;
    v_new_repetitions INT;
    v_new_interval INT;
    v_new_ease_factor DOUBLE PRECISION;
    v_next_due_date TIMESTAMPTZ;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- Fetch card and verify ownership
    SELECT * INTO v_card
    FROM public.flashcards
    WHERE id = p_card_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Card not found or access denied.';
    END IF;

    -- SM-2 Ease Factor Calculation: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    v_new_ease_factor := v_card.ease_factor + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02));
    IF v_new_ease_factor < 1.3 THEN
        v_new_ease_factor := 1.3;
    END IF;

    -- SM-2 Repetitions and Interval Calculation
    IF p_quality < 3 THEN
        -- Failure (Again)
        v_new_repetitions := 0;
        v_new_interval := 1;
    ELSE
        -- Success (Hard, Good, Easy)
        IF v_card.repetitions = 0 THEN
            v_new_interval := 1;
        ELSIF v_card.repetitions = 1 THEN
            v_new_interval := 6;
        ELSE
            v_new_interval := ROUND(v_card.interval * v_new_ease_factor);
        END IF;
        v_new_repetitions := v_card.repetitions + 1;
    END IF;

    v_next_due_date := v_now + (v_new_interval || ' days')::INTERVAL;

    -- Update Flashcard
    UPDATE public.flashcards
    SET interval = v_new_interval,
        repetitions = v_new_repetitions,
        ease_factor = v_new_ease_factor,
        last_reviewed = v_now,
        next_due_date = v_next_due_date,
        updated_at = v_now
    WHERE id = p_card_id;

    -- Refresh Deck Due Cards & Mastery
    UPDATE public.decks
    SET due_cards = (
            SELECT COUNT(*)
            FROM public.flashcards
            WHERE deck_id = v_card.deck_id AND next_due_date <= v_now
        ),
        total_cards = (
            SELECT COUNT(*)
            FROM public.flashcards
            WHERE deck_id = v_card.deck_id
        ),
        mastery_rate = (
            SELECT COALESCE(COUNT(*) FILTER (WHERE repetitions >= 3)::FLOAT / NULLIF(COUNT(*), 0), 0.0)
            FROM public.flashcards
            WHERE deck_id = v_card.deck_id
        ),
        last_studied = v_now
    WHERE id = v_card.deck_id;

    RETURN jsonb_build_object(
        'cardId', p_card_id,
        'nextInterval', v_new_interval,
        'newRepetitions', v_new_repetitions,
        'newEaseFactor', v_new_ease_factor,
        'nextDueDate', v_next_due_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC Function: Semantic Vector Search on Flashcards
CREATE OR REPLACE FUNCTION public.search_flashcards_semantic(
    p_query_embedding vector(1536),
    p_match_threshold FLOAT DEFAULT 0.65,
    p_match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    deck_id UUID,
    front TEXT,
    back TEXT,
    front_latex TEXT,
    back_latex TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.id,
        f.deck_id,
        f.front,
        f.back,
        f.front_latex,
        f.back_latex,
        1 - (f.embedding <=> p_query_embedding) AS similarity
    FROM public.flashcards f
    WHERE f.user_id = auth.uid()
      AND f.embedding IS NOT NULL
      AND 1 - (f.embedding <=> p_query_embedding) > p_match_threshold
    ORDER BY similarity DESC
    LIMIT p_match_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
