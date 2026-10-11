-- ============================================================================
-- Migration: 20261012050000_harden_device_sessions.sql
-- Description: P2-03 Device Session Limits: Auto-Expiration & Atomic Allocation
--
-- 1. Updates register_device_session_rpc with:
--    - pg_advisory_xact_lock to eliminate concurrency race conditions.
--    - 30-day auto-pruning of abandoned/inactive device slots.
--    - Atomic 3-device slot quota enforcement.
-- 2. Adds/updates revoke_device_session and disconnect_device_session_rpc.
-- 3. Hardens search_path and enforces least privilege permissions.
-- ============================================================================

-- 1. Hardened Atomic register_device_session_rpc
CREATE OR REPLACE FUNCTION public.register_device_session_rpc(
    p_device_id TEXT,
    p_device_name TEXT,
    p_platform TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_active_count INT;
    v_existing_session BOOLEAN := false;
    v_active_devices JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated: User session required';
    END IF;

    IF p_device_id IS NULL OR trim(p_device_id) = '' THEN
        RAISE EXCEPTION 'Device ID is required';
    END IF;

    -- Concurrency Protection: Acquire advisory transaction lock for this user
    -- Eliminates race conditions when multiple devices register simultaneously.
    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    -- Auto-pruning: Expire inactive device sessions older than 30 days
    DELETE FROM public.user_device_sessions
    WHERE user_id = v_user_id
      AND last_active_at < (now() - INTERVAL '30 days');

    -- Check if this specific device is already registered for this user
    SELECT EXISTS (
        SELECT 1 FROM public.user_device_sessions 
        WHERE user_id = v_user_id AND device_id = p_device_id
    ) INTO v_existing_session;

    -- If device slot exists, refresh last_active_at and metadata
    IF v_existing_session THEN
        UPDATE public.user_device_sessions 
        SET last_active_at = now(), 
            device_name = COALESCE(NULLIF(trim(p_device_name), ''), device_name),
            platform = COALESCE(NULLIF(trim(p_platform), ''), platform)
        WHERE user_id = v_user_id AND device_id = p_device_id;
        
        RETURN jsonb_build_object(
            'status', 'success', 
            'code', 'SESSION_OK', 
            'message', 'Active device session refreshed',
            'device_id', p_device_id
        );
    END IF;

    -- Count active device slots for the user
    SELECT COUNT(*)::INT INTO v_active_count 
    FROM public.user_device_sessions 
    WHERE user_id = v_user_id;

    -- Enforce 3-Device Slot Quota
    IF v_active_count >= 3 THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', id,
                'device_id', device_id,
                'device_name', device_name,
                'platform', platform,
                'last_active_at', last_active_at
            ) ORDER BY last_active_at ASC
        ) INTO v_active_devices
        FROM public.user_device_sessions
        WHERE user_id = v_user_id;

        RETURN jsonb_build_object(
            'status', 'error',
            'code', 'DEVICE_LIMIT_EXCEEDED',
            'message', 'Maximum active device limit (3) reached for this profile.',
            'active_devices', COALESCE(v_active_devices, '[]'::jsonb)
        );
    END IF;

    -- Insert new device slot atomically
    INSERT INTO public.user_device_sessions (
        user_id, device_id, device_name, platform, last_active_at, created_at
    )
    VALUES (
        v_user_id, 
        p_device_id, 
        COALESCE(NULLIF(trim(p_device_name), ''), 'Kortex Device'), 
        COALESCE(NULLIF(trim(p_platform), ''), 'other'),
        now(),
        now()
    );

    RETURN jsonb_build_object(
        'status', 'success', 
        'code', 'SESSION_REGISTERED', 
        'message', 'New device slot registered successfully',
        'device_id', p_device_id
    );
END;
$$;

-- 2. Revoke Device Session Procedure
CREATE OR REPLACE FUNCTION public.revoke_device_session(
    p_target_device_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_deleted_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated: User session required';
    END IF;

    IF p_target_device_id IS NULL OR trim(p_target_device_id) = '' THEN
        RAISE EXCEPTION 'Target device ID is required';
    END IF;

    DELETE FROM public.user_device_sessions
    WHERE user_id = v_user_id AND device_id = p_target_device_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'status', 'success',
        'code', 'DEVICE_REVOKED',
        'message', 'Device session revoked successfully',
        'device_id', p_target_device_id,
        'revoked', (v_deleted_count > 0)
    );
END;
$$;

-- 3. Backward-Compatible Alias: disconnect_device_session_rpc
CREATE OR REPLACE FUNCTION public.disconnect_device_session_rpc(
    p_target_device_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    RETURN public.revoke_device_session(p_target_device_id);
END;
$$;

-- 4. Permissions Hardening
REVOKE EXECUTE ON FUNCTION public.register_device_session_rpc(TEXT, TEXT, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_device_session_rpc(TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.revoke_device_session(TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_device_session(TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.disconnect_device_session_rpc(TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.disconnect_device_session_rpc(TEXT) TO authenticated, service_role;
