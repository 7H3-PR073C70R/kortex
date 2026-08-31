-- Migration: Create Community & Peer Study Hub Tables, RLS, and RPCs

-- 1. Live Study Rooms table
CREATE TABLE IF NOT EXISTS study_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    subject TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    pomodoro_duration_minutes INT NOT NULL DEFAULT 25,
    pomodoro_state TEXT NOT NULL DEFAULT 'focusing', -- focusing, break, paused
    pomodoro_started_at TIMESTAMPTZ DEFAULT now(),
    active_participants_count INT NOT NULL DEFAULT 1,
    max_participants INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Forum Posts table
CREATE TABLE IF NOT EXISTS forum_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    track TEXT NOT NULL DEFAULT 'General', -- WAEC, JAMB, SAT, Engineering, Medicine, etc.
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    latex_content TEXT,
    upvotes INT NOT NULL DEFAULT 0,
    replies_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Forum Replies table
CREATE TABLE IF NOT EXISTS forum_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    content TEXT NOT NULL,
    latex_content TEXT,
    upvotes INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Shared Decks (Community Marketplace) table
CREATE TABLE IF NOT EXISTS shared_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_name TEXT NOT NULL,
    original_deck_id UUID,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'STEM',
    total_cards INT NOT NULL DEFAULT 0,
    downloads_count INT NOT NULL DEFAULT 0,
    rating DOUBLE PRECISION NOT NULL DEFAULT 4.8,
    cards JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Leaderboard Standings table
CREATE TABLE IF NOT EXISTS leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    avatar_url TEXT,
    track TEXT NOT NULL DEFAULT 'General',
    daily_xp INT NOT NULL DEFAULT 0,
    weekly_xp INT NOT NULL DEFAULT 0,
    streak_days INT NOT NULL DEFAULT 1,
    rank INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_study_rooms_category ON study_rooms(category);
CREATE INDEX IF NOT EXISTS idx_forum_posts_track ON forum_posts(track);
CREATE INDEX IF NOT EXISTS idx_forum_replies_post_id ON forum_replies(post_id);
CREATE INDEX IF NOT EXISTS idx_shared_decks_subject ON shared_decks(subject);
CREATE INDEX IF NOT EXISTS idx_leaderboards_track_xp ON leaderboards(track, weekly_xp DESC);

-- Enable RLS
ALTER TABLE study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;

-- Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE study_rooms, forum_posts, leaderboards;

-- Study Rooms RLS
CREATE POLICY "Anyone can view study rooms"
    ON study_rooms FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create study rooms"
    ON study_rooms FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Room owners can update their rooms"
    ON study_rooms FOR UPDATE
    TO authenticated
    USING (auth.uid() = created_by);

CREATE POLICY "Room owners can delete their rooms"
    ON study_rooms FOR DELETE
    TO authenticated
    USING (auth.uid() = created_by);

-- Forum Posts RLS
CREATE POLICY "Anyone can view forum posts"
    ON forum_posts FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create forum posts"
    ON forum_posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own posts"
    ON forum_posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = author_id);

-- Forum Replies RLS
CREATE POLICY "Anyone can view forum replies"
    ON forum_replies FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create replies"
    ON forum_replies FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

-- Shared Decks RLS
CREATE POLICY "Anyone can view shared decks"
    ON shared_decks FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can publish shared decks"
    ON shared_decks FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = owner_id);

-- Leaderboards RLS
CREATE POLICY "Anyone can view leaderboards"
    ON leaderboards FOR SELECT
    TO authenticated
    USING (true);

-- RPC: Clone shared deck into user's private decks and flashcards
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

    -- 1. Create personal deck for user
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

    -- 2. Clone flashcards
    FOR v_card IN SELECT * FROM jsonb_array_elements(v_shared_deck.cards)
    LOOP
        INSERT INTO flashcards (
            deck_id,
            user_id,
            front,
            back,
            front_latex,
            back_latex,
            easiness_factor,
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

    -- 3. Increment downloads count on the shared deck
    UPDATE shared_decks
    SET downloads_count = downloads_count + 1
    WHERE id = p_shared_deck_id;

    RETURN jsonb_build_object(
        'success', true,
        'new_deck_id', v_new_deck_id,
        'cloned_cards_count', v_cards_inserted
    );
END;
$$;
