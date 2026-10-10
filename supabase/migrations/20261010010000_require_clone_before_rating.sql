-- Create user_deck_clones table to track which users cloned which shared decks
CREATE TABLE IF NOT EXISTS user_deck_clones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shared_deck_id UUID NOT NULL REFERENCES shared_decks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, shared_deck_id)
);

CREATE INDEX IF NOT EXISTS idx_user_deck_clones_user_shared ON user_deck_clones(user_id, shared_deck_id);

ALTER TABLE user_deck_clones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cloned decks"
    ON user_deck_clones FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their deck clones"
    ON user_deck_clones FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Update clone_shared_deck to record in user_deck_clones
CREATE OR REPLACE FUNCTION clone_shared_deck(
    p_shared_deck_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_shared_deck RECORD;
    v_new_deck_id UUID;
    v_card JSONB;
    v_cards_inserted INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT * INTO v_shared_deck
    FROM shared_decks
    WHERE id = p_shared_deck_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shared deck not found';
    END IF;

    -- Record user clone relationship
    INSERT INTO user_deck_clones (user_id, shared_deck_id)
    VALUES (v_user_id, p_shared_deck_id)
    ON CONFLICT (user_id, shared_deck_id) DO NOTHING;

    INSERT INTO decks (
        user_id,
        title,
        subject,
        description,
        total_cards,
        due_cards,
        mastery_rate,
        category
    )
    VALUES (
        v_user_id,
        v_shared_deck.title,
        v_shared_deck.subject,
        COALESCE(v_shared_deck.description, 'Cloned from Community Marketplace'),
        v_shared_deck.total_cards,
        v_shared_deck.total_cards,
        0.0,
        v_shared_deck.category
    )
    RETURNING id INTO v_new_deck_id;

    FOR v_card IN SELECT * FROM jsonb_array_elements(v_shared_deck.cards)
    LOOP
        INSERT INTO flashcards (
            deck_id,
            user_id,
            front,
            back,
            front_latex,
            back_latex,
            ease_factor,
            interval,
            repetitions,
            next_due_date
        )
        VALUES (
            v_new_deck_id,
            v_user_id,
            COALESCE(v_card->>'front', 'Front'),
            COALESCE(v_card->>'back', 'Back'),
            v_card->>'front_latex',
            v_card->>'back_latex',
            2.5,
            0,
            0,
            now()
        );
        v_cards_inserted := v_cards_inserted + 1;
    END LOOP;

    UPDATE shared_decks
    SET downloads_count = downloads_count + 1
    WHERE id = p_shared_deck_id;

    UPDATE public.profiles
    SET xp_points = xp_points + 25
    WHERE id = v_shared_deck.owner_id;

    UPDATE public.leaderboards
    SET weekly_xp = weekly_xp + 25,
        updated_at = now()
    WHERE user_id = v_shared_deck.owner_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_deck_id', v_new_deck_id,
        'cloned_cards_count', v_cards_inserted
    );
END;
$$;

-- Update rate_shared_deck to enforce user MUST have cloned the deck
CREATE OR REPLACE FUNCTION rate_shared_deck(
    p_shared_deck_id UUID,
    p_rating DOUBLE PRECISION
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_deck RECORD;
    v_avg_rating DOUBLE PRECISION;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be authenticated to rate a deck';
    END IF;

    IF p_rating < 1.0 OR p_rating > 5.0 THEN
        RAISE EXCEPTION 'Invalid rating: Rating must be between 1.0 and 5.0';
    END IF;

    -- Fetch shared deck
    SELECT * INTO v_deck FROM shared_decks WHERE id = p_shared_deck_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shared deck not found';
    END IF;

    -- ENFORCE 1: Distributor / Owner cannot rate their own deck!
    IF v_deck.owner_id = v_user_id THEN
        RAISE EXCEPTION 'Distributors cannot rate their own published decks';
    END IF;

    -- ENFORCE 2: User MUST have cloned the deck first!
    IF NOT EXISTS (
        SELECT 1 FROM user_deck_clones
        WHERE user_id = v_user_id AND shared_deck_id = p_shared_deck_id
    ) THEN
        RAISE EXCEPTION 'You must clone this deck to your library before rating it';
    END IF;

    -- Upsert rating from this non-owner user
    INSERT INTO deck_ratings (shared_deck_id, user_id, rating, updated_at)
    VALUES (p_shared_deck_id, v_user_id, p_rating, now())
    ON CONFLICT (shared_deck_id, user_id)
    DO UPDATE SET rating = EXCLUDED.rating, updated_at = now();

    -- Calculate new average rating for the deck
    SELECT ROUND(AVG(rating)::numeric, 1) INTO v_avg_rating
    FROM deck_ratings
    WHERE shared_deck_id = p_shared_deck_id;

    -- Update shared_decks table with recalculated average
    UPDATE shared_decks
    SET rating = v_avg_rating,
        updated_at = now()
    WHERE id = p_shared_deck_id;

    RETURN jsonb_build_object(
        'success', true,
        'rating', v_avg_rating
    );
END;
$$;
