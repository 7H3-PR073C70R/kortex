-- Migration: 20261012080000_harden_livekit_room_access.sql
-- Description: Room-scoped LiveKit token verification and authorization helper RPC.
-- Enforces server-authoritative membership verification for private study circles/pods,
-- course study communities, and study rooms, enforcing silent room publish restrictions.

-- 1. Create compatibility views for study_pod_members and study_community_members
CREATE OR REPLACE VIEW public.study_pod_members AS
SELECT 
    id,
    circle_id AS pod_id,
    user_id,
    user_name,
    avatar_url,
    role,
    weekly_minutes_contributed,
    joined_at
FROM public.study_circle_members;

CREATE OR REPLACE VIEW public.study_community_members AS
SELECT 
    id,
    community_id,
    user_id,
    role,
    is_founding_member,
    joined_at
FROM public.community_members;

-- 2. Secure function to validate user room access and resolve LiveKit claims
CREATE OR REPLACE FUNCTION public.check_livekit_room_access(
    p_room_id TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_room_uuid UUID;
    v_display_name TEXT;
    v_pod_exists BOOLEAN := false;
    v_pod_member RECORD;
    v_comm_exists BOOLEAN := false;
    v_comm_member RECORD;
    v_room_record RECORD;
    v_can_publish BOOLEAN := false;
    v_role TEXT := 'participant';
BEGIN
    IF p_room_id IS NULL OR p_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'error', 'Missing room or user identifier'
        );
    END IF;

    -- Validate UUID format
    IF p_room_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_room_uuid := p_room_id::UUID;
    ELSE
        RETURN jsonb_build_object(
            'allowed', false,
            'error', 'Invalid room identifier format'
        );
    END IF;

    -- Resolve authoritative display name from profiles or auth metadata
    SELECT COALESCE(
        NULLIF(trim(p.display_name), ''),
        NULLIF(trim(u.raw_user_meta_data->>'display_name'), ''),
        'Scholar'
    )
    INTO v_display_name
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE u.id = p_user_id;

    IF v_display_name IS NULL THEN
        v_display_name := 'Scholar';
    END IF;

    -- Case A: Check if room_id is a private Study Pod / Study Circle
    SELECT EXISTS (SELECT 1 FROM public.study_circles WHERE id = v_room_uuid) INTO v_pod_exists;
    IF v_pod_exists THEN
        SELECT role INTO v_pod_member 
        FROM public.study_circle_members 
        WHERE circle_id = v_room_uuid AND user_id = p_user_id;

        IF v_pod_member IS NOT NULL THEN
            -- User is an active member of this private pod
            RETURN jsonb_build_object(
                'allowed', true,
                'room_type', 'study_pod',
                'can_publish', true,
                'display_name', v_display_name,
                'role', COALESCE(v_pod_member.role, 'member')
            );
        ELSE
            -- Forbidden: Non-members cannot access private study pod
            RETURN jsonb_build_object(
                'allowed', false,
                'error', 'Forbidden: You are not an active member of this study pod',
                'room_type', 'study_pod'
            );
        END IF;
    END IF;

    -- Case B: Check if room_id is a Study Community
    SELECT EXISTS (SELECT 1 FROM public.study_communities WHERE id = v_room_uuid) INTO v_comm_exists;
    IF v_comm_exists THEN
        SELECT role INTO v_comm_member 
        FROM public.community_members 
        WHERE community_id = v_room_uuid AND user_id = p_user_id;

        IF v_comm_member IS NOT NULL THEN
            -- In community audio stages, only leaders/moderators/speakers publish by default
            v_can_publish := (v_comm_member.role IN ('admin', 'moderator', 'creator', 'speaker'));
            RETURN jsonb_build_object(
                'allowed', true,
                'room_type', 'study_community',
                'can_publish', v_can_publish,
                'display_name', v_display_name,
                'role', COALESCE(v_comm_member.role, 'member')
            );
        ELSE
            -- Forbidden: Non-members cannot join community voice channels
            RETURN jsonb_build_object(
                'allowed', false,
                'error', 'Forbidden: You are not a member of this study community',
                'room_type', 'study_community'
            );
        END IF;
    END IF;

    -- Case C: Check if room_id is a general Study Room
    SELECT * INTO v_room_record FROM public.study_rooms WHERE id = v_room_uuid;
    IF v_room_record.id IS NOT NULL THEN
        IF v_room_record.created_by = p_user_id THEN
            -- Host/creator can always speak and moderate
            v_can_publish := true;
            v_role := 'host';
        ELSE
            -- If silent focus is enabled, non-host participants are listen-only
            v_can_publish := NOT v_room_record.is_silent_focus;
            v_role := 'participant';
        END IF;

        RETURN jsonb_build_object(
            'allowed', true,
            'room_type', 'study_room',
            'can_publish', v_can_publish,
            'display_name', v_display_name,
            'role', v_role
        );
    END IF;

    -- Case D: Room not found in any room registry
    RETURN jsonb_build_object(
        'allowed', false,
        'error', 'Room not found or access denied',
        'room_type', 'unknown'
    );
END;
$$;

-- 3. Lock down permissions: Revoke from public/anon, grant to authenticated & service_role
REVOKE EXECUTE ON FUNCTION public.check_livekit_room_access(TEXT, UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_livekit_room_access(TEXT, UUID) TO authenticated, service_role;
