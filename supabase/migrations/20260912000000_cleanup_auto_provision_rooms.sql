-- Cleanup auto-provisioned hash rooms and guard auto_provision_community_rpc

-- 1. Delete study rooms created from document hashes
DELETE FROM study_rooms
WHERE title ~* '^[0-9a-f]{16,}'
   OR title ~* '^[0-9a-f]{8}-[0-9a-f]{4}'
   OR subject ~* '^[0-9a-f]{16,}';

-- 2. Delete study communities created from document hashes
DELETE FROM study_communities
WHERE course_code ~* '^[0-9a-f]{16,}'
   OR course_code ~* '^[0-9a-f]{8}-[0-9a-f]{4}'
   OR title ~* '^[0-9a-f]{16,}';

-- 3. Update auto_provision_community_rpc to ignore document hash-like codes
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

    -- Do not provision for raw file hashes / object IDs
    IF v_normalized_code ~ '^[0-9A-F]{16,}$' OR v_normalized_code ~ '^[0-9A-F]{8}-[0-9A-F]{4}' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Ignored hash identifier');
    END IF;

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

        -- Create default 25m Silent Focus Pomodoro room
        INSERT INTO study_rooms (
            title,
            description,
            subject,
            category,
            pomodoro_duration_minutes,
            pomodoro_state,
            active_participants_count,
            ambient_sound_track,
            is_silent_focus,
            created_by
        ) VALUES (
            p_title || ' Silent Focus Room',
            'Synchronized silent co-working session for ' || p_title,
            v_normalized_code,
            p_department,
            25,
            'focusing',
            1,
            'lofi',
            true,
            v_user_id
        ) RETURNING id INTO v_room_id;

        UPDATE study_communities
        SET active_room_id = v_room_id,
            active_room_title = p_title || ' Silent Focus Room'
        WHERE id = v_community_id;

    ELSE
        v_community_id := v_community.id;
        -- Increment member count
        UPDATE study_communities
        SET member_count = member_count + 1
        WHERE id = v_community_id;
    END IF;

    -- Ensure user is a member of this community
    IF v_user_id IS NOT NULL THEN
        INSERT INTO community_members (community_id, user_id, role)
        VALUES (v_community_id, v_user_id, CASE WHEN v_is_founding THEN 'admin' ELSE 'member' END)
        ON CONFLICT (community_id, user_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'community_id', v_community_id,
        'course_code', v_normalized_code,
        'title', COALESCE(v_community.title, p_title),
        'active_room_id', COALESCE(v_community.active_room_id, v_room_id),
        'active_room_title', COALESCE(v_community.active_room_title, p_title || ' Silent Focus Room'),
        'is_user_member', true,
        'is_founding_member', v_is_founding
    );
END;
$$;
