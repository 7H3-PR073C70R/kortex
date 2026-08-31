-- Migration: Create cross-user Content Deduplication and Reference Assignment RPC
-- Allows multi-tenant reference assignment to avoid duplicate binary storage.

CREATE OR REPLACE FUNCTION find_or_create_document_reference(
    p_content_hash TEXT,
    p_filename TEXT,
    p_file_type TEXT,
    p_file_size_bytes BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_existing_doc RECORD;
    v_target_doc RECORD;
    v_existing_user_doc RECORD;
    v_snippets_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 1. Check if the current user already has an instance for this hash
    SELECT * INTO v_existing_user_doc
    FROM documents
    WHERE user_id = v_user_id AND content_hash = p_content_hash
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'document', to_jsonb(v_existing_user_doc),
            'is_deduplicated', true,
            'is_existing_instance', true
        );
    END IF;

    -- 2. Check if ANY user has uploaded this identical content before
    SELECT * INTO v_existing_doc
    FROM documents
    WHERE content_hash = p_content_hash
    ORDER BY created_at ASC
    LIMIT 1;

    IF NOT FOUND THEN
        -- No existing content found anywhere in the system; client should upload binary to storage
        RETURN NULL;
    END IF;

    -- 3. Create an instance/reference for this user in their folder with full personal ownership
    INSERT INTO documents (
        user_id,
        filename,
        file_type,
        file_size_bytes,
        storage_path,
        content_hash,
        processing_status
    )
    VALUES (
        v_user_id,
        p_filename,
        p_file_type,
        p_file_size_bytes,
        v_existing_doc.storage_path,
        p_content_hash,
        'completed'
    )
    RETURNING * INTO v_target_doc;

    -- 4. Automatically copy and assign all extracted snippets to this user's document instance
    INSERT INTO extracted_snippets (
        document_id,
        user_id,
        raw_text,
        latex_content,
        topic,
        confidence_score
    )
    SELECT
        v_target_doc.id,
        v_user_id,
        s.raw_text,
        s.latex_content,
        s.topic,
        s.confidence_score
    FROM extracted_snippets s
    WHERE s.document_id = v_existing_doc.id;

    GET DIAGNOSTICS v_snippets_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'document', to_jsonb(v_target_doc),
        'is_deduplicated', true,
        'snippets_assigned', v_snippets_count,
        'is_existing_instance', false
    );
END;
$$;
