-- Migration: Auto-Community Provisioning Engine & Triggers
-- Creates study_communities, community_members, RPC functions, and automated database triggers

-- 1. Study Communities table
CREATE TABLE IF NOT EXISTS study_communities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    department TEXT NOT NULL DEFAULT 'General',
    member_count INT NOT NULL DEFAULT 1,
    active_rooms_count INT NOT NULL DEFAULT 1,
    forum_threads_count INT NOT NULL DEFAULT 3,
    active_room_id UUID,
    active_room_title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Community Members junction table
CREATE TABLE IF NOT EXISTS community_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES study_communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_founding_member BOOLEAN NOT NULL DEFAULT false,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_study_communities_course_code ON study_communities(course_code);
CREATE INDEX IF NOT EXISTS idx_study_communities_department ON study_communities(department);
CREATE INDEX IF NOT EXISTS idx_community_members_user_id ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_community_id ON community_members(community_id);

-- Enable RLS
ALTER TABLE study_communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE study_communities, community_members;

-- RLS Policies for study_communities
DROP POLICY IF EXISTS "Anyone can view study communities" ON study_communities;
DROP POLICY IF EXISTS "Users can create study communities" ON study_communities;
DROP POLICY IF EXISTS "Service role or functions can update study communities" ON study_communities;

CREATE POLICY "Anyone can view study communities"
    ON study_communities FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can create study communities"
    ON study_communities FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Service role or functions can update study communities"
    ON study_communities FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- RLS Policies for community_members
DROP POLICY IF EXISTS "Anyone can view community memberships" ON community_members;
DROP POLICY IF EXISTS "Users can join communities" ON community_members;
DROP POLICY IF EXISTS "Users can leave communities" ON community_members;

CREATE POLICY "Anyone can view community memberships"
    ON community_members FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can join communities"
    ON community_members FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave communities"
    ON community_members FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 3. Idempotent Stored Function for Auto-Provisioning
CREATE OR REPLACE FUNCTION auto_provision_community_rpc(
    p_course_code TEXT,
    p_title TEXT,
    p_department TEXT DEFAULT 'General'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_community_id UUID;
    v_community RECORD;
    v_room_id UUID;
    v_is_founding BOOLEAN := false;
    v_normalized_code TEXT;
BEGIN
    v_user_id := auth.uid();
    v_normalized_code := upper(trim(p_course_code));

    -- Check if community exists
    SELECT * INTO v_community FROM study_communities WHERE course_code = v_normalized_code;

    IF v_community.id IS NULL THEN
        -- Create new community
        INSERT INTO study_communities (
            course_code,
            title,
            department,
            member_count,
            active_rooms_count,
            forum_threads_count
        ) VALUES (
            v_normalized_code,
            p_title,
            p_department,
            1,
            1,
            3
        ) RETURNING id INTO v_community_id;

        v_is_founding := true;

        -- Create default 25m Pomodoro room
        INSERT INTO study_rooms (
            title,
            description,
            subject,
            category,
            pomodoro_duration_minutes,
            pomodoro_state,
            active_participants_count,
            created_by
        ) VALUES (
            p_title || ' 25m Focus Room',
            'Synchronized study session for ' || p_title,
            v_normalized_code,
            p_department,
            25,
            'focusing',
            1,
            v_user_id
        ) RETURNING id INTO v_room_id;

        UPDATE study_communities
        SET active_room_id = v_room_id,
            active_room_title = p_title || ' 25m Focus Room'
        WHERE id = v_community_id;

        -- Create default forum discussion posts
        INSERT INTO forum_posts (
            author_id,
            author_name,
            track,
            title,
            content,
            upvotes
        ) VALUES
        (
            v_user_id,
            'Kortex Syllabot',
            p_department,
            'Welcome to ' || p_title || ' Peer Hub!',
            'This community was auto-created for students studying ' || v_normalized_code || '. Share past paper solutions and discuss topics here.',
            5
        ),
        (
            v_user_id,
            'Kortex AI',
            p_department,
            v_normalized_code || ' Past Paper Solutions & Discussion',
            'Post questions from past exams and compare steps with peers.',
            3
        ),
        (
            v_user_id,
            'Kortex AI',
            p_department,
            v_normalized_code || ' Cheat Sheets & Flashcard Decks',
            'Curated neural study notes and active recall decks for ' || v_normalized_code || '.',
            8
        );

    ELSE
        v_community_id := v_community.id;
        -- Increment member count
        UPDATE study_communities
        SET member_count = member_count + 1,
            updated_at = now()
        WHERE id = v_community_id;
    END IF;

    -- Add user to community_members if logged in
    IF v_user_id IS NOT NULL THEN
        INSERT INTO community_members (
            community_id,
            user_id,
            is_founding_member
        ) VALUES (
            v_community_id,
            v_user_id,
            v_is_founding
        ) ON CONFLICT (community_id, user_id) DO NOTHING;
    END IF;

    SELECT * INTO v_community FROM study_communities WHERE id = v_community_id;

    RETURN jsonb_build_object(
        'id', v_community.id,
        'course_code', v_community.course_code,
        'title', v_community.title,
        'department', v_community.department,
        'member_count', v_community.member_count,
        'active_rooms_count', v_community.active_rooms_count,
        'forum_threads_count', v_community.forum_threads_count,
        'active_room_id', v_community.active_room_id,
        'active_room_title', v_community.active_room_title,
        'is_user_member', true,
        'is_founding_member', v_is_founding
    );
END;
$$;

-- 4. Database Trigger on Onboarding Track Selection
CREATE OR REPLACE FUNCTION trigger_onboarding_track_provision()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.target_track IS NOT NULL AND (OLD.target_track IS NULL OR OLD.target_track <> NEW.target_track) THEN
        PERFORM auto_provision_community_rpc(
            NEW.target_track || '-STUDY-HUB',
            NEW.target_track || ' Peer Study Hub',
            NEW.target_track
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_user_profile_track_provision ON public.profiles;
CREATE TRIGGER tr_user_profile_track_provision
    AFTER INSERT OR UPDATE OF target_track ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION trigger_onboarding_track_provision();

-- 5. Database Trigger on Document Ingestion
CREATE OR REPLACE FUNCTION trigger_document_ingestion_provision()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_course_code TEXT;
BEGIN
    IF NEW.subject IS NOT NULL AND NEW.subject <> '' THEN
        v_course_code := upper(trim(NEW.subject));
        PERFORM auto_provision_community_rpc(
            v_course_code,
            v_course_code || ' Study Hub',
            'STEM'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_document_ingestion_provision ON documents;
CREATE TRIGGER tr_document_ingestion_provision
    AFTER INSERT ON documents
    FOR EACH ROW
    EXECUTE FUNCTION trigger_document_ingestion_provision();
