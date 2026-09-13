-- ==============================================================================
-- KORTEX ENTERPRISE SCALABILITY & CONCURRENCY HARDENING MIGRATION
-- Migration: 20260916000000_enterprise_scalability_indexes.sql
-- Scale Target: 1,000,000+ Users, 50,000+ Peak CCU, 25,000+ QPS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. High-Concurrency Composite & Covering B-Tree Indexes
-- ------------------------------------------------------------------------------

-- Flashcards: Optimize due card scans, deck card lookups, and review queues
CREATE INDEX IF NOT EXISTS idx_flashcards_user_due_covering 
    ON public.flashcards(user_id, next_due_date, state) 
    INCLUDE (id, deck_id, stability, difficulty, interval, repetitions);

CREATE INDEX IF NOT EXISTS idx_flashcards_deck_user 
    ON public.flashcards(deck_id, user_id);

-- Forum: High-concurrency community feed listings and nested replies
CREATE INDEX IF NOT EXISTS idx_forum_posts_track_feed 
    ON public.forum_posts(track, created_at DESC)
    INCLUDE (id, author_id, title, upvotes, replies_count);

CREATE INDEX IF NOT EXISTS idx_forum_replies_post_tree 
    ON public.forum_replies(post_id, parent_reply_id, created_at ASC)
    INCLUDE (id, author_id, is_verified_solution, upvotes);

-- Dashboard & Analytics: Ultra-fast user stats and streak aggregations
CREATE INDEX IF NOT EXISTS idx_heatmap_activity_user_activity_date 
    ON public.heatmap_activity(user_id, activity_date DESC);

CREATE INDEX IF NOT EXISTS idx_user_curated_courses_covering 
    ON public.user_curated_courses(user_id, course_id) 
    INCLUDE (syllabus_coverage, enrolled_at);

-- Past Questions: Fast deterministic indexed filtering
CREATE INDEX IF NOT EXISTS idx_past_questions_subject_exam_year 
    ON public.past_questions(subject, exam_type, year)
    INCLUDE (id, prompt, correct_option_label);

-- Study Review Logs: Idempotent checkpointing index
CREATE INDEX IF NOT EXISTS idx_study_review_logs_sync_lookup 
    ON public.study_review_logs(user_id, reviewed_at_epoch DESC);

-- ------------------------------------------------------------------------------
-- 2. Notification Outbox Queue (Decoupled Push Engine with SKIP LOCKED)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notification_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL, -- 'forum_reply', 'daily_reminder', 'streak_alert', 'exam_countdown'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'sent', 'failed'
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    scheduled_for TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial index for active outbox worker polling
CREATE INDEX IF NOT EXISTS idx_notification_outbox_pending_queue 
    ON public.notification_outbox(scheduled_for, retry_count) 
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_notification_outbox_user_history 
    ON public.notification_outbox(user_id, created_at DESC);

-- RLS: Service role and admin only
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages notification outbox" ON public.notification_outbox;
CREATE POLICY "Service role manages notification outbox"
    ON public.notification_outbox FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Users can view own outbox status" ON public.notification_outbox;
CREATE POLICY "Users can view own outbox status"
    ON public.notification_outbox FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- RPC: Dequeue pending notifications with concurrent safety (FOR UPDATE SKIP LOCKED)
