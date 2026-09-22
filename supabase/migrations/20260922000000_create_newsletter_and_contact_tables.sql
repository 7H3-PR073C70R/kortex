-- =============================================================================
-- Migration: Create newsletter_subscribers table for landing page signups
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),
  email           text        NOT NULL,
  source          text        NOT NULL DEFAULT 'landing_page',
  subscribed_at   timestamptz NOT NULL DEFAULT now(),
  is_active       boolean     NOT NULL DEFAULT true,
  metadata        jsonb                DEFAULT '{}'::jsonb,

  CONSTRAINT newsletter_subscribers_pkey PRIMARY KEY (id),
  CONSTRAINT newsletter_subscribers_email_key UNIQUE (email),
  CONSTRAINT newsletter_subscribers_email_check CHECK (
    email ~* '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$'
    AND length(email) <= 254
  ),
  CONSTRAINT newsletter_subscribers_source_check CHECK (
    source IN ('landing_page', 'contact_form', 'in_app', 'referral', 'other')
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_email       ON public.newsletter_subscribers (email);
CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_active      ON public.newsletter_subscribers (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_subscribed  ON public.newsletter_subscribers (subscribed_at DESC);

-- Comment
COMMENT ON TABLE public.newsletter_subscribers IS
  'Landing page and in-app newsletter signups. One unique record per email.';

-- =============================================================================
-- Row-Level Security
-- =============================================================================
ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;

-- Public cannot SELECT any rows (no data leakage)
-- Only the service_role (Edge Functions) can read/write
CREATE POLICY "newsletter_subscribers_no_public_read"
  ON public.newsletter_subscribers
  FOR SELECT
  USING (false);

-- The anon role is blocked from direct INSERT. Writes go through the Edge Function
-- (which uses the service_role key internally, never exposed to the client).
CREATE POLICY "newsletter_subscribers_no_public_write"
  ON public.newsletter_subscribers
  FOR INSERT
  WITH CHECK (false);

-- Service role bypasses RLS by design – no extra policy needed.

-- =============================================================================
-- Also create contact_inquiries table (if not already present)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.contact_inquiries (
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),
  name            text        NOT NULL,
  email           text        NOT NULL,
  topic           text        NOT NULL DEFAULT 'other',
  message         text        NOT NULL,
  newsletter_optin boolean    NOT NULL DEFAULT false,
  submitted_at    timestamptz NOT NULL DEFAULT now(),
  metadata        jsonb                DEFAULT '{}'::jsonb,

  CONSTRAINT contact_inquiries_pkey PRIMARY KEY (id),
  CONSTRAINT contact_inquiries_topic_check CHECK (
    topic IN ('early_access','exam_past_questions','feature_request','campus_partnership','bug_report','other')
  ),
  CONSTRAINT contact_inquiries_email_check CHECK (length(email) <= 254),
  CONSTRAINT contact_inquiries_name_check   CHECK (length(name)  >= 2 AND length(name) <= 100),
  CONSTRAINT contact_inquiries_message_check CHECK (length(message) >= 5 AND length(message) <= 3000)
);

CREATE INDEX IF NOT EXISTS idx_contact_inquiries_email       ON public.contact_inquiries (email);
CREATE INDEX IF NOT EXISTS idx_contact_inquiries_submitted   ON public.contact_inquiries (submitted_at DESC);

COMMENT ON TABLE public.contact_inquiries IS
  'Contact form submissions from the Kortex landing page.';

ALTER TABLE public.contact_inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contact_inquiries_no_public_read"
  ON public.contact_inquiries
  FOR SELECT
  USING (false);

CREATE POLICY "contact_inquiries_no_public_write"
  ON public.contact_inquiries
  FOR INSERT
  WITH CHECK (false);
