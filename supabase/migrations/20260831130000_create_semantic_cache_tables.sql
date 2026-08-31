-- Migration: Semantic Response Cache Table & Vector Similarity Matcher
-- Caches RAG embeddings, Syllabot chat completions, and AI quiz outputs

CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Create semantic_response_cache table
CREATE TABLE IF NOT EXISTS public.semantic_response_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prompt_hash TEXT NOT NULL,
    prompt_vector vector(1536),
    response_json JSONB NOT NULL,
    course_code TEXT,
    hit_count INT NOT NULL DEFAULT 1,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes for exact hash lookup and HNSW cosine similarity search
CREATE INDEX IF NOT EXISTS idx_semantic_resp_cache_hash ON public.semantic_response_cache(prompt_hash);
CREATE INDEX IF NOT EXISTS idx_semantic_resp_cache_course ON public.semantic_response_cache(course_code);
CREATE INDEX IF NOT EXISTS idx_semantic_resp_cache_expires ON public.semantic_response_cache(expires_at);

CREATE INDEX IF NOT EXISTS idx_semantic_resp_cache_vector_hnsw 
    ON public.semantic_response_cache 
    USING hnsw (prompt_vector vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 3. Row Level Security
ALTER TABLE public.semantic_response_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow cache access for all authenticated and service role" ON public.semantic_response_cache;
CREATE POLICY "Allow cache access for all authenticated and service role"
    ON public.semantic_response_cache FOR ALL
    TO authenticated, service_role
    USING (true)
    WITH CHECK (true);

-- 4. RPC: find_cached_response (Cosine Similarity >= 0.95)
CREATE OR REPLACE FUNCTION public.find_cached_response(
    query_vector vector(1536),
    similarity_threshold FLOAT DEFAULT 0.95,
    p_course_code TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    prompt_hash TEXT,
    response_json JSONB,
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
            c.prompt_hash,
            c.response_json,
            1 - (c.prompt_vector <=> query_vector) AS sim,
            c.hit_count
        FROM public.semantic_response_cache c
        WHERE c.expires_at > now()
          AND c.prompt_vector IS NOT NULL
          AND (p_course_code IS NULL OR c.course_code = p_course_code)
        ORDER BY c.prompt_vector <=> query_vector
        LIMIT 1
    )
    SELECT
        candidate.id,
        candidate.prompt_hash,
        candidate.response_json,
        candidate.sim,
        candidate.hit_count
    FROM candidate
    WHERE candidate.sim >= similarity_threshold;

    -- Increment hit count on matched entry
    UPDATE public.semantic_response_cache
    SET hit_count = hit_count + 1
    WHERE id IN (
        SELECT candidate.id
        FROM (
            SELECT c.id, 1 - (c.prompt_vector <=> query_vector) AS sim
            FROM public.semantic_response_cache c
            WHERE c.expires_at > now()
              AND c.prompt_vector IS NOT NULL
              AND (p_course_code IS NULL OR c.course_code = p_course_code)
            ORDER BY c.prompt_vector <=> query_vector
            LIMIT 1
        ) candidate
        WHERE candidate.sim >= similarity_threshold
    );
END;
$$;

-- 5. RPC: store_cached_response
CREATE OR REPLACE FUNCTION public.store_cached_response(
    p_prompt_hash TEXT,
    p_response_json JSONB,
    p_prompt_vector vector(1536) DEFAULT NULL,
    p_course_code TEXT DEFAULT NULL,
    p_ttl_days INT DEFAULT 7
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.semantic_response_cache (
        prompt_hash,
        prompt_vector,
        response_json,
        course_code,
        expires_at
    )
    VALUES (
        p_prompt_hash,
        p_prompt_vector,
        p_response_json,
        p_course_code,
        now() + (p_ttl_days || ' days')::interval
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;
