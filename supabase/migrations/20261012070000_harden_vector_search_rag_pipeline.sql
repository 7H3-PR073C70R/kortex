-- ============================================================================
-- Migration: 20261012070000_harden_vector_search_rag_pipeline.sql
-- Description: P2-05 Replace Pseudo-Embeddings with Real Vector Pipeline & Safe Fallbacks
--
-- 1. Updates match_document_chunks:
--    - Eliminates broken `(dc.embedding <=> NULL::vector)` computation.
--    - Implements high-precision PostgreSQL full-text search fallback when query_text
--      is supplied without precomputed vector embeddings.
-- 2. Updates match_document_chunks_optimized:
--    - Strictly validates that query_embedding is NOT NULL before running cosine distance.
--    - Never returns arbitrary records if query_embedding is missing or disabled.
-- 3. Hardens search_path and enforces authenticated least privilege.
-- ============================================================================

-- 1. Robust Hybrid Text & Ranking Search for match_document_chunks
CREATE OR REPLACE FUNCTION public.match_document_chunks(
    query_text TEXT,
    match_threshold FLOAT DEFAULT 0.10,
    match_count INT DEFAULT 5,
    filter_document_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    document_id UUID,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_query tsquery;
BEGIN
    IF query_text IS NULL OR trim(query_text) = '' THEN
        RETURN;
    END IF;

    -- Construct safe tsquery from user text
    BEGIN
        v_query := websearch_to_tsquery('english', query_text);
    EXCEPTION WHEN OTHERS THEN
        v_query := plainto_tsquery('english', query_text);
    END;

    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.content,
        dc.metadata,
        COALESCE(
            ts_rank_cd(to_tsvector('english', dc.content), v_query),
            0.15
        )::FLOAT AS similarity
    FROM public.document_chunks dc
    WHERE (v_user_id IS NULL OR dc.user_id = v_user_id)
      AND (filter_document_id IS NULL OR dc.document_id = filter_document_id)
      AND (
          (v_query IS NOT NULL AND to_tsvector('english', dc.content) @@ v_query)
          OR dc.content ILIKE ('%' || trim(query_text) || '%')
      )
    ORDER BY similarity DESC, dc.created_at DESC
    LIMIT match_count;
END;
$$;

-- 2. Hardened match_document_chunks_optimized (True pgvector cosine search)
CREATE OR REPLACE FUNCTION public.match_document_chunks_optimized(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.65,
    match_count INT DEFAULT 6,
    filter_document_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    document_id UUID,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- Deactivation Guard: If query_embedding is null, do NOT serve garbage context
    IF query_embedding IS NULL THEN
        RETURN;
    END IF;

    -- Configure search-time trade-off between recall and speed
    PERFORM set_config('hnsw.ef_search', '40', true);

    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.content,
        dc.metadata,
        (1 - (dc.embedding <=> query_embedding))::FLOAT AS similarity
    FROM public.document_chunks dc
    WHERE dc.embedding IS NOT NULL
      AND (v_user_id IS NULL OR dc.user_id = v_user_id)
      AND (filter_document_id IS NULL OR dc.document_id = filter_document_id)
      AND (1 - (dc.embedding <=> query_embedding)) >= match_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 3. Permissions Hardening
REVOKE EXECUTE ON FUNCTION public.match_document_chunks(TEXT, FLOAT, INT, UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_document_chunks(TEXT, FLOAT, INT, UUID) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.match_document_chunks_optimized(vector, FLOAT, INT, UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_document_chunks_optimized(vector, FLOAT, INT, UUID) TO authenticated, service_role;
