-- Migration: Setup pgvector Vector Search Pipeline for Syllabot RAG
-- Enables the vector extension, creates document_chunks table, similarity indexes, and matching RPC

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Document Chunks table for vector embeddings
CREATE TABLE IF NOT EXISTS document_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    embedding vector(1536),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Indexes for semantic cosine similarity search
CREATE INDEX IF NOT EXISTS idx_document_chunks_user_id ON document_chunks(user_id);
CREATE INDEX IF NOT EXISTS idx_document_chunks_document_id ON document_chunks(document_id);

-- Create HNSW index for high-speed approximate nearest neighbor vector search
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding_hnsw 
    ON document_chunks 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 4. Enable Row Level Security
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
CREATE POLICY "Users can query their own document chunks"
    ON document_chunks FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own document chunks"
    ON document_chunks FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own document chunks"
    ON document_chunks FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 6. Stored Function for Semantic Vector Matching
CREATE OR REPLACE FUNCTION match_document_chunks(
    query_text TEXT,
    match_threshold FLOAT DEFAULT 0.60,
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
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    RETURN QUERY
    SELECT
        dc.id,
        dc.document_id,
        dc.content,
        dc.metadata,
        1 - (dc.embedding <=> NULL::vector) AS similarity
    FROM document_chunks dc
    WHERE dc.user_id = v_user_id
      AND (filter_document_id IS NULL OR dc.document_id = filter_document_id)
      AND (1 - (dc.embedding <=> NULL::vector)) >= match_threshold
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$;

-- 7. Trigger to clean up chunks when a document is deleted
CREATE OR REPLACE FUNCTION trigger_cleanup_document_chunks()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM document_chunks WHERE document_id = OLD.id;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS tr_document_chunks_cleanup ON documents;
CREATE TRIGGER tr_document_chunks_cleanup
    BEFORE DELETE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cleanup_document_chunks();
