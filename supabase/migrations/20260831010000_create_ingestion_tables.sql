
INSERT INTO storage.buckets (id, name, public)
VALUES ('study-documents', 'study-documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload their own study documents" ON storage.objects;
CREATE POLICY "Users can upload their own study documents"
ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'study-documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can view their own study documents" ON storage.objects;
CREATE POLICY "Users can view their own study documents"
ON storage.objects
FOR SELECT
USING (
    bucket_id = 'study-documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can delete their own study documents" ON storage.objects;
CREATE POLICY "Users can delete their own study documents"
ON storage.objects
FOR DELETE
USING (
    bucket_id = 'study-documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    storage_path TEXT NOT NULL,
    content_hash TEXT NOT NULL, -- SHA-256 hash of file contents for deduplication
    processing_status TEXT NOT NULL DEFAULT 'uploaded' CHECK (processing_status IN ('uploaded', 'parsingOcr', 'generatingCards', 'completed', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.extracted_snippets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL,
    latex_content TEXT,
    topic TEXT NOT NULL DEFAULT 'General',
    confidence_score REAL DEFAULT 0.95,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_documents_user_id_hash ON public.documents(user_id, content_hash);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON public.documents(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_extracted_snippets_doc ON public.extracted_snippets(document_id, created_at ASC);

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extracted_snippets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own documents" ON public.documents;
CREATE POLICY "Users can manage their own documents"
ON public.documents
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage their own extracted snippets" ON public.extracted_snippets;
CREATE POLICY "Users can manage their own extracted snippets"
ON public.extracted_snippets
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.update_document_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_document_timestamp ON public.documents;
CREATE TRIGGER trg_update_document_timestamp
BEFORE UPDATE ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.update_document_timestamp();
