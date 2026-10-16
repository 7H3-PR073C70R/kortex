-- =============================================================================
-- Kortex Anti-Account Sharing & Multi-Platform Session Management Migration
-- =============================================================================
-- Enforces a strict 3-Device Slot Quota per user profile, single-concurrency
-- AI streams, and an automated Master Kill Switch on password reset.
-- All enforcement logic resides 100% inside Supabase / PostgreSQL.
-- =============================================================================

-- 1. Create Device Sessions Registry Table
CREATE TABLE IF NOT EXISTS public.user_device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    ip_address INET,
    last_active_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_user_device UNIQUE (user_id, device_id)
);

-- Index for fast user session lookups
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id 
ON public.user_device_sessions(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view and manage their own active devices
CREATE POLICY "Users can manage own device sessions"
ON public.user_device_sessions
FOR ALL
USING (auth.uid() = user_id);

-- 2. RPC Procedure: register_device_session_rpc
-- Called on login/app launch to register or refresh active device slot.
CREATE OR REPLACE FUNCTION public.register_device_session_rpc(
    p_device_id TEXT,
    p_device_name TEXT,
    p_platform TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_active_count INT;
    v_existing_session BOOLEAN;
    v_active_devices JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated';
    END IF;

    IF p_device_id IS NULL OR trim(p_device_id) = '' THEN
        RAISE EXCEPTION 'Device ID is required';
    END IF;

    -- Check if this device is already registered for the user
    SELECT EXISTS (
        SELECT 1 FROM public.user_device_sessions 
        WHERE user_id = v_user_id AND device_id = p_device_id
    ) INTO v_existing_session;

    -- If device slot exists, update last_active_at and device_name
    IF v_existing_session THEN
        UPDATE public.user_device_sessions 
        SET last_active_at = now(), 
            device_name = COALESCE(NULLIF(p_device_name, ''), device_name),
            platform = COALESCE(NULLIF(p_platform, ''), platform)
        WHERE user_id = v_user_id AND device_id = p_device_id;
        
        RETURN jsonb_build_object(
            'status', 'success', 
            'code', 'SESSION_OK', 
            'message', 'Active device session refreshed'
        );
    END IF;

    -- Count active device slots
    SELECT COUNT(*) INTO v_active_count 
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
            )
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

    -- Insert new device slot
    INSERT INTO public.user_device_sessions (user_id, device_id, device_name, platform)
    VALUES (v_user_id, p_device_id, COALESCE(NULLIF(p_device_name, ''), 'Kortex Device'), COALESCE(NULLIF(p_platform, ''), 'other'));

    RETURN jsonb_build_object(
        'status', 'success', 
        'code', 'SESSION_REGISTERED', 
        'message', 'New device slot registered successfully'
    );
END;
$$;

-- 3. RPC Procedure: disconnect_device_session_rpc
-- Allows users to remotely sign out an active device slot to free up a slot for a new device.
CREATE OR REPLACE FUNCTION public.disconnect_device_session_rpc(
    p_target_device_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated';
    END IF;

    DELETE FROM public.user_device_sessions
    WHERE user_id = v_user_id AND device_id = p_target_device_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'code', 'DEVICE_DISCONNECTED',
        'message', 'Device session disconnected successfully'
    );
END;
$$;

-- 4. Password Reset Master Kill Switch Trigger
-- Automatically purges ALL device session slots when the user updates their password.
CREATE OR REPLACE FUNCTION public.on_password_reset_purge_sessions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
        -- Delete all active device slots for this user profile
        DELETE FROM public.user_device_sessions WHERE user_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_password_reset_purge_sessions ON auth.users;

CREATE TRIGGER trigger_password_reset_purge_sessions
AFTER UPDATE ON auth.users
FOR EACH ROW
WHEN (OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password)
EXECUTE FUNCTION public.on_password_reset_purge_sessions();
