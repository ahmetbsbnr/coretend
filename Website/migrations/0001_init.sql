-- SPDX-License-Identifier: Apache-2.0
-- SPDX-FileCopyrightText: The CoreTend Authors
--
-- CoreTend website Contact / Community schema, revision 0001.
-- Applied by `node scripts/migrate.mjs` against POSTGRES_URL. Deterministic
-- and idempotent (IF NOT EXISTS everywhere); the runner records applied
-- files in schema_migrations.

CREATE TABLE IF NOT EXISTS schema_migrations (
  filename    text PRIMARY KEY,
  applied_at  timestamptz NOT NULL DEFAULT now()
);

-- Private inbound messages. Never exposed publicly by any endpoint.
CREATE TABLE IF NOT EXISTS contact_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     timestamptz NOT NULL DEFAULT now(),
  request_type   text NOT NULL CHECK (request_type IN
                   ('general','support','bug','improvement','feature','privacy','security')),
  name           text,
  email          text,
  wants_reply    boolean NOT NULL DEFAULT false,
  subject        text NOT NULL,
  message        text NOT NULL,
  app_version    text,
  macos_version  text,
  reproducibility text CHECK (reproducibility IN ('always','sometimes','once')),
  locale         text NOT NULL DEFAULT 'en',
  status         text NOT NULL DEFAULT 'new' CHECK (status IN ('new','read','closed'))
);
CREATE INDEX IF NOT EXISTS contact_messages_created_idx ON contact_messages (created_at DESC);

-- Community submissions. `email` is private; the public feed reads only the
-- title/body (or their redacted public_* overrides) and never the email.
CREATE TABLE IF NOT EXISTS community_submissions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  type              text NOT NULL CHECK (type IN ('bug','improvement','feature','feedback')),
  title             text NOT NULL,
  body              text NOT NULL,
  email             text,
  app_version       text,
  macos_version     text,
  public_consent    boolean NOT NULL DEFAULT false,
  locale            text NOT NULL DEFAULT 'en',
  moderation_status text NOT NULL DEFAULT 'pending'
                      CHECK (moderation_status IN ('pending','approved','rejected')),
  public_status     text NOT NULL DEFAULT 'under_review'
                      CHECK (public_status IN
                        ('under_review','planned','in_progress','completed','declined')),
  public_title      text,
  public_body       text
);
CREATE INDEX IF NOT EXISTS community_moderation_idx
  ON community_submissions (moderation_status, created_at DESC);
CREATE INDEX IF NOT EXISTS community_public_idx
  ON community_submissions (moderation_status, public_consent, type, created_at DESC);

-- Reviews / testimonials. Private unless publish_consent = true AND approved.
CREATE TABLE IF NOT EXISTS community_reviews (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  rating            smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body              text NOT NULL,
  name              text,
  email             text,
  publish_consent   boolean NOT NULL DEFAULT false,
  locale            text NOT NULL DEFAULT 'en',
  moderation_status text NOT NULL DEFAULT 'pending'
                      CHECK (moderation_status IN ('pending','approved','rejected'))
);

-- Token-bucket rate-limit state. `key` is a salted SHA-256 of the client IP,
-- never the raw address. Rows are transient and safe to prune.
CREATE TABLE IF NOT EXISTS rate_limit_entries (
  key         text PRIMARY KEY,
  tokens      double precision NOT NULL,
  updated_ms  bigint NOT NULL
);
CREATE INDEX IF NOT EXISTS rate_limit_updated_idx ON rate_limit_entries (updated_ms);
