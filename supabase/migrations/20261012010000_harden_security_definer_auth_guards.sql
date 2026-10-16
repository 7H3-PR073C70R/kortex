-- ==============================================================================
-- KORTEX SECURITY HARDENING: 20261012010000
-- Enforce auth.uid() Ownership and SET search_path Across SECURITY DEFINER RPCs
-- Eliminates cross-user privilege escalation, arbitrary XP/ELO manipulation,
-- notification spam/phishing, and search_path hijacking vulnerabilities.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Helper Function: Check if caller is executing with service_role privilege
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_service_role_caller()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(
        current_setting('request.jwt.claim.role', true) = 'service_role',
        (auth.jwt()->>'role') = 'service_role',
        false
    );
$$;

REVOKE EXECUTE ON FUNCTION public.is_service_role_caller() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_service_role_caller() TO service_role;

-- ------------------------------------------------------------------------------
-- 2. award_user_xp: Enforce caller ownership, role check, and transaction bounds
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_user_xp(
    p_user_id UUID,
    p_amount INT,
    p_category TEXT,
    p_source_id TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN;
    v_caller_id UUID;
    v_streak INT := 0;
    v_multiplier NUMERIC(3,2) := 1.00;
    v_final_xp INT := 0;
    v_new_total_xp INT := 0;
BEGIN
    v_is_service := public.is_service_role_caller();
    v_caller_id := auth.uid();

    -- Authorization Guard
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL OR v_caller_id <> p_user_id THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Cannot award XP to another user';
        END IF;

        -- Ceiling on client-initiated award per transaction
        IF p_amount > 500 THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Client XP award exceeds transaction ceiling (500)';
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'XP amount must be positive');
    END IF;

    -- Fetch current streak for multiplier calculation
    SELECT COALESCE(current_streak_days, 0)
    INTO v_streak
    FROM public.user_analytics
    WHERE user_id = p_user_id;

    -- Calculate streak multiplier
    IF v_streak >= 30 THEN
        v_multiplier := 2.00;
    ELSIF v_streak >= 14 THEN
        v_multiplier := 1.75;
    ELSIF v_streak >= 7 THEN
        v_multiplier := 1.50;
    ELSIF v_streak >= 4 THEN
        v_multiplier := 1.25;
    ELSE
        v_multiplier := 1.00;
    END IF;

    v_final_xp := ROUND(p_amount * v_multiplier);

    -- 1. Insert XP transaction log
    INSERT INTO public.user_xp_transactions (
        user_id,
        amount,
        category,
        source_id,
        multiplier,
        metadata
    ) VALUES (
        p_user_id,
        v_final_xp,
        p_category,
        p_source_id,
        v_multiplier,
        p_metadata
    );

    -- 2. Update user analytics xp_points atomically
    INSERT INTO public.user_analytics (user_id, xp_points)
    VALUES (p_user_id, v_final_xp)
    ON CONFLICT (user_id) DO UPDATE
    SET xp_points = COALESCE(user_analytics.xp_points, 0) + v_final_xp,
        updated_at = now()
    RETURNING xp_points INTO v_new_total_xp;

    -- 3. Sync to public leaderboards
    PERFORM public.sync_profile_to_leaderboard(p_user_id, v_new_total_xp);

    RETURN jsonb_build_object(
        'success', true,
        'awarded_xp', v_final_xp,
        'base_xp', p_amount,
        'multiplier', v_multiplier,
        'new_total_xp', v_new_total_xp
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. purchase_streak_freeze: Atomic row lock, ownership verification & XP debit
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purchase_streak_freeze(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN;
    v_caller_id UUID;
    v_current_xp INT;
    v_current_freezes INT;
    v_cost CONSTANT INT := 200;
    v_new_xp INT;
BEGIN
    v_is_service := public.is_service_role_caller();
    v_caller_id := auth.uid();

    -- Authorization Guard
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL OR v_caller_id <> p_user_id THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Cannot purchase streak freeze for another user';
        END IF;
    END IF;

    -- Row-level locking to prevent concurrent balance draining race conditions
    SELECT xp_points, COALESCE(streak_freezes_available, 0)
    INTO v_current_xp, v_current_freezes
    FROM public.user_analytics
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_current_xp IS NULL OR v_current_xp < v_cost THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Insufficient XP points to purchase Streak Freeze'
        );
    END IF;

    v_new_xp := v_current_xp - v_cost;

    -- Update user analytics state
    UPDATE public.user_analytics
    SET xp_points = v_new_xp,
        streak_freezes_available = v_current_freezes + 1,
        streak_freeze_active = true,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Also deduct from user profiles table for balance consistency
    UPDATE public.profiles
    SET xp_points = GREATEST(0, COALESCE(xp_points, 0) - v_cost),
        updated_at = now()
    WHERE id = p_user_id;

    -- Record transaction debit in audit log
    INSERT INTO public.user_xp_transactions (
        user_id,
        amount,
        category,
        source_id,
        multiplier,
        metadata
    ) VALUES (
        p_user_id,
        -v_cost,
        'streak_freeze_purchase',
        'shop',
        1.00,
        jsonb_build_object('cost', v_cost, 'previous_xp', v_current_xp)
    );

    -- Sync updated XP to leaderboards
    PERFORM public.sync_profile_to_leaderboard(p_user_id, v_new_xp);

    RETURN jsonb_build_object(
        'success', true,
        'remaining_xp', v_new_xp,
        'streak_freezes_available', v_current_freezes + 1,
        'message', 'Streak Freeze equipped successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. fn_process_quiz_duel_outcome: Participant guard, idempotency & Elo update
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_process_quiz_duel_outcome(
    p_duel_id TEXT,
    p_player1_id UUID,
    p_player2_id UUID,
    p_player1_score INT,
    p_player2_score INT,
    p_winner_id UUID DEFAULT NULL,
    p_is_draw BOOLEAN DEFAULT FALSE,
    p_is_forfeit BOOLEAN DEFAULT FALSE,
    p_forfeit_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN;
    v_caller_id UUID;
    v_duel RECORD;
    v_p1_elo INT := 1200;
    v_p2_elo INT := 1200;
    v_expected_p1 FLOAT;
    v_expected_p2 FLOAT;
    v_actual_p1 FLOAT;
    v_actual_p2 FLOAT;
    v_k_factor CONSTANT INT := 32;
    v_new_p1_elo INT;
    v_new_p2_elo INT;
    v_subject TEXT := 'Quiz Duel';
    v_result JSONB;
BEGIN
    v_is_service := public.is_service_role_caller();
    v_caller_id := auth.uid();

    -- Authorization Guard: Caller must be service_role or one of the duel participants
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL OR (v_caller_id <> p_player1_id AND (p_player2_id IS NULL OR v_caller_id <> p_player2_id)) THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Caller is not a participant in this quiz duel';
        END IF;
    END IF;

    -- Validate scores are non-negative
    IF p_player1_score < 0 OR p_player2_score < 0 THEN
        RAISE EXCEPTION 'Invalid scores: scores must be non-negative';
    END IF;

    -- Check if duel was already finalized (Idempotency Protection)
    SELECT * INTO v_duel
    FROM public.quiz_duels
    WHERE duel_id = p_duel_id
    FOR UPDATE;

    IF FOUND AND v_duel.player1_elo_after IS NOT NULL THEN
        -- Duel was already processed. Return cached result without reapplying ELO changes or duplicate notifications.
        RETURN jsonb_build_object(
            'duel_id', p_duel_id,
            'status', 'ALREADY_PROCESSED',
            'player1_id', v_duel.player1_id,
            'player1_elo_before', v_duel.player1_elo_before,
            'player1_elo_after', v_duel.player1_elo_after,
            'player2_id', v_duel.player2_id,
            'player2_elo_before', v_duel.player2_elo_before,
            'player2_elo_after', v_duel.player2_elo_after
        );
    END IF;

    -- Fetch existing ELO for Player 1
    SELECT COALESCE(elo_rating, 1200) INTO v_p1_elo
    FROM public.profiles
    WHERE id = p_player1_id;

    -- Fetch existing ELO for Player 2 (if real user)
    IF p_player2_id IS NOT NULL THEN
        SELECT COALESCE(elo_rating, 1200) INTO v_p2_elo
        FROM public.profiles
        WHERE id = p_player2_id;
    ELSE
        v_p2_elo := 1200;
    END IF;

    -- Fetch subject if recorded in duel
    IF FOUND AND v_duel.subject IS NOT NULL THEN
        v_subject := v_duel.subject;
    END IF;

    -- Calculate expected scores using standard Elo rating formula
    v_expected_p1 := 1.0 / (1.0 + POWER(10.0, (v_p2_elo - v_p1_elo)::FLOAT / 400.0));
    v_expected_p2 := 1.0 / (1.0 + POWER(10.0, (v_p1_elo - v_p2_elo)::FLOAT / 400.0));

    -- Determine actual scores (1 = Win, 0.5 = Draw, 0 = Loss)
    IF p_is_draw THEN
        v_actual_p1 := 0.5;
        v_actual_p2 := 0.5;
    ELSIF p_winner_id = p_player1_id THEN
        v_actual_p1 := 1.0;
        v_actual_p2 := 0.0;
    ELSE
        v_actual_p1 := 0.0;
        v_actual_p2 := 1.0;
    END IF;

    -- Calculate new ELO ratings
    v_new_p1_elo := GREATEST(100, ROUND(v_p1_elo + v_k_factor * (v_actual_p1 - v_expected_p1)));
    v_new_p2_elo := GREATEST(100, ROUND(v_p2_elo + v_k_factor * (v_actual_p2 - v_expected_p2)));

    -- Update user profiles with new ELO
    UPDATE public.profiles
    SET elo_rating = v_new_p1_elo
    WHERE id = p_player1_id;

    IF p_player2_id IS NOT NULL THEN
        UPDATE public.profiles
        SET elo_rating = v_new_p2_elo
        WHERE id = p_player2_id;
    END IF;

    -- Update quiz_duels record with finalized outcome
    UPDATE public.quiz_duels
    SET player1_score = p_player1_score,
        player2_score = p_player2_score,
        player1_elo_before = v_p1_elo,
        player2_elo_before = v_p2_elo,
        player1_elo_after = v_new_p1_elo,
        player2_elo_after = v_new_p2_elo,
        winner_user_id = p_winner_id,
        is_draw = p_is_draw,
        is_forfeit = p_is_forfeit,
        forfeit_user_id = p_forfeit_user_id,
        finished_at = now()
    WHERE duel_id = p_duel_id;

    -- Dispatch Player 1 outcome notification
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        p_player1_id,
        CASE
            WHEN p_is_draw THEN '🤝 Quiz Duel Draw!'
            WHEN p_winner_id = p_player1_id THEN '🏆 You won the Quiz Duel!'
            ELSE '📚 Quiz Duel Complete'
        END,
        CASE
            WHEN p_is_draw THEN format('Close battle in %s! Final score: %s - %s. New ELO: %s.', v_subject, p_player1_score, p_player2_score, v_new_p1_elo)
            WHEN p_winner_id = p_player1_id THEN format('Victory in %s! Score: %s - %s. New ELO: %s (+%s).', v_subject, p_player1_score, p_player2_score, v_new_p1_elo, v_new_p1_elo - v_p1_elo)
            ELSE format('Good match in %s! Score: %s - %s. New ELO: %s (%s). Tap to review missed questions.', v_subject, p_player1_score, p_player2_score, v_new_p1_elo, v_new_p1_elo - v_p1_elo)
        END,
        'quiz_duel_result',
        jsonb_build_object(
            'duelId', p_duel_id,
            'result', CASE WHEN p_is_draw THEN 'draw' WHEN p_winner_id = p_player1_id THEN 'win' ELSE 'loss' END,
            'eloBefore', v_p1_elo,
            'eloAfter', v_new_p1_elo,
            'route', '/quiz-duel',
            'action', 'quiz_duel_result'
        )
    );

    -- Dispatch Player 2 outcome notification (if real user)
    IF p_player2_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            p_player2_id,
            CASE
                WHEN p_is_draw THEN '🤝 Quiz Duel Draw!'
                WHEN p_winner_id = p_player2_id THEN '🏆 You won the Quiz Duel!'
                ELSE '📚 Quiz Duel Complete'
            END,
            CASE
                WHEN p_is_draw THEN format('Close battle in %s! Final score: %s - %s. New ELO: %s.', v_subject, p_player2_score, p_player1_score, v_new_p2_elo)
                WHEN p_winner_id = p_player2_id THEN format('Victory in %s! Score: %s - %s. New ELO: %s (+%s).', v_subject, p_player2_score, p_player1_score, v_new_p2_elo, v_new_p2_elo - v_p2_elo)
                ELSE format('Good match in %s! Score: %s - %s. New ELO: %s (%s). Tap to review missed questions.', v_subject, p_player2_score, p_player1_score, v_new_p2_elo, v_new_p2_elo - v_p2_elo)
            END,
            'quiz_duel_result',
            jsonb_build_object(
                'duelId', p_duel_id,
                'result', CASE WHEN p_is_draw THEN 'draw' WHEN p_winner_id = p_player2_id THEN 'win' ELSE 'loss' END,
                'eloBefore', v_p2_elo,
                'eloAfter', v_new_p2_elo,
                'route', '/quiz-duel',
                'action', 'quiz_duel_result'
            )
        );
    END IF;

    -- Return outcome summary JSON
    v_result := jsonb_build_object(
        'duel_id', p_duel_id,
        'player1_id', p_player1_id,
        'player1_elo_before', v_p1_elo,
        'player1_elo_after', v_new_p1_elo,
        'player1_elo_diff', v_new_p1_elo - v_p1_elo,
        'player2_id', p_player2_id,
        'player2_elo_before', v_p2_elo,
        'player2_elo_after', v_new_p2_elo,
        'player2_elo_diff', v_new_p2_elo - v_p2_elo
    );

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. send_tailored_notification: Foreign account guard & service_role restriction
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_tailored_notification(
    p_target_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_category TEXT DEFAULT 'general',
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service BOOLEAN;
    v_caller_id UUID;
    v_notif_id UUID;
    v_pref_allowed BOOLEAN := true;
BEGIN
    v_is_service := public.is_service_role_caller();
    v_caller_id := auth.uid();

    -- Authorization Guard: Clients cannot dispatch notifications to arbitrary accounts
    IF NOT v_is_service THEN
        IF v_caller_id IS NULL OR v_caller_id <> p_target_user_id THEN
            RAISE EXCEPTION 'P0001: Permission Denied: Users may not dispatch notifications to foreign accounts';
        END IF;
    END IF;

    -- Check category preferences
    IF p_category = 'spaced_repetition' THEN
        SELECT study_reminders INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'streak_protection' THEN
        SELECT streak_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'exam_countdown' THEN
        SELECT exam_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'room_invite' OR p_category = 'social_alerts' THEN
        SELECT social_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    ELSIF p_category = 'ai_ingestion' THEN
        SELECT ai_ingestion_alerts INTO v_pref_allowed FROM public.notification_preferences WHERE user_id = p_target_user_id;
    END IF;

    IF v_pref_allowed IS FALSE THEN
        RETURN jsonb_build_object('success', false, 'reason', 'User opted out of this category');
    END IF;

    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        category,
        data
    ) VALUES (
        p_target_user_id,
        p_title,
        p_body,
        p_category,
        p_data
    )
    RETURNING id INTO v_notif_id;

    RETURN jsonb_build_object(
        'success', true,
        'notificationId', v_notif_id,
        'createdAt', now()
    );
END;
$$;

-- Restrict execution to service_role (ordinary users must not invoke arbitrary notification inserts)
REVOKE EXECUTE ON FUNCTION public.send_tailored_notification(UUID, TEXT, TEXT, TEXT, JSONB) FROM authenticated, anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_tailored_notification(UUID, TEXT, TEXT, TEXT, JSONB) TO service_role;

-- ------------------------------------------------------------------------------
-- 6. nudge_study_circle_rpc: Circle membership verification & harassment rate limit
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.nudge_study_circle_rpc(
    p_circle_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_sender_id UUID;
    v_sender_name TEXT;
    v_circle RECORD;
    v_member_ids UUID[];
    v_notif_title TEXT;
    v_notif_body TEXT;
    v_uid UUID;
    v_recent_nudge_count INT := 0;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be signed in to nudge study circle';
    END IF;

    -- Membership Verification Guard
    IF NOT EXISTS (
        SELECT 1 FROM public.study_circle_members
        WHERE circle_id = p_circle_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION 'P0001: Permission Denied: Caller is not a member of this study circle';
    END IF;

    -- Rate Limit Guard: Prevent spamming more than 1 nudge every 5 minutes per user per circle
    SELECT COUNT(*) INTO v_recent_nudge_count
    FROM public.notifications
    WHERE category = 'room_invite'
      AND data->>'circle_id' = p_circle_id::text
      AND data->>'sender_id' = v_sender_id::text
      AND created_at > now() - INTERVAL '5 minutes';

    IF v_recent_nudge_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Please wait 5 minutes before nudging this circle again'
        );
    END IF;

    -- Retrieve sender display name
    SELECT COALESCE(display_name, raw_user_meta_data->>'full_name', email, 'A scholar')
    INTO v_sender_name
    FROM public.profiles
    WHERE id = v_sender_id;

    -- Retrieve circle info
    SELECT * INTO v_circle
    FROM public.study_circles
    WHERE id = p_circle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study Circle not found';
    END IF;

    -- Collect all other members in the pod
    SELECT array_agg(user_id) INTO v_member_ids
    FROM public.study_circle_members
    WHERE circle_id = p_circle_id AND user_id <> v_sender_id;

    IF v_member_ids IS NULL OR array_length(v_member_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'nudged_count', 0,
            'message', 'No other members to nudge'
        );
    END IF;

    v_notif_title := format('⚡ Focus Nudge from %s!', v_sender_name);
    v_notif_body := format('%s nudged your "%s" pod! Time to hit your weekly focus targets.', v_sender_name, v_circle.name);

    -- Insert in-app notifications for all members (enqueues to outbox via trigger)
    FOREACH v_uid IN ARRAY v_member_ids
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            category,
            data
        ) VALUES (
            v_uid,
            v_notif_title,
            v_notif_body,
            'room_invite',
            jsonb_build_object(
                'circle_id', p_circle_id,
                'circle_name', v_circle.name,
                'sender_id', v_sender_id,
                'sender_name', v_sender_name,
                'route', '/community'
            )
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'nudged_count', array_length(v_member_ids, 1),
        'message', format('Successfully nudged %s members', array_length(v_member_ids, 1))
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. sync_user_progress: Bound p_xp_delta against client inflation
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_user_progress(
    p_xp_delta  INT  DEFAULT 0,
    p_streak    INT  DEFAULT NULL,
    p_track     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id         UUID;
    v_new_xp          INT;
    v_new_streak      INT;
    v_effective_track TEXT;
    v_tier            TEXT;
    v_multiplier      NUMERIC(3,2) := 1.00;
    v_bounded_delta   INT;
    v_xp_to_add       INT;
    v_display_name    TEXT;
    v_avatar_url      TEXT;
    v_existing_xp     INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- Bound delta per invocation: clients cannot inject more than 1,000 XP in a single progress sync
    v_bounded_delta := LEAST(GREATEST(0, COALESCE(p_xp_delta, 0)), 1000);

    v_new_streak := COALESCE(p_streak, 0);
    IF v_new_streak >= 30 THEN v_multiplier := 2.00;
    ELSIF v_new_streak >= 14 THEN v_multiplier := 1.75;
    ELSIF v_new_streak >= 7  THEN v_multiplier := 1.50;
    ELSIF v_new_streak >= 4  THEN v_multiplier := 1.25;
    END IF;

    v_xp_to_add := GREATEST(0, ROUND(v_bounded_delta * v_multiplier));

    -- Safeguard: ensure we don't start from 0 if leaderboards already has real XP
    SELECT COALESCE(weekly_xp, 0) INTO v_existing_xp
    FROM public.leaderboards WHERE user_id = v_user_id;

    -- 1. Atomically update profiles
    UPDATE public.profiles
    SET
        xp_points    = GREATEST(COALESCE(xp_points, 0), COALESCE(v_existing_xp, 0)) + v_xp_to_add,
        streak_days  = CASE
                           WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                           ELSE streak_days
                       END,
        target_track = CASE
                           WHEN p_track IS NOT NULL AND p_track <> ''
                               THEN p_track
                           ELSE target_track
                       END,
        updated_at   = now()
    WHERE id = v_user_id
    RETURNING xp_points, streak_days, target_track, display_name, photo_url
    INTO v_new_xp, v_new_streak, v_effective_track, v_display_name, v_avatar_url;

    IF NOT FOUND THEN
        SELECT 
            COALESCE(raw_user_meta_data->>'display_name', raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', split_part(email, '@', 1), 'Scholar'),
            raw_user_meta_data->>'avatar_url'
        INTO v_display_name, v_avatar_url
        FROM auth.users
        WHERE id = v_user_id;

        INSERT INTO public.profiles (id, xp_points, streak_days, target_track, display_name, photo_url)
        VALUES (v_user_id, v_xp_to_add, GREATEST(0, v_new_streak), COALESCE(p_track, 'General'), v_display_name, v_avatar_url)
        RETURNING xp_points, streak_days, target_track INTO v_new_xp, v_new_streak, v_effective_track;
    END IF;

    -- 2. Determine league tier
    IF v_new_xp >= 1000 THEN v_tier := 'Dean''s List';
    ELSIF v_new_xp >= 600 THEN v_tier := 'Diamond';
    ELSIF v_new_xp >= 350 THEN v_tier := 'Gold';
    ELSIF v_new_xp >= 150 THEN v_tier := 'Silver';
    ELSE v_tier := 'Bronze';
    END IF;

    -- 3. Upsert into leaderboards
    INSERT INTO public.leaderboards (
        user_id, user_name, avatar_url, track,
        weekly_xp, daily_xp, streak_days, league_tier, rank, updated_at
    ) VALUES (
        v_user_id,
        COALESCE(v_display_name, 'Scholar'),
        v_avatar_url,
        COALESCE(v_effective_track, 'General'),
        v_new_xp,
        v_xp_to_add,
        GREATEST(0, v_new_streak),
        v_tier,
        1,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        user_name   = COALESCE(NULLIF(EXCLUDED.user_name, ''), leaderboards.user_name),
        avatar_url  = COALESCE(EXCLUDED.avatar_url, leaderboards.avatar_url),
        track       = COALESCE(NULLIF(EXCLUDED.track, ''), leaderboards.track),
        weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        daily_xp    = CASE
                          WHEN v_xp_to_add > 0 THEN leaderboards.daily_xp + v_xp_to_add
                          ELSE leaderboards.daily_xp
                      END,
        streak_days = EXCLUDED.streak_days,
        league_tier = EXCLUDED.league_tier,
        updated_at  = now();

    -- 4. Sync to user_analytics
    INSERT INTO public.user_analytics (user_id, xp_points, current_streak_days)
    VALUES (v_user_id, v_new_xp, GREATEST(0, v_new_streak))
    ON CONFLICT (user_id) DO UPDATE SET
        xp_points           = EXCLUDED.xp_points,
        current_streak_days = CASE
                                  WHEN p_streak IS NOT NULL THEN GREATEST(0, p_streak)
                                  ELSE user_analytics.current_streak_days
                              END,
        updated_at          = now();

    RETURN jsonb_build_object(
        'success',     true,
        'user_id',     v_user_id,
        'total_xp',    v_new_xp,
        'xp_added',    v_xp_to_add,
        'streak_days', v_new_streak,
        'track',       v_effective_track,
        'league_tier', v_tier,
        'multiplier',  v_multiplier
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. claim_weekly_xp: Source from authenticated profile state
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_weekly_xp(p_xp_amount INT DEFAULT 0)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_profile RECORD;
    v_xp      INT;
    v_tier    TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT xp_points, streak_days, target_track, display_name, photo_url
    INTO v_profile FROM public.profiles WHERE id = v_user_id;

    -- Profile xp_points is the authoritative source; client amount cannot inflate beyond profile balance
    v_xp := COALESCE(v_profile.xp_points, 0);

    IF v_xp >= 1000 THEN v_tier := 'Dean''s List';
    ELSIF v_xp >= 600 THEN v_tier := 'Diamond';
    ELSIF v_xp >= 350 THEN v_tier := 'Gold';
    ELSIF v_xp >= 150 THEN v_tier := 'Silver';
    ELSE v_tier := 'Bronze';
    END IF;

    INSERT INTO public.leaderboards (
        user_id, user_name, avatar_url, track,
        weekly_xp, daily_xp, streak_days, league_tier, rank, updated_at
    ) VALUES (
        v_user_id,
        COALESCE(v_profile.display_name, 'Scholar'),
        v_profile.photo_url,
        COALESCE(v_profile.target_track, 'General'),
        v_xp,
        0,
        GREATEST(0, COALESCE(v_profile.streak_days, 0)),
        v_tier,
        1,
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        weekly_xp   = GREATEST(leaderboards.weekly_xp, EXCLUDED.weekly_xp),
        league_tier = EXCLUDED.league_tier,
        updated_at  = now();

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'claimed_xp', v_xp,
        'league_tier', v_tier
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. record_pod_focus_minutes_rpc: Enforce session duration bounds & search_path
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_pod_focus_minutes_rpc(
    p_circle_id UUID DEFAULT NULL,
    p_minutes INT DEFAULT 0,
    p_activity_type TEXT DEFAULT 'general'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_bounded_minutes INT;
    v_pod_count INT := 0;
    v_updated_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User must be authenticated to record study circle activity';
    END IF;

    -- Bound minutes: maximum 720 minutes (12 hours) in a single recording event
    v_bounded_minutes := LEAST(GREATEST(0, p_minutes), 720);

    IF v_bounded_minutes <= 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', 0,
            'minutes_added_per_pod', 0,
            'message', 'No focus minutes earned (duration too short)'
        );
    END IF;

    IF p_circle_id IS NOT NULL THEN
        UPDATE public.study_circle_members
        SET weekly_minutes_contributed = weekly_minutes_contributed + v_bounded_minutes
        WHERE circle_id = p_circle_id AND user_id = v_user_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;

        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', v_updated_count,
            'minutes_added_per_pod', v_bounded_minutes,
            'activity_type', p_activity_type
        );
    END IF;

    SELECT COUNT(*) INTO v_pod_count
    FROM public.study_circle_members
    WHERE user_id = v_user_id;

    IF v_pod_count <= 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'updated_circles_count', 0,
            'message', 'User is not a member of any active study pod'
        );
    END IF;

    UPDATE public.study_circle_members
    SET weekly_minutes_contributed = weekly_minutes_contributed + v_bounded_minutes
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'updated_circles_count', v_updated_count,
        'minutes_added_per_pod', v_bounded_minutes,
        'activity_type', p_activity_type
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 10. Blanket Dynamic Enforcement: Apply SET search_path = public, pg_temp
--     to ALL existing SECURITY DEFINER routines in schema 'public'
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_sql TEXT;
    v_count INT := 0;
BEGIN
    FOR r IN
        SELECT 
            n.nspname, 
            p.proname, 
            pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND (
            p.proconfig IS NULL 
            OR NOT (
                'search_path=public, pg_temp' = ANY(p.proconfig)
                OR 'search_path=public,pg_temp' = ANY(p.proconfig)
            )
          )
    LOOP
        v_sql := format(
            'ALTER FUNCTION %I.%I(%s) SET search_path = public, pg_temp;', 
            r.nspname, 
            r.proname, 
            r.args
        );
        BEGIN
            EXECUTE v_sql;
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not set search_path on %.%(%): %', r.nspname, r.proname, r.args, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Successfully hardened % SECURITY DEFINER functions with search_path = public, pg_temp', v_count;
END;
$$;
