-- ==============================================================================
-- Migration: 20260921000000_canonical_cas_deduplication.sql
-- Description: Canonical Content-Addressed Storage (CAS), Multi-Tenant Preflight RPC with
--              Advisory Locking, Deck Projection Isolation, Poisoned Retry, and Storage GC.
-- ==============================================================================

-- 1. Ensure flashcards has explanation and image_url columns
ALTER TABLE public.flashcards 
    ADD COLUMN IF NOT EXISTS explanation TEXT,
    ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. Canonical Documents (Global Master Binaries & Pipeline Status)
CREATE TABLE IF NOT EXISTS public.canonical_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_hash TEXT UNIQUE NOT NULL,       -- SHA-256 of raw file
    text_stream_hash TEXT,                  -- Optional normalized text hash
    storage_path TEXT NOT NULL,             -- canonical/{content_hash}.pdf
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    file_type TEXT NOT NULL DEFAULT 'pdf',
    processing_status TEXT NOT NULL DEFAULT 'processing' 
        CHECK (processing_status IN ('processing', 'completed', 'failed', 'reprocess_required')),
    reference_count INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_canonical_docs_hash ON public.canonical_documents(content_hash);
CREATE INDEX IF NOT EXISTS idx_canonical_docs_text_hash ON public.canonical_documents(text_stream_hash);

-- 3. Canonical Decks & Cards (Master Flashcard Templates from Luna Synthesis)
CREATE TABLE IF NOT EXISTS public.canonical_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_document_id UUID UNIQUE NOT NULL REFERENCES public.canonical_documents(id) ON DELETE CASCADE,
    default_title TEXT NOT NULL,
    subject TEXT NOT NULL,
    total_cards INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.canonical_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_deck_id UUID NOT NULL REFERENCES public.canonical_decks(id) ON DELETE CASCADE,
    order_index INT NOT NULL DEFAULT 0,
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    front_latex TEXT,
    back_latex TEXT,
    explanation TEXT,
    image_url TEXT,
    source_topic TEXT,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_canonical_cards_deck ON public.canonical_cards(canonical_deck_id);

-- 4. Storage Binary Cleanup Queue
CREATE TABLE IF NOT EXISTS public.storage_cleanup_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_storage_cleanup_unprocessed 
    ON public.storage_cleanup_queue(processed_at) 
    WHERE processed_at IS NULL;

