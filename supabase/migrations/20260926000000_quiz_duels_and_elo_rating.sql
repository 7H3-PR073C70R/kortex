-- Migration: 20260926000000_quiz_duels_and_elo_rating.sql
-- Description: Adds quiz_duels table for multiplayer duel history, persistent ELO ratings, and Elo calculation RPC.

-- 1. Ensure elo_rating exists on user profiles
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS elo_rating INT DEFAULT 1200;

CREATE INDEX IF NOT EXISTS idx_user_profiles_elo_rating ON public.user_profiles(elo_rating DESC);

-- 2. Create quiz_duels history table
CREATE TABLE IF NOT EXISTS public.quiz_duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    duel_id TEXT UNIQUE NOT NULL,
    subject TEXT NOT NULL,
    exam_board TEXT NOT NULL,
    player1_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    player2_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    player1_score INT NOT NULL DEFAULT 0,
    player2_score INT NOT NULL DEFAULT 0,
    player1_elo_before INT NOT NULL DEFAULT 1200,
    player2_elo_before INT NOT NULL DEFAULT 1200,
    player1_elo_after INT,
    player2_elo_after INT,
    winner_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    is_draw BOOLEAN DEFAULT FALSE,
    is_forfeit BOOLEAN DEFAULT FALSE,
    forfeit_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    questions_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_quiz_duels_player1 ON public.quiz_duels(player1_id);
CREATE INDEX IF NOT EXISTS idx_quiz_duels_player2 ON public.quiz_duels(player2_id);
CREATE INDEX IF NOT EXISTS idx_quiz_duels_created_at ON public.quiz_duels(created_at DESC);

-- Enable RLS on quiz_duels
ALTER TABLE public.quiz_duels ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quiz_duels;

-- RLS Policies
DROP POLICY IF EXISTS "Participants can view own duels" ON public.quiz_duels;
CREATE POLICY "Participants can view own duels"
    ON public.quiz_duels FOR SELECT
    TO authenticated
    USING (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "Participants can insert duels" ON public.quiz_duels;
CREATE POLICY "Participants can insert duels"
    ON public.quiz_duels FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player1_id OR auth.uid() = player2_id);

-- 3. Atomic Function: Process Duel Outcome & Update ELO
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
AS $$
DECLARE
    v_p1_elo INT := 1200;
    v_p2_elo INT := 1200;
    v_expected_p1 FLOAT;
    v_expected_p2 FLOAT;
    v_actual_p1 FLOAT;
    v_actual_p2 FLOAT;
    v_k_factor CONSTANT INT := 32;
    v_new_p1_elo INT;
    v_new_p2_elo INT;
    v_result JSONB;
BEGIN
    -- Fetch existing ELO for Player 1
    SELECT COALESCE(elo_rating, 1200) INTO v_p1_elo
    FROM public.user_profiles
    WHERE id = p_player1_id;

    -- Fetch existing ELO for Player 2 (if real user)
    IF p_player2_id IS NOT NULL THEN
        SELECT COALESCE(elo_rating, 1200) INTO v_p2_elo
        FROM public.user_profiles
        WHERE id = p_player2_id;
    ELSE
        v_p2_elo := 1200;
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

    -- Update user profiles
    UPDATE public.user_profiles
    SET elo_rating = v_new_p1_elo
    WHERE id = p_player1_id;

    IF p_player2_id IS NOT NULL THEN
        UPDATE public.user_profiles
        SET elo_rating = v_new_p2_elo
        WHERE id = p_player2_id;
    END IF;

    -- Return outcome JSON summary
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

-- Grant EXECUTE permission to authenticated users, anon, and service_role for PostgREST RPC access
GRANT EXECUTE ON FUNCTION public.fn_process_quiz_duel_outcome(
    TEXT, UUID, UUID, INT, INT, UUID, BOOLEAN, BOOLEAN, UUID
) TO authenticated, anon, service_role;

