-- Migration: 20261005000000_fix_clone_shared_deck_column_name.sql
-- Fix column name from 'easiness_factor' to 'ease_factor' in flashcards table insert

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
