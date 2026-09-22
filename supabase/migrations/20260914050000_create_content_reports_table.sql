
CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type TEXT NOT NULL DEFAULT 'forum_post',
    content_id TEXT NOT NULL,
    post_id UUID REFERENCES public.forum_posts(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reporter_name TEXT,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_content_reports_content_id ON public.content_reports(content_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON public.content_reports(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter_id ON public.content_reports(reporter_id);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can submit content reports"
    ON public.content_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = reporter_id OR reporter_id IS NULL);

CREATE POLICY "Users can view their own submitted reports"
    ON public.content_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = reporter_id);

GRANT ALL ON public.content_reports TO authenticated, service_role;
