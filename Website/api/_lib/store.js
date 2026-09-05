// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Persistence contract for the Contact / Community API, with two
// implementations behind one interface:
//
//   memoryStore()   — deterministic, in-process; used by `node --test`.
//   postgresStore() — @vercel/postgres (lazy-imported so the module loads
//                     without the dependency present, e.g. in unit tests).
//
// The interface is intentionally tiny and returns plain objects. Private
// fields (reporter email, rate-limit keys) never travel through a "public"
// method.

"use strict";

const crypto = require("node:crypto");

function newId() {
  return crypto.randomUUID();
}

// ---------------------------------------------------------------------------
// In-memory implementation (tests / local)
// ---------------------------------------------------------------------------

function memoryStore() {
  const contacts = [];
  const submissions = [];
  const reviews = [];
  const rate = new Map(); // key -> { tokens, updatedMs }

  return {
    kind: "memory",

    async insertContact(rec) {
      const row = { id: newId(), createdAt: new Date().toISOString(), status: "new", ...rec };
      contacts.push(row);
      return { id: row.id };
    },

    async insertSubmission(rec) {
      const row = {
        id: newId(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        moderationStatus: "pending",
        publicStatus: "under_review",
        publicTitle: null,
        publicBody: null,
        ...rec,
      };
      submissions.push(row);
      return { id: row.id };
    },

    async getSubmission(id) {
      return submissions.find((s) => s.id === id) || null;
    },

    async listApprovedSubmissions({ type = null, completed = null, limit = 100 } = {}) {
      return submissions
        .filter((s) => s.moderationStatus === "approved" && s.publicConsent === true)
        .filter((s) => (type ? s.type === type : true))
        .filter((s) => (completed === true ? s.publicStatus === "completed" : true))
        .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
        .slice(0, limit)
        .map(publicSubmissionView);
    },

    async listPendingSubmissions({ limit = 200 } = {}) {
      return submissions
        .filter((s) => s.moderationStatus === "pending")
        .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
        .slice(0, limit)
        .map(adminSubmissionView);
    },

    async updateSubmissionModeration(id, patch) {
      const row = submissions.find((s) => s.id === id);
      if (!row) return null;
      if (patch.moderationStatus) row.moderationStatus = patch.moderationStatus;
      if (patch.publicStatus) row.publicStatus = patch.publicStatus;
      if (patch.publicTitle != null) row.publicTitle = patch.publicTitle;
      if (patch.publicBody != null) row.publicBody = patch.publicBody;
      row.updatedAt = new Date().toISOString();
      return adminSubmissionView(row);
    },

    async insertReview(rec) {
      const row = {
        id: newId(),
        createdAt: new Date().toISOString(),
        moderationStatus: "pending",
        ...rec,
      };
      reviews.push(row);
      return { id: row.id };
    },

    // Token-bucket state accessor used by ratelimit.js.
    async rateGet(key) {
      return rate.get(key) || null;
    },
    async rateSet(key, state) {
      rate.set(key, state);
    },

    // test-only introspection
    _dump() {
      return { contacts, submissions, reviews };
    },
  };
}

// ---------------------------------------------------------------------------
// Postgres implementation (production, lazy dependency)
// ---------------------------------------------------------------------------

async function postgresStore() {
  const { sql } = await import("@vercel/postgres");

  return {
    kind: "postgres",

    async insertContact(rec) {
      const { rows } = await sql`
        INSERT INTO contact_messages
          (request_type, name, email, wants_reply, subject, message,
           app_version, macos_version, reproducibility, locale)
        VALUES
          (${rec.requestType}, ${rec.name}, ${rec.email}, ${rec.wantsReply},
           ${rec.subject}, ${rec.message}, ${rec.appVersion}, ${rec.macosVersion},
           ${rec.reproducibility}, ${rec.locale})
        RETURNING id`;
      return { id: rows[0].id };
    },

    async insertSubmission(rec) {
      const { rows } = await sql`
        INSERT INTO community_submissions
          (type, title, body, email, app_version, macos_version, public_consent, locale)
        VALUES
          (${rec.type}, ${rec.title}, ${rec.body}, ${rec.email}, ${rec.appVersion},
           ${rec.macosVersion}, ${rec.publicConsent}, ${rec.locale})
        RETURNING id`;
      return { id: rows[0].id };
    },

    async getSubmission(id) {
      const { rows } = await sql`SELECT * FROM community_submissions WHERE id = ${id}`;
      return rows[0] ? rowToSubmission(rows[0]) : null;
    },

    async listApprovedSubmissions({ type = null, completed = null, limit = 100 } = {}) {
      const cap = Math.min(Number(limit) || 100, 200);
      const { rows } = await sql`
        SELECT id, type, title, public_title, public_body, body, public_status,
               created_at, updated_at
        FROM community_submissions
        WHERE moderation_status = 'approved' AND public_consent = true
          AND (${type}::text IS NULL OR type = ${type})
          AND (${completed}::bool IS NOT TRUE OR public_status = 'completed')
        ORDER BY created_at DESC
        LIMIT ${cap}`;
      return rows.map((r) => publicSubmissionView(rowToSubmission(r)));
    },

    async listPendingSubmissions({ limit = 200 } = {}) {
      const cap = Math.min(Number(limit) || 200, 500);
      const { rows } = await sql`
        SELECT * FROM community_submissions
        WHERE moderation_status = 'pending'
        ORDER BY created_at DESC LIMIT ${cap}`;
      return rows.map((r) => adminSubmissionView(rowToSubmission(r)));
    },

    async updateSubmissionModeration(id, patch) {
      const { rows } = await sql`
        UPDATE community_submissions SET
          moderation_status = COALESCE(${patch.moderationStatus}, moderation_status),
          public_status     = COALESCE(${patch.publicStatus}, public_status),
          public_title      = COALESCE(${patch.publicTitle}, public_title),
          public_body       = COALESCE(${patch.publicBody}, public_body),
          updated_at        = now()
        WHERE id = ${id}
        RETURNING *`;
      return rows[0] ? adminSubmissionView(rowToSubmission(rows[0])) : null;
    },

    async insertReview(rec) {
      const { rows } = await sql`
        INSERT INTO community_reviews (rating, body, name, email, publish_consent, locale)
        VALUES (${rec.rating}, ${rec.body}, ${rec.name}, ${rec.email},
                ${rec.publishConsent}, ${rec.locale})
        RETURNING id`;
      return { id: rows[0].id };
    },

    async rateGet(key) {
      const { rows } = await sql`
        SELECT tokens, updated_ms FROM rate_limit_entries WHERE key = ${key}`;
      return rows[0] ? { tokens: Number(rows[0].tokens), updatedMs: Number(rows[0].updated_ms) } : null;
    },
    async rateSet(key, state) {
      await sql`
        INSERT INTO rate_limit_entries (key, tokens, updated_ms)
        VALUES (${key}, ${state.tokens}, ${state.updatedMs})
        ON CONFLICT (key) DO UPDATE SET tokens = ${state.tokens}, updated_ms = ${state.updatedMs}`;
    },
  };
}

// ---------------------------------------------------------------------------
// Views — the ONLY shapes that leave the store toward a response
// ---------------------------------------------------------------------------

// Public feed row: no email, no raw reporter body unless it was consented AND
// no redacted override was set.
function publicSubmissionView(s) {
  return {
    id: s.id,
    type: s.type,
    title: s.publicTitle || s.title,
    body: s.publicBody || s.body,
    publicStatus: s.publicStatus,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  };
}

// Admin row: adds moderation fields + whether an email is attached (never the
// address itself).
function adminSubmissionView(s) {
  return {
    id: s.id,
    type: s.type,
    title: s.title,
    body: s.body,
    publicTitle: s.publicTitle || null,
    publicBody: s.publicBody || null,
    moderationStatus: s.moderationStatus,
    publicStatus: s.publicStatus,
    publicConsent: s.publicConsent === true,
    hasEmail: Boolean(s.email),
    appVersion: s.appVersion || null,
    macosVersion: s.macosVersion || null,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  };
}

function rowToSubmission(r) {
  return {
    id: r.id,
    type: r.type,
    title: r.title,
    body: r.body,
    email: r.email,
    appVersion: r.app_version,
    macosVersion: r.macos_version,
    publicConsent: r.public_consent,
    locale: r.locale,
    moderationStatus: r.moderation_status,
    publicStatus: r.public_status,
    publicTitle: r.public_title,
    publicBody: r.public_body,
    createdAt: r.created_at instanceof Date ? r.created_at.toISOString() : r.created_at,
    updatedAt: r.updated_at instanceof Date ? r.updated_at.toISOString() : r.updated_at,
  };
}

module.exports = { memoryStore, postgresStore, publicSubmissionView, adminSubmissionView };
