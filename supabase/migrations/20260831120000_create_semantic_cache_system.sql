-- Migration: Semantic Response Caching System & Vector RPC Optimizer
-- Caches embeddings, LLM chat responses, and generated quiz JSONs to eliminate redundant AI calls.

CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Semantic AI Cache Table
CREATE TABLE IF NOT EXISTS public.semantic_ai_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key TEXT NOT NULL,
    prompt_text TEXT NOT NULL,
    prompt_embedding vector(1536),
    response_type TEXT NOT NULL, -- 'syllabot_response', 'quiz_questions', 'rag_context'
    cached_payload JSONB NOT NULL,
    hit_count INT NOT NULL DEFAULT 1,
    ttl_seconds INT NOT NULL DEFAULT 604800, -- 7 days
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_semantic_cache_key UNIQUE (cache_key)
);

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_semantic_cache_type ON public.semantic_ai_cache(response_type);
CREATE INDEX IF NOT EXISTS idx_semantic_cache_expires_at ON public.semantic_ai_cache(expires_at);

-- HNSW Vector Index for Semantic Approximate Nearest Neighbor Lookup
CREATE INDEX IF NOT EXISTS idx_semantic_cache_embedding_hnsw 
    ON public.semantic_ai_cache 
    USING hnsw (prompt_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 3. Row Level Security
ALTER TABLE public.semantic_ai_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated and service role cache access" ON public.semantic_ai_cache;
CREATE POLICY "Allow authenticated and service role cache access"
    ON public.semantic_ai_cache FOR ALL
    TO authenticated, service_role
    USING (true)
    WITH CHECK (true);

-- 4. RPC: Get Semantic Cache Match (Cosine similarity search >= threshold)
CREATE OR REPLACE FUNCTION public.get_semantic_cache_match(
    p_embedding vector(1536),
    p_response_type TEXT,
    p_similarity_threshold FLOAT DEFAULT 0.94
)
RETURNS TABLE (
    cache_id UUID,
    cache_key TEXT,
    cached_payload JSONB,
    similarity FLOAT,
    hit_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH candidate AS (
        SELECT
            c.id,
            c.cache_key,
            c.cached_payload,
            1 - (c.prompt_embedding <=> p_embedding) AS sim,
            c.hit_count
        FROM public.semantic_ai_cache c
        WHERE c.response_type = p_response_type
          AND c.expires_at > now()
          AND c.prompt_embedding IS NOT NULL
        ORDER BY c.prompt_embedding <=> p_embedding
        LIMIT 1
    )
    SELECT
        candidate.id,
        candidate.cache_key,
        candidate.cached_payload,
        candidate.sim,
        candidate.hit_count
    FROM candidate
    WHERE candidate.sim >= p_similarity_threshold;

    -- Increment hit count on matched entry
    UPDATE public.semantic_ai_cache
    SET hit_count = hit_count + 1,
        updated_at = now()
    WHERE id IN (
        SELECT c.id FROM candidate c WHERE c.sim >= p_similarity_threshold
    );
END;
$$;

-- 5. RPC: Put Semantic Cache Entry
CREATE OR REPLACE FUNCTION public.put_semantic_cache(
    p_cache_key TEXT,
    p_prompt_text TEXT,
    p_response_type TEXT,
    p_payload JSONB,
    p_embedding vector(1536) DEFAULT NULL,
    p_ttl_seconds INT DEFAULT 604800
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.semantic_ai_cache (
        cache_key,
        prompt_text,
        prompt_embedding,
        response_type,
        cached_payload,
        ttl_seconds,
        expires_at
    )
    VALUES (
        p_cache_key,
        p_prompt_text,
        p_embedding,
        p_response_type,
        p_payload,
        p_ttl_seconds,
        now() + (p_ttl_seconds || ' seconds')::interval
    )
    ON CONFLICT (cache_key) DO UPDATE
    SET cached_payload = EXCLUDED.cached_payload,
        prompt_embedding = COALESCE(EXCLUDED.prompt_embedding, public.semantic_ai_cache.prompt_embedding),
        hit_count = public.semantic_ai_cache.hit_count + 1,
        expires_at = now() + (EXCLUDED.ttl_seconds || ' seconds')::interval,
        updated_at = now()
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- 6. RPC: Purge Expired Cache
CREATE OR REPLACE FUNCTION public.purge_expired_semantic_cache()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM public.semantic_ai_cache
    WHERE expires_at < now();

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;

-- 7. Optimized Vector Matching RPC for Document Chunks with Index Tuning
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
AS $$
BEGIN
    -- Set HNSW search parameter dynamically for high precision & speed
    PERFORM set_config('hnsw.ef_search', '40', true);

    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.content,
        dc.metadata,
        1 - (dc.embedding <=> query_embedding) AS similarity
    FROM public.document_chunks dc
    WHERE (filter_document_id IS NULL OR dc.document_id = filter_document_id)
      AND (1 - (dc.embedding <=> query_embedding)) >= match_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