-- 5. Add Canonical Reference & Fork Flag to User Decks
ALTER TABLE public.decks 
    ADD COLUMN IF NOT EXISTS canonical_deck_id UUID REFERENCES public.canonical_decks(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS is_forked BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_decks_canonical_deck_id ON public.decks(canonical_deck_id);

-- 6. Enable Row Level Security (RLS) on Canonical & Cleanup Tables
ALTER TABLE public.canonical_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canonical_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canonical_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.storage_cleanup_queue ENABLE ROW LEVEL SECURITY;

-- Read policies for authenticated users
DROP POLICY IF EXISTS "Authenticated users can read canonical documents" ON public.canonical_documents;
CREATE POLICY "Authenticated users can read canonical documents"
    ON public.canonical_documents FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can read canonical decks" ON public.canonical_decks;
CREATE POLICY "Authenticated users can read canonical decks"
    ON public.canonical_decks FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can read canonical cards" ON public.canonical_cards;
CREATE POLICY "Authenticated users can read canonical cards"
    ON public.canonical_cards FOR SELECT TO authenticated USING (true);

-- 7. Multi-Tenant Preflight RPC with Transactional Advisory Locking & User Title Override
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

    -- Generate a deterministic 64-bit signed integer from first 16 hex characters of hash
    v_lock_key := ('x' || substr(p_content_hash, 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

    v_ext := LOWER(TRIM(LEADING '.' FROM p_file_type));
    IF v_ext = '' OR v_ext IS NULL THEN
        v_ext := 'pdf';
    END IF;

    v_clean_title := COALESCE(NULLIF(TRIM(p_deck_title), ''), regexp_replace(p_filename, '\.[^.]+$', ''));
    v_canonical_storage := 'canonical/' || p_content_hash || '.' || v_ext;

    -- 1. Check if canonical record exists
    SELECT * INTO v_canonical
    FROM canonical_documents
    WHERE content_hash = p_content_hash;

    IF FOUND THEN
        -- Ensure user document row exists in documents table
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

            -- Increment reference count
            UPDATE canonical_documents 
            SET reference_count = reference_count + 1,
                updated_at = now()
            WHERE id = v_canonical.id;
        END IF;

        -- CASE A: Stuck or Failed Synthesis Recovery
        -- If status is 'failed' OR stuck in 'processing' for > 15 minutes (unhandled crash/reboot)
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

        -- CASE B: In-Flight Processing (active within last 15 minutes)
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

        -- CASE C: Synthesis Completed -> Instant Provisioning
        IF v_canonical.processing_status = 'completed' THEN
            SELECT * INTO v_canonical_deck 
            FROM canonical_decks 
            WHERE canonical_document_id = v_canonical.id;

            IF FOUND THEN
                -- Check if user already has a deck for this canonical deck
                SELECT * INTO v_user_deck 
                FROM decks 
                WHERE user_id = v_user_id AND canonical_deck_id = v_canonical_deck.id;

                IF NOT FOUND THEN
                    -- Provision personal deck projection with user's custom title (if provided)
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

                    -- Instantiate isolated flashcards with fresh SRS states
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

                    -- Assign extracted snippets to this user's document for RAG search
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
                -- Canonical doc marked completed but canonical_deck missing -> reprocess
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

    -- 2. Novel Document: Reserve slot in canonical_documents
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

-- 8. Safe Garbage Collection (Trigger on User Document Deletion)
CREATE OR REPLACE FUNCTION handle_document_ref_decrement()
RETURNS TRIGGER AS $$
DECLARE
    v_rem_refs INT;
    v_storage_path TEXT;
    v_content_hash TEXT := OLD.content_hash;
BEGIN
    IF v_content_hash IS NULL THEN
        RETURN OLD;
    END IF;

    UPDATE canonical_documents
    SET reference_count = reference_count - 1,
        updated_at = now()
    WHERE content_hash = v_content_hash
    RETURNING reference_count, storage_path INTO v_rem_refs, v_storage_path;

    -- If 0 active references across all users, queue storage deletion
    IF v_rem_refs IS NOT NULL AND v_rem_refs <= 0 THEN
        -- Queue primary PDF file for deletion from study-documents
        IF v_storage_path IS NOT NULL THEN
            INSERT INTO storage_cleanup_queue (bucket_id, storage_path)
            VALUES ('study-documents', v_storage_path);
        END IF;

        -- Queue extracted diagram assets folder
        INSERT INTO storage_cleanup_queue (bucket_id, storage_path)
        VALUES ('card-assets', 'canonical/' || v_content_hash);

        -- Delete canonical record (cascades to canonical_decks and canonical_cards)
        DELETE FROM canonical_documents WHERE content_hash = v_content_hash;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_decrement_doc_ref ON public.documents;
CREATE TRIGGER trg_decrement_doc_ref
AFTER DELETE ON public.documents
FOR EACH ROW EXECUTE FUNCTION handle_document_ref_decrement();

-- 9. Storage Cleanup Purge Function
CREATE OR REPLACE FUNCTION purge_orphaned_storage_files(p_batch_limit INT DEFAULT 50)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
    v_item RECORD;
    v_purged_count INT := 0;
BEGIN
    FOR v_item IN 
        SELECT id, bucket_id, storage_path 
        FROM storage_cleanup_queue 
        WHERE processed_at IS NULL 
        ORDER BY queued_at ASC 
        LIMIT p_batch_limit 
        FOR UPDATE SKIP LOCKED
    LOOP
        -- Delete objects from storage.objects
        DELETE FROM storage.objects
        WHERE bucket_id = v_item.bucket_id
          AND (name = v_item.storage_path OR name LIKE v_item.storage_path || '/%');

        UPDATE storage_cleanup_queue
        SET processed_at = now()
        WHERE id = v_item.id;

        v_purged_count := v_purged_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'purged_count', v_purged_count,
        'batch_limit', p_batch_limit
    );
END;
$$;
