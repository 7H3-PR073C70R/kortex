-- ==============================================================================
-- KORTEX SECURITY HARDENING: 20261012020000
-- Remediate Overly Permissive Row Level Security (RLS) Policies
-- Eliminates unrestricted write policies, public curriculum tampering,
-- vector cache corruption, forum post hijackings, and analytics fabrication.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. past_questions: Curriculum & Exam Bank Protection
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.past_questions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Public can read past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Service role can insert/update past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Anyone can view past questions" ON public.past_questions;
    DROP POLICY IF EXISTS "Service role manages past questions" ON public.past_questions;
END $$;

-- Allow public and student read-only inspection of curriculum items
CREATE POLICY "Anyone can view past questions"
    ON public.past_questions FOR SELECT
    TO anon, authenticated
    USING (true);

-- Restrict all mutations (INSERT, UPDATE, DELETE) strictly to internal service_role
CREATE POLICY "Service role manages past questions"
    ON public.past_questions FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Revoke direct table manipulation privileges from client roles
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.past_questions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.past_questions TO anon, authenticated;
GRANT ALL ON public.past_questions TO service_role;

-- ------------------------------------------------------------------------------
-- 2. study_communities: Scope Community Modifications to Creators & Admins
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.study_communities ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE IF EXISTS public.study_communities ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view study communities" ON public.study_communities;
    DROP POLICY IF EXISTS "Users can create study communities" ON public.study_communities;
    DROP POLICY IF EXISTS "Service role or functions can update study communities" ON public.study_communities;
    DROP POLICY IF EXISTS "Community creators and admins can update study communities" ON public.study_communities;
    DROP POLICY IF EXISTS "Community creators can delete study communities" ON public.study_communities;
    DROP POLICY IF EXISTS "Service role manages study communities" ON public.study_communities;
END $$;

-- Read policy: Anyone can discover communities
CREATE POLICY "Anyone can view study communities"
    ON public.study_communities FOR SELECT
    TO anon, authenticated
    USING (true);

-- Insert policy: Authenticated users can create communities attributed to their account
CREATE POLICY "Users can create study communities"
    ON public.study_communities FOR INSERT
    TO authenticated
    WITH CHECK (created_by IS NULL OR created_by = auth.uid());

-- Update policy: Only creator or founding members can update community details
CREATE POLICY "Community creators and admins can update study communities"
    ON public.study_communities FOR UPDATE
    TO authenticated
    USING (
        created_by = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM public.community_members cm 
            WHERE cm.community_id = study_communities.id 
              AND cm.user_id = auth.uid() 
              AND cm.is_founding_member = true
        )
    )
    WITH CHECK (
        created_by = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM public.community_members cm 
            WHERE cm.community_id = study_communities.id 
              AND cm.user_id = auth.uid() 
              AND cm.is_founding_member = true
        )
    );

-- Delete policy: Only community creator can delete the community
CREATE POLICY "Community creators can delete study communities"
    ON public.study_communities FOR DELETE
    TO authenticated
    USING (created_by = auth.uid());

-- Service role bypass for background housekeeping
CREATE POLICY "Service role manages study communities"
    ON public.study_communities FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- ------------------------------------------------------------------------------
-- 3. semantic_ai_cache & semantic_response_cache: Vector Cache Defense
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'semantic_ai_cache') THEN
        ALTER TABLE public.semantic_ai_cache ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Allow authenticated and service role cache access" ON public.semantic_ai_cache;
        DROP POLICY IF EXISTS "Authenticated users can read semantic cache" ON public.semantic_ai_cache;
        DROP POLICY IF EXISTS "Service role manages semantic cache" ON public.semantic_ai_cache;

        CREATE POLICY "Authenticated users can read semantic cache"
            ON public.semantic_ai_cache FOR SELECT
            TO authenticated
            USING (true);

        CREATE POLICY "Service role manages semantic cache"
            ON public.semantic_ai_cache FOR ALL
            TO service_role
            USING ((auth.jwt() ->> 'role') = 'service_role')
            WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

        REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.semantic_ai_cache FROM PUBLIC, anon, authenticated;
        GRANT SELECT ON public.semantic_ai_cache TO authenticated;
        GRANT ALL ON public.semantic_ai_cache TO service_role;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'semantic_response_cache') THEN
        ALTER TABLE public.semantic_response_cache ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Allow cache access for all authenticated and service role" ON public.semantic_response_cache;
        DROP POLICY IF EXISTS "Authenticated users can read semantic response cache" ON public.semantic_response_cache;
        DROP POLICY IF EXISTS "Service role manages semantic response cache" ON public.semantic_response_cache;

        CREATE POLICY "Authenticated users can read semantic response cache"
            ON public.semantic_response_cache FOR SELECT
            TO authenticated
            USING (true);

        CREATE POLICY "Service role manages semantic response cache"
            ON public.semantic_response_cache FOR ALL
            TO service_role
            USING ((auth.jwt() ->> 'role') = 'service_role')
            WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

        REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.semantic_response_cache FROM PUBLIC, anon, authenticated;
        GRANT SELECT ON public.semantic_response_cache TO authenticated;
        GRANT ALL ON public.semantic_response_cache TO service_role;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. user_analytics & heatmap_activity: Analytics Integrity Lockdown
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.user_analytics ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view own analytics" ON public.user_analytics;
    DROP POLICY IF EXISTS "Users can update own analytics" ON public.user_analytics;
    DROP POLICY IF EXISTS "Service role manages user analytics" ON public.user_analytics;
