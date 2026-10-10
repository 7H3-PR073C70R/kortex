-- ==============================================================================
-- KORTEX GRADE-A DATABASE SCALABILITY MIGRATION
-- Migration: 20261011020000_tune_pgvector_hnsw_indexes.sql
-- Description:
--   Tunes all pgvector HNSW indexes with optimal parameters (m = 16,
--   ef_construction = 64) and partial index predicates (WHERE embedding IS NOT NULL)
--   to prevent graph pollution, eliminate null vector indexing overhead,
--   and dramatically speed up vector similarity scans across flashcards,
--   document chunks, curated courses, and semantic cache.
-- ==============================================================================

SET search_path = public, pg_catalog;

-- 1. Re-create HNSW index for flashcards with partial index filter
DROP INDEX IF EXISTS public.idx_flashcards_embedding_hnsw;

CREATE INDEX IF NOT EXISTS idx_flashcards_embedding_hnsw 
    ON public.flashcards 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    WHERE embedding IS NOT NULL;

-- 2. Re-create HNSW index for document chunks with partial index filter
DROP INDEX IF EXISTS public.idx_document_chunks_embedding_hnsw;

CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding_hnsw 
    ON public.document_chunks 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    WHERE embedding IS NOT NULL;

-- 3. Re-create HNSW index for curated courses with partial index filter
DROP INDEX IF EXISTS public.idx_curated_courses_embedding_hnsw;

CREATE INDEX IF NOT EXISTS idx_curated_courses_embedding_hnsw 
    ON public.curated_courses 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    WHERE embedding IS NOT NULL;

-- 4. Re-create HNSW index for semantic AI cache with partial index filter
DROP INDEX IF EXISTS public.idx_semantic_cache_embedding_hnsw;

CREATE INDEX IF NOT EXISTS idx_semantic_cache_embedding_hnsw 
    ON public.semantic_ai_cache 
    USING hnsw (prompt_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    WHERE prompt_embedding IS NOT NULL;

-- 5. Harden and optimize match_document_chunks_optimized RPC function
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
SET search_path = public, pg_catalog
AS $$
BEGIN
    -- Configure search-time trade-off between recall and speed (default 40 is optimal for sub-10ms scans)
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
      AND (filter_document_id IS NULL OR dc.document_id = filter_document_id)
      AND (1 - (dc.embedding <=> query_embedding)) >= match_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 6. Harden and optimize search_flashcards_semantic RPC function
CREATE OR REPLACE FUNCTION public.search_flashcards_semantic(
    p_query_embedding vector(1536),
    p_match_threshold FLOAT DEFAULT 0.65,
    p_match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    deck_id UUID,
    front TEXT,
    back TEXT,
    front_latex TEXT,
    back_latex TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    PERFORM set_config('hnsw.ef_search', '40', true);

    RETURN QUERY
    SELECT
        f.id,
        f.deck_id,
        f.front,
        f.back,
        f.front_latex,
        f.back_latex,
        (1 - (f.embedding <=> p_query_embedding))::FLOAT AS similarity
    FROM public.flashcards f
    WHERE f.user_id = auth.uid()
      AND f.embedding IS NOT NULL
      AND (1 - (f.embedding <=> p_query_embedding)) >= p_match_threshold
    ORDER BY f.embedding <=> p_query_embedding
    LIMIT p_match_count;
END;
$$;

-- Grant execute permissions to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.match_document_chunks_optimized(vector, FLOAT, INT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.search_flashcards_semantic(vector, FLOAT, INT) TO authenticated, service_role;
