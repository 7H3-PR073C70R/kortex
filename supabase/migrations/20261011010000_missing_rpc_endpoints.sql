-- ==============================================================================
-- KORTEX MISSING RPC CONTRACTS MIGRATION: 20261011010000
-- Implements app_sync_engine_upsert, get_dashboard_analytics_summary,
-- and generate_duel_questions to resolve client-to-backend contract mismatches.
-- ==============================================================================

-- 1. App Sync Engine CRDT Storage & Upsert RPC
CREATE TABLE IF NOT EXISTS public.app_sync_queue_records (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    payload JSONB NOT NULL,
    client_timestamp_epoch BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_sync_queue_user_type 
ON public.app_sync_queue_records(user_id, type);

ALTER TABLE public.app_sync_queue_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own sync records" ON public.app_sync_queue_records;
CREATE POLICY "Users can manage own sync records"
    ON public.app_sync_queue_records FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.app_sync_engine_upsert(payloads JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item JSONB;
    v_synced_count INT := 0;
    v_id TEXT;
    v_type TEXT;
    v_data JSONB;
    v_epoch BIGINT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User authentication required';
    END IF;

    IF payloads IS NULL OR jsonb_typeof(payloads) != 'array' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid payloads array');
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(payloads)
    LOOP
        v_id := v_item->>'id';
        v_type := COALESCE(v_item->>'type', 'generic');
        v_data := COALESCE(v_item->'data', '{}'::jsonb);
        v_epoch := COALESCE((v_item->>'timestampEpoch')::BIGINT, (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT);

        IF v_id IS NOT NULL THEN
            INSERT INTO public.app_sync_queue_records (
                id, user_id, type, payload, client_timestamp_epoch, updated_at
            ) VALUES (
                v_id, v_user_id, v_type, v_data, v_epoch, now()
            )
            ON CONFLICT (id) DO UPDATE SET
                payload = EXCLUDED.payload,
                client_timestamp_epoch = EXCLUDED.client_timestamp_epoch,
                updated_at = now()
            WHERE EXCLUDED.client_timestamp_epoch >= public.app_sync_queue_records.client_timestamp_epoch;

            v_synced_count := v_synced_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'synced_count', v_synced_count,
        'processed_at', now()
    );
END;
$$;

-- 2. Dashboard Analytics Summary RPC
CREATE OR REPLACE FUNCTION public.get_dashboard_analytics_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_feed JSONB;
    v_analytics JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    v_feed := public.get_dashboard_feed();
    v_analytics := v_feed->'analytics';

    IF v_analytics IS NULL THEN
        RETURN jsonb_build_object(
            'currentStreakDays', 0,
            'longestStreakDays', 1,
            'weeklyMinutesStudied', 0,
            'overallRetentionRate', 0.85,
            'totalCardsMastered', 0,
            'heatMapData', '[]'::jsonb,
            'xpPoints', 0,
            'academicRank', 'Neural Scholar I'
        );
    END IF;

    RETURN v_analytics;
END;
$$;

-- 3. Dynamic Quiz Duel Questions RPC
CREATE OR REPLACE FUNCTION public.generate_duel_questions(
    subject TEXT DEFAULT '',
    exam_board TEXT DEFAULT '',
    count INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_results JSONB;
    v_clean_subject TEXT := lower(trim(COALESCE(subject, '')));
    v_clean_board TEXT := lower(trim(COALESCE(exam_board, '')));
    v_limit INT := GREATEST(1, LEAST(COALESCE(count, 10), 30));
BEGIN
    -- Primary match: by subject and exam board
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'prompt', q.prompt,
            'question', q.prompt,
            'options', q.options,
            'correct_answer', q.correct_option_label,
            'answer', q.correct_option_label,
            'explanation', COALESCE(q.explanation, ''),
            'sub_topic', COALESCE(q.topic, subject),
            'topic', COALESCE(q.topic, subject)
        )
    ), '[]'::jsonb)
    INTO v_results
    FROM (
        SELECT id, prompt, options, correct_option_label, explanation, topic
        FROM public.past_questions
        WHERE (v_clean_subject = '' OR lower(past_questions.subject) LIKE '%' || v_clean_subject || '%')
          AND (v_clean_board = '' OR lower(past_questions.exam_type) LIKE '%' || v_clean_board || '%')
        ORDER BY random()
        LIMIT v_limit
    ) q;

    -- Secondary fallback: match by subject only
    IF jsonb_array_length(v_results) = 0 AND v_clean_subject != '' THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', q.id,
                'prompt', q.prompt,
                'question', q.prompt,
                'options', q.options,
                'correct_answer', q.correct_option_label,
                'answer', q.correct_option_label,
                'explanation', COALESCE(q.explanation, ''),
                'sub_topic', COALESCE(q.topic, subject),
                'topic', COALESCE(q.topic, subject)
            )
        ), '[]'::jsonb)
        INTO v_results
        FROM (
            SELECT id, prompt, options, correct_option_label, explanation, topic
            FROM public.past_questions
            WHERE lower(past_questions.subject) LIKE '%' || v_clean_subject || '%'
            ORDER BY random()
            LIMIT v_limit
        ) q;
    END IF;

    -- Final fallback: return any available random past questions
    IF jsonb_array_length(v_results) = 0 THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', q.id,
                'prompt', q.prompt,
                'question', q.prompt,
                'options', q.options,
                'correct_answer', q.correct_option_label,
                'answer', q.correct_option_label,
                'explanation', COALESCE(q.explanation, ''),
                'sub_topic', COALESCE(q.topic, 'General'),
                'topic', COALESCE(q.topic, 'General')
            )
        ), '[]'::jsonb)
        INTO v_results
        FROM (
            SELECT id, prompt, options, correct_option_label, explanation, topic
            FROM public.past_questions
            ORDER BY random()
            LIMIT v_limit
        ) q;
    END IF;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_sync_engine_upsert(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dashboard_analytics_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_duel_questions(TEXT, TEXT, INT) TO authenticated, anon;
