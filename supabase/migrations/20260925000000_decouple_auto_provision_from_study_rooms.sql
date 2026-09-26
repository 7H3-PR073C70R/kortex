-- Decouple auto_provision_community_rpc from inserting static study_rooms rows.
-- Live focus rooms must be created on-demand by real users, not auto-provisioned as ghost DB entries.

DELETE FROM study_rooms
WHERE title ~* 'Silent Focus Room$'
   OR title ~* '^[0-9a-f]{16,}'
   OR title ~* '^[0-9a-f]{8}-[0-9a-f]{4}'
   OR subject ~* '^[0-9a-f]{16,}';

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
    v_is_founding BOOLEAN := false;
    v_normalized_code TEXT;
BEGIN
    v_user_id := auth.uid();
    v_normalized_code := upper(trim(p_course_code));

    IF v_normalized_code ~ '^[0-9A-F]{16,}$' OR v_normalized_code ~ '^[0-9A-F]{8}-[0-9A-F]{4}' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Ignored hash identifier');
    END IF;

    SELECT * INTO v_community FROM study_communities WHERE course_code = v_normalized_code;

    IF v_community.id IS NULL THEN
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
            0,
            0
        ) RETURNING id INTO v_community_id;

        v_is_founding := true;
    ELSE
        v_community_id := v_community.id;
        UPDATE study_communities
        SET member_count = member_count + 1
        WHERE id = v_community_id;
    END IF;

    IF v_user_id IS NOT NULL THEN
        INSERT INTO community_members (
            community_id,
            user_id,
            is_founding_member,
            role
        ) VALUES (
            v_community_id,
            v_user_id,
            v_is_founding,
            CASE WHEN v_is_founding THEN 'admin' ELSE 'member' END
        ) ON CONFLICT (community_id, user_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'community_id', v_community_id,
        'is_founding_member', v_is_founding
    );
END;
$$;
