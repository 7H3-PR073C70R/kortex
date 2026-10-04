-- ==============================================================================
-- Migration: Add course_id and course_code columns to documents table
-- Ensures compatibility with claim_or_create_document_preflight RPC and course-based document scoping
-- ==============================================================================

ALTER TABLE public.documents 
    ADD COLUMN IF NOT EXISTS course_id TEXT,
    ADD COLUMN IF NOT EXISTS course_code TEXT;

CREATE INDEX IF NOT EXISTS idx_documents_course_id ON public.documents(course_id);
CREATE INDEX IF NOT EXISTS idx_documents_course_code ON public.documents(course_code);

-- Refresh claim_or_create_document_preflight function
CREATE OR REPLACE FUNCTION claim_or_create_document_preflight(
    p_content_hash TEXT,
    p_filename TEXT,
    p_file_type TEXT,
    p_file_size_bytes BIGINT,
    p_course_id TEXT DEFAULT NULL,
    p_course_code TEXT DEFAULT NULL,
    p_deck_title TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_canonical RECORD;
    v_existing_user_doc RECORD;
    v_canonical_deck RECORD;
    v_user_deck RECORD;
    v_lock_key BIGINT;
    v_clean_title TEXT;
    v_canonical_storage TEXT;
    v_ext TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User session required';
    END IF;

    v_lock_key := ('x' || substr(md5(p_content_hash), 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

    v_ext := LOWER(TRIM(LEADING '.' FROM p_file_type));
    IF v_ext = '' OR v_ext IS NULL THEN
        v_ext := 'pdf';
    END IF;

    v_clean_title := COALESCE(NULLIF(TRIM(p_deck_title), ''), regexp_replace(p_filename, '\.[^.]+$', ''));
    v_canonical_storage := 'canonical/' || p_content_hash || '.' || v_ext;

    SELECT * INTO v_canonical
    FROM canonical_documents
    WHERE content_hash = p_content_hash;

    IF FOUND THEN
        SELECT * INTO v_existing_user_doc
        FROM documents
        WHERE user_id = v_user_id AND content_hash = p_content_hash
        LIMIT 1;

        IF NOT FOUND THEN
            INSERT INTO documents (
                user_id, filename, file_type, file_size_bytes, storage_path, 
                content_hash, processing_status, course_id, course_code
            )
            VALUES (
                v_user_id, p_filename, v_ext, p_file_size_bytes, v_canonical.storage_path, 
                p_content_hash, v_canonical.processing_status, p_course_id, p_course_code
            )
            RETURNING * INTO v_existing_user_doc;

            UPDATE canonical_documents 
            SET reference_count = reference_count + 1,
                updated_at = now()
            WHERE id = v_canonical.id;
        END IF;

        IF v_canonical.processing_status = 'failed' OR 
           (v_canonical.processing_status = 'processing' AND v_canonical.updated_at < (now() - INTERVAL '15 minutes')) THEN
            UPDATE canonical_documents
            SET processing_status = 'processing',
                updated_at = now()
            WHERE id = v_canonical.id;

            RETURN jsonb_build_object(
                'status', 'reprocess_required',
                'is_deduplicated', false,
                'canonical_doc_id', v_canonical.id,
                'user_doc_id', v_existing_user_doc.id,
                'storage_path', v_canonical.storage_path,
                'message', 'Previous synthesis timed out or failed. Re-initiating processing.'
            );
        END IF;

        IF v_canonical.processing_status = 'processing' THEN
            RETURN jsonb_build_object(
                'status', 'in_progress',
                'is_deduplicated', true,
                'canonical_doc_id', v_canonical.id,
                'user_doc_id', v_existing_user_doc.id,
                'storage_path', v_canonical.storage_path,
                'message', 'Document is actively being synthesized. Subscribed to live updates.'
            );
        END IF;

        IF v_canonical.processing_status = 'completed' THEN
            SELECT * INTO v_canonical_deck 
            FROM canonical_decks 
            WHERE canonical_document_id = v_canonical.id;

            IF FOUND THEN
                SELECT * INTO v_user_deck 
                FROM decks 
                WHERE user_id = v_user_id AND canonical_deck_id = v_canonical_deck.id;

                IF NOT FOUND THEN
                    INSERT INTO decks (
                        user_id, canonical_deck_id, title, subject, category, 
                        total_cards, due_cards, course_id, course_code, is_forked
                    )
                    VALUES (
                        v_user_id, 
                        v_canonical_deck.id, 
                        COALESCE(NULLIF(TRIM(p_deck_title), ''), v_canonical_deck.default_title), 
                        v_canonical_deck.subject, 
                        'Academic',
                        v_canonical_deck.total_cards, 
                        v_canonical_deck.total_cards, 
                        p_course_id, 
                        p_course_code, 
                        false
                    )
                    RETURNING * INTO v_user_deck;

                    INSERT INTO flashcards (
                        deck_id, user_id, front, back, front_latex, back_latex, 
                        explanation, image_url, source_topic, state, difficulty, 
                        "interval", repetitions, ease_factor, next_due_date
                    )
                    SELECT 
                        v_user_deck.id, v_user_id, c.front, c.back, c.front_latex, c.back_latex,
                        c.explanation, c.image_url, c.source_topic, 0, 0.3,
                        1, 0, 2.5, now()
                    FROM canonical_cards c
                    WHERE c.canonical_deck_id = v_canonical_deck.id;

                    INSERT INTO extracted_snippets (
                        document_id, user_id, raw_text, latex_content, topic, confidence_score
                    )
                    SELECT 
                        v_existing_user_doc.id, v_user_id, c.back, c.back_latex, c.front, 0.98
                    FROM canonical_cards c
                    WHERE c.canonical_deck_id = v_canonical_deck.id
                    ON CONFLICT DO NOTHING;
                END IF;

                RETURN jsonb_build_object(
                    'status', 'ready',
                    'is_deduplicated', true,
                    'canonical_doc_id', v_canonical.id,
                    'user_doc_id', v_existing_user_doc.id,
                    'deck_id', v_user_deck.id,
                    'total_cards', v_canonical_deck.total_cards,
                    'message', 'Instant match found! Deck added to your library.'
                );
            ELSE
                UPDATE canonical_documents
                SET processing_status = 'processing', updated_at = now()
                WHERE id = v_canonical.id;

                RETURN jsonb_build_object(
                    'status', 'reprocess_required',
                    'is_deduplicated', false,
                    'canonical_doc_id', v_canonical.id,
                    'user_doc_id', v_existing_user_doc.id,
                    'storage_path', v_canonical.storage_path
                );
            END IF;
        END IF;
    END IF;

    INSERT INTO canonical_documents (
        content_hash, storage_path, file_size_bytes, file_type, processing_status, reference_count
    )
    VALUES (
        p_content_hash, v_canonical_storage, p_file_size_bytes, v_ext, 'processing', 1
    )
    RETURNING * INTO v_canonical;

    INSERT INTO documents (
        user_id, filename, file_type, file_size_bytes, storage_path, 
        content_hash, processing_status, course_id, course_code
    )
    VALUES (
        v_user_id, p_filename, v_ext, p_file_size_bytes, v_canonical.storage_path, 
        p_content_hash, 'uploaded', p_course_id, p_course_code
    )
    RETURNING * INTO v_existing_user_doc;

    RETURN jsonb_build_object(
        'status', 'upload_required',
        'is_deduplicated', false,
        'canonical_doc_id', v_canonical.id,
        'user_doc_id', v_existing_user_doc.id,
        'storage_path', v_canonical.storage_path
    );
END;
$$;