END $$;

CREATE POLICY "Users can view own analytics"
    ON public.user_analytics FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Service role manages user analytics"
    ON public.user_analytics FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Disallow client direct mutations; all writes flow through audited SECURITY DEFINER RPCs
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.user_analytics FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_analytics TO authenticated;
GRANT ALL ON public.user_analytics TO service_role;

ALTER TABLE IF EXISTS public.heatmap_activity ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view own heatmap activity" ON public.heatmap_activity;
    DROP POLICY IF EXISTS "Users can insert own heatmap activity" ON public.heatmap_activity;
    DROP POLICY IF EXISTS "Users can update own heatmap activity" ON public.heatmap_activity;
    DROP POLICY IF EXISTS "Service role manages heatmap activity" ON public.heatmap_activity;
END $$;

CREATE POLICY "Users can view own heatmap activity"
    ON public.heatmap_activity FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Service role manages heatmap activity"
    ON public.heatmap_activity FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Disallow client direct mutations on heatmap
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.heatmap_activity FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.heatmap_activity TO authenticated;
GRANT ALL ON public.heatmap_activity TO service_role;

-- ------------------------------------------------------------------------------
-- 5. forum_posts & forum_replies: Strict Author Verification Lockdown
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.forum_posts ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can view forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Anyone can create forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can create forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Anyone can update forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authenticated users can update forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can update own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can delete their forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Authors can delete own forum posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Service role manages forum posts" ON public.forum_posts;
END $$;

CREATE POLICY "Anyone can view forum posts"
    ON public.forum_posts FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Authenticated users can create forum posts"
    ON public.forum_posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own forum posts"
    ON public.forum_posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can delete own forum posts"
    ON public.forum_posts FOR DELETE
    TO authenticated
    USING (auth.uid() = author_id);

CREATE POLICY "Service role manages forum posts"
    ON public.forum_posts FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

ALTER TABLE IF EXISTS public.forum_replies ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Anyone can view forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can view forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Anyone can create forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can create forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Anyone can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authenticated users can update forum replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can update own replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Authors can delete own replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Service role manages forum replies" ON public.forum_replies;
END $$;

CREATE POLICY "Anyone can view forum replies"
    ON public.forum_replies FOR SELECT
    TO anon, authenticated
    USING (true);

CREATE POLICY "Authenticated users can create forum replies"
    ON public.forum_replies FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own forum replies"
    ON public.forum_replies FOR UPDATE
    TO authenticated
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can delete own forum replies"
    ON public.forum_replies FOR DELETE
    TO authenticated
    USING (auth.uid() = author_id);

CREATE POLICY "Service role manages forum replies"
    ON public.forum_replies FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- ------------------------------------------------------------------------------
-- 6. Replace Legacy Permissive Service Role Policies on Core Infrastructure
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Service role manages all user devices" ON public.user_devices;
CREATE POLICY "Service role manages all user devices"
    ON public.user_devices FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

DROP POLICY IF EXISTS "Service role manages all notification preferences" ON public.notification_preferences;
CREATE POLICY "Service role manages all notification preferences"
    ON public.notification_preferences FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

DROP POLICY IF EXISTS "Service role manages all notifications" ON public.notifications;
CREATE POLICY "Service role manages all notifications"
    ON public.notifications FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

DROP POLICY IF EXISTS "Service role manages notification outbox" ON public.notification_outbox;
CREATE POLICY "Service role manages notification outbox"
    ON public.notification_outbox FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

DROP POLICY IF EXISTS "service_role_all_app_version_config" ON public.app_version_config;
CREATE POLICY "service_role_all_app_version_config"
    ON public.app_version_config FOR ALL
    TO service_role
    USING ((auth.jwt() ->> 'role') = 'service_role')
    WITH CHECK ((auth.jwt() ->> 'role') = 'service_role');

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
