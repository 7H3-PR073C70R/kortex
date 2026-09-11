-- Migration: Create Community & Peer Study Hub Tables, RLS, and RPCs
-- Modernized for Silent Focus, Study Circles, Peer Bounties, and League Gamification

-- 1. Live Study Rooms table (Silent Body Doubling + Focus Cockpit)
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
    ambient_sound_track TEXT NOT NULL DEFAULT 'lofi', -- lofi, rain, binaural, library, none
    active_goal TEXT,
    is_silent_focus BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Forum Posts table (Discussions, Notes & Question Bounties)
CREATE TABLE IF NOT EXISTS forum_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    track TEXT NOT NULL DEFAULT 'General', -- WAEC, JAMB, SAT, Engineering, Medicine, etc.
    syllabus_tag TEXT NOT NULL DEFAULT 'General',
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    latex_content TEXT,
    is_question BOOLEAN NOT NULL DEFAULT false,
    is_verified_solution BOOLEAN NOT NULL DEFAULT false,
    verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    upvotes INT NOT NULL DEFAULT 0,
    replies_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Forum Replies table (Answers with Verification)
CREATE TABLE IF NOT EXISTS forum_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    content TEXT NOT NULL,
    latex_content TEXT,
    is_verified_solution BOOLEAN NOT NULL DEFAULT false,
    upvotes INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Study Circles (Micro-Accountability Pods: 3-6 students)
CREATE TABLE IF NOT EXISTS study_circles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    track TEXT NOT NULL DEFAULT 'General',
    target_weekly_minutes INT NOT NULL DEFAULT 600,
    creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    max_members INT NOT NULL DEFAULT 6,
    member_count INT NOT NULL DEFAULT 1,
    total_minutes_completed INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Study Circle Members junction table
CREATE TABLE IF NOT EXISTS study_circle_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID NOT NULL REFERENCES study_circles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'member', -- creator, member
    weekly_minutes_contributed INT NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (circle_id, user_id)
);

-- 6. Shared Decks (Community Marketplace) table
CREATE TABLE IF NOT EXISTS shared_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_name TEXT NOT NULL,
    original_deck_id UUID,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    syllabus_tag TEXT NOT NULL DEFAULT 'General',
    description TEXT,
    category TEXT NOT NULL DEFAULT 'STEM',
    total_cards INT NOT NULL DEFAULT 0,
    downloads_count INT NOT NULL DEFAULT 0,
    rating DOUBLE PRECISION NOT NULL DEFAULT 4.8,
    cards JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Leaderboard Standings table (Tiered League System)
CREATE TABLE IF NOT EXISTS leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    avatar_url TEXT,
    track TEXT NOT NULL DEFAULT 'General',
    daily_xp INT NOT NULL DEFAULT 0,
    weekly_xp INT NOT NULL DEFAULT 0,
    streak_days INT NOT NULL DEFAULT 1,
    league_tier TEXT NOT NULL DEFAULT 'Bronze', -- Bronze, Silver, Gold, Diamond, Dean's List
    rank INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_study_rooms_category ON study_rooms(category);
CREATE INDEX IF NOT EXISTS idx_forum_posts_track ON forum_posts(track);
CREATE INDEX IF NOT EXISTS idx_forum_posts_is_question ON forum_posts(is_question);
CREATE INDEX IF NOT EXISTS idx_forum_replies_post_id ON forum_replies(post_id);
CREATE INDEX IF NOT EXISTS idx_study_circles_track ON study_circles(track);
CREATE INDEX IF NOT EXISTS idx_study_circle_members_user_id ON study_circle_members(user_id);
CREATE INDEX IF NOT EXISTS idx_study_circle_members_circle_id ON study_circle_members(circle_id);
CREATE INDEX IF NOT EXISTS idx_shared_decks_subject ON shared_decks(subject);
CREATE INDEX IF NOT EXISTS idx_leaderboards_track_xp ON leaderboards(track, weekly_xp DESC);

-- Enable RLS
ALTER TABLE study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;

-- Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE study_rooms, forum_posts, forum_replies, study_circles, study_circle_members, leaderboards;

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

-- Study Circles RLS
CREATE POLICY "Anyone can view study circles"
    ON study_circles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create study circles"
    ON study_circles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Circle creators can update circles"
    ON study_circles FOR UPDATE
    TO authenticated
    USING (auth.uid() = creator_id);

-- Study Circle Members RLS
CREATE POLICY "Anyone can view circle memberships"
    ON study_circle_members FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can join circles"
    ON study_circle_members FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave circles"
    ON study_circle_members FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

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

-- RPC: Verify Forum Reply (Awards +100 XP to solver and marks solution)
CREATE OR REPLACE FUNCTION verify_forum_reply(
    p_post_id UUID,
    p_reply_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_post RECORD;
    v_reply RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Fetch post
    SELECT * INTO v_post FROM forum_posts WHERE id = p_post_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Post not found';
    END IF;

    -- Only author can mark verified solution
    IF v_post.author_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the post author can verify a solution';
    END IF;

    -- Fetch reply
    SELECT * INTO v_reply FROM forum_replies WHERE id = p_reply_id AND post_id = p_post_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reply not found';
    END IF;

    -- Unmark any previously verified replies for this post
    UPDATE forum_replies
    SET is_verified_solution = false
    WHERE post_id = p_post_id;

    -- Mark this reply as verified
    UPDATE forum_replies
    SET is_verified_solution = true
    WHERE id = p_reply_id;

    -- Update post status
    UPDATE forum_posts
    SET is_verified_solution = true,
        verified_by = v_user_id,
        updated_at = now()
    WHERE id = p_post_id;

    -- Award +100 XP to solver
    UPDATE public.profiles
    SET xp_points = xp_points + 100
    WHERE id = v_reply.author_id;

    UPDATE public.leaderboards
    SET weekly_xp = weekly_xp + 100,
        updated_at = now()
    WHERE user_id = v_reply.author_id;

    RETURN jsonb_build_object(
        'success', true,
        'post_id', p_post_id,
        'verified_reply_id', p_reply_id,
        'solver_id', v_reply.author_id,
        'xp_awarded', 100
    );
END;
$$;

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

    -- Award creator 25 XP for sharing a deck that was cloned
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
