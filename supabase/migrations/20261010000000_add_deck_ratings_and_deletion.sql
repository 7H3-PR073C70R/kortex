-- 1. Create deck_ratings table to store individual ratings by non-owner users
CREATE TABLE IF NOT EXISTS deck_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shared_deck_id UUID NOT NULL REFERENCES shared_decks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shared_deck_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_deck_ratings_deck_id ON deck_ratings(shared_deck_id);
CREATE INDEX IF NOT EXISTS idx_deck_ratings_user_id ON deck_ratings(user_id);

ALTER TABLE deck_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view deck ratings"
    ON deck_ratings FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own deck rating"
    ON deck_ratings FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own deck rating"
    ON deck_ratings FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own deck rating"
    ON deck_ratings FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. Add RLS Delete Policy on shared_decks for Deck Owners
DROP POLICY IF EXISTS "Owners can delete their shared decks" ON shared_decks;
CREATE POLICY "Owners can delete their shared decks"
    ON shared_decks FOR DELETE
    TO authenticated
    USING (auth.uid() = owner_id);

-- 3. Create rate_shared_deck RPC function
-- Prevents distributors (deck owners) from rating their own deck
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

    -- ENFORCE: Distributor / Owner cannot rate their own deck!
    IF v_deck.owner_id = v_user_id THEN
        RAISE EXCEPTION 'Distributors cannot rate their own published decks';
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

-- 4. Create delete_shared_deck RPC function
CREATE OR REPLACE FUNCTION delete_shared_deck(
    p_shared_deck_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_deck RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT * INTO v_deck FROM shared_decks WHERE id = p_shared_deck_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shared deck not found';
    END IF;

    IF v_deck.owner_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the deck owner can delete this deck from the marketplace';
    END IF;

    DELETE FROM shared_decks WHERE id = p_shared_deck_id;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_id', p_shared_deck_id
    );
END;
$$;