CREATE OR REPLACE FUNCTION public.dequeue_notification_outbox(
    p_batch_size INT DEFAULT 100
)
RETURNS TABLE (
    outbox_id UUID,
    target_user_id UUID,
    notification_type TEXT,
    title TEXT,
    body TEXT,
    payload JSONB,
    retry_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH batch AS (
        SELECT id
        FROM public.notification_outbox
        WHERE status = 'pending'
          AND scheduled_for <= now()
          AND retry_count < max_retries
        ORDER BY scheduled_for ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.notification_outbox o
    SET status = 'processing',
        processed_at = now()
    FROM batch b
    WHERE o.id = b.id
    RETURNING 
        o.id AS outbox_id,
        o.user_id AS target_user_id,
        o.notification_type,
        o.title,
        o.body,
        o.data AS payload,
        o.retry_count;
END;
$$;

-- RPC: Complete notification processing batch
CREATE OR REPLACE FUNCTION public.complete_notification_outbox_batch(
    p_success_ids UUID[],
    p_failed_ids UUID[],
    p_error_map JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Mark successful items as sent
    IF p_success_ids IS NOT NULL AND array_length(p_success_ids, 1) > 0 THEN
        UPDATE public.notification_outbox
        SET status = 'sent',
            processed_at = now()
        WHERE id = ANY(p_success_ids);
    END IF;

    -- Update failed items: retry or mark permanently failed
    IF p_failed_ids IS NOT NULL AND array_length(p_failed_ids, 1) > 0 THEN
        UPDATE public.notification_outbox
        SET retry_count = retry_count + 1,
            status = CASE 
                WHEN retry_count + 1 >= max_retries THEN 'failed'
                ELSE 'pending'
            END,
            scheduled_for = now() + (POWER(2, retry_count) * INTERVAL '30 seconds'), -- Exponential backoff
            error_message = COALESCE(p_error_map->>id::text, 'Push delivery failed'),
            processed_at = now()
        WHERE id = ANY(p_failed_ids);
    END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. High-Throughput Idempotent Quiz Submission Batch RPC
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.quiz_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_uuid UUID NOT NULL,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE SET NULL,
    score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    total_questions INT NOT NULL DEFAULT 0,
    correct_count INT NOT NULL DEFAULT 0,
    time_spent_seconds INT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_quiz_submission_transaction UNIQUE (user_id, transaction_uuid)
);

CREATE INDEX IF NOT EXISTS idx_quiz_submissions_user_date 
    ON public.quiz_submissions(user_id, submitted_at DESC);

ALTER TABLE public.quiz_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own quiz submissions" ON public.quiz_submissions;
CREATE POLICY "Users view own quiz submissions"
    ON public.quiz_submissions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own quiz submissions" ON public.quiz_submissions;
CREATE POLICY "Users insert own quiz submissions"
    ON public.quiz_submissions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Batch submission RPC
CREATE OR REPLACE FUNCTION public.sync_quiz_submissions_batch(
    submissions JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_sub RECORD;
    v_synced_count INT := 0;
    v_skipped_count INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authenticated Supabase JWT required.';
    END IF;

    IF submissions IS NULL OR jsonb_array_length(submissions) = 0 THEN
        RETURN jsonb_build_object('status', 'success', 'synced_count', 0, 'skipped_count', 0);
    END IF;

    FOR v_sub IN SELECT * FROM jsonb_to_recordset(submissions) AS x(
        transaction_uuid UUID,
        quiz_id UUID,
        score DOUBLE PRECISION,
        total_questions INT,
        correct_count INT,
        time_spent_seconds INT,
        metadata JSONB,
        submitted_at TEXT
    )
    LOOP
        -- Idempotency check
        IF EXISTS (
            SELECT 1 FROM public.quiz_submissions 
            WHERE user_id = v_user_id AND transaction_uuid = v_sub.transaction_uuid
        ) THEN
            v_skipped_count := v_skipped_count + 1;
            CONTINUE;
        END IF;

        INSERT INTO public.quiz_submissions (
            user_id,
            transaction_uuid,
            quiz_id,
            score,
            total_questions,
            correct_count,
            time_spent_seconds,
            metadata,
            submitted_at
        ) VALUES (
            v_user_id,
            v_sub.transaction_uuid,
            v_sub.quiz_id,
            COALESCE(v_sub.score, 0.0),
            COALESCE(v_sub.total_questions, 0),
            COALESCE(v_sub.correct_count, 0),
            COALESCE(v_sub.time_spent_seconds, 0),
            COALESCE(v_sub.metadata, '{}'::jsonb),
            COALESCE(v_sub.submitted_at::TIMESTAMPTZ, now())
        );

        -- Record activity log for gamification asynchronously
        INSERT INTO public.user_activity_logs (
            user_id,
            activity_type,
            details,
            xp_earned,
            created_at
        ) VALUES (
            v_user_id,
            'quiz_completed',
            jsonb_build_object('score', v_sub.score, 'correct', v_sub.correct_count),
            GREATEST(10, (v_sub.correct_count * 5)::INT),
            COALESCE(v_sub.submitted_at::TIMESTAMPTZ, now())
        );

        v_synced_count := v_synced_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'synced_count', v_synced_count,
        'skipped_duplicates', v_skipped_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 4. Fast Deterministic Past Questions Sampling RPC (No ORDER BY RANDOM())
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_past_questions_fast(
    p_subject TEXT DEFAULT NULL,
    p_exam_type TEXT DEFAULT NULL,
    p_limit INT DEFAULT 40,
    p_random_seed FLOAT DEFAULT 0.5
)
RETURNS TABLE (
    id TEXT,
    exam_type TEXT,
    subject TEXT,
    year INT,
    question_number INT,
    prompt TEXT,
    options JSONB,
    correct_option_index INT,
    correct_option_label TEXT,
    explanation TEXT,
    topic TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        pq.id,
        pq.exam_type,
        pq.subject,
        pq.year,
        pq.question_number,
        pq.prompt,
        pq.options,
        pq.correct_option_index,
        pq.correct_option_label,
        pq.explanation,
        pq.topic
    FROM public.past_questions pq
    WHERE (p_subject IS NULL OR pq.subject ILIKE '%' || p_subject || '%')
      AND (p_exam_type IS NULL OR pq.exam_type ILIKE '%' || p_exam_type || '%')
    -- Deterministic hash-based distribution provides pseudorandom sampling using indexes
    ORDER BY md5(pq.id || p_random_seed::text)
    LIMIT p_limit;
END;
$$;
