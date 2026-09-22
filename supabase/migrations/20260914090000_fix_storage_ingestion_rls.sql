
INSERT INTO storage.buckets (id, name, public)
VALUES ('study-documents', 'study-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Users can upload their own study documents" ON storage.objects;
CREATE POLICY "Users can upload their own study documents"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'study-documents'
);

DROP POLICY IF EXISTS "Users can view their own study documents" ON storage.objects;
CREATE POLICY "Users can view their own study documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'study-documents'
);

DROP POLICY IF EXISTS "Users can update their own study documents" ON storage.objects;
CREATE POLICY "Users can update their own study documents"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'study-documents'
)
WITH CHECK (
    bucket_id = 'study-documents'
);

DROP POLICY IF EXISTS "Users can delete their own study documents" ON storage.objects;
CREATE POLICY "Users can delete their own study documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'study-documents'
);
