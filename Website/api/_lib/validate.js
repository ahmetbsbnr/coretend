// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Zero-dependency server-side validation for the Contact and Community
// endpoints. Browser validation is UX only; this module is authoritative.
// Every parser returns { ok:true, value } (normalized) or
// { ok:false, errors:[{field,code}] }. Nothing here trusts input length,
// type, or presence.

"use strict";

const CONTACT_TYPES = new Set([
  "general", "support", "bug", "improvement", "feature", "privacy", "security",
]);
const COMMUNITY_TYPES = new Set(["bug", "improvement", "feature", "feedback"]);
const REPRODUCIBILITY = new Set(["always", "sometimes", "once"]);
const MOD_STATUS = new Set(["pending", "approved", "rejected"]);
const PUBLIC_STATUS = new Set([
  "under_review", "planned", "in_progress", "completed", "declined",
]);

const LIMITS = {
  name: 120,
  email: 254,
  subject: 200,
  message: 8000,
  title: 140,
  body: 6000,
  version: 40,
};

// Collapses whitespace runs, strips ALL control chars (incl. CR/LF so a value
// can never be smuggled into an email header), trims. "" for non-strings.
function clean(value, max) {
  if (typeof value !== "string") return "";
  let s = value
    .replace(/[\u0000-\u001F\u007F]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (s.length > max) s = s.slice(0, max);
  return s;
}

// Multi-line clean: keeps "\n", strips every other control char (CR included,
// so header injection via the body is impossible), caps length and blank-line
// runs.
function cleanMultiline(value, max) {
  if (typeof value !== "string") return "";
  let s = value
    .replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0009\u000B-\u001F\u007F]+/g, "")
    .replace(/\n{4,}/g, "\n\n\n")
    .replace(/[ \t]+\n/g, "\n")
    .trim();
  if (s.length > max) s = s.slice(0, max);
  return s;
}

// Deliberately conservative: one @, a dot in the domain, no spaces, no
// header-relevant characters. Not RFC-complete on purpose.
function looksLikeEmail(s) {
  return (
    typeof s === "string" &&
    s.length <= LIMITS.email &&
    /^[^\s@"'<>();:,]+@[^\s@"'<>();:,]+\.[^\s@"'<>();:,]{2,}$/.test(s)
  );
}

function isBool(v) {
  return v === true || v === false;
}

// A honeypot field that must be empty/absent. Any content => treat as a bot.
function honeypotTripped(body) {
  const v = body && (body.company ?? body.website ?? body.hp);
  return typeof v === "string" && v.trim().length > 0;
}

function parseContact(body) {
  const errors = [];
  const b = body || {};

  const requestType = String(b.requestType || "").toLowerCase();
  if (!CONTACT_TYPES.has(requestType)) errors.push({ field: "requestType", code: "invalid" });

  const name = clean(b.name, LIMITS.name); // optional
  const wantsReply = isBool(b.wantsReply) ? b.wantsReply : false;
  const email = clean(b.email, LIMITS.email);
  if (email && !looksLikeEmail(email)) errors.push({ field: "email", code: "invalid" });
  if (wantsReply && !email) errors.push({ field: "email", code: "required_for_reply" });

  const subject = clean(b.subject, LIMITS.subject);
  if (subject.length < 3) errors.push({ field: "subject", code: "too_short" });

  const message = cleanMultiline(b.message, LIMITS.message);
  if (message.length < 10) errors.push({ field: "message", code: "too_short" });

  const appVersion = clean(b.appVersion, LIMITS.version); // optional
  const macosVersion = clean(b.macosVersion, LIMITS.version); // optional
  let reproducibility = null;
  if (b.reproducibility != null && b.reproducibility !== "") {
    const r = String(b.reproducibility).toLowerCase();
    if (!REPRODUCIBILITY.has(r)) errors.push({ field: "reproducibility", code: "invalid" });
    else reproducibility = r;
  }

  const locale = String(b.locale || "en").toLowerCase() === "fr" ? "fr" : "en";

  if (errors.length) return { ok: false, errors };
  return {
    ok: true,
    value: {
      requestType,
      name: name || null,
      email: email || null,
      wantsReply,
      subject,
      message,
      appVersion: appVersion || null,
      macosVersion: macosVersion || null,
      reproducibility,
      locale,
    },
  };
}

function parseCommunitySubmission(body) {
  const errors = [];
  const b = body || {};

  const type = String(b.type || "").toLowerCase();
  if (!COMMUNITY_TYPES.has(type)) errors.push({ field: "type", code: "invalid" });

  const title = clean(b.title, LIMITS.title);
  if (title.length < 4) errors.push({ field: "title", code: "too_short" });

  const bodyText = cleanMultiline(b.body, LIMITS.body);
  if (bodyText.length < 10) errors.push({ field: "body", code: "too_short" });

  const email = clean(b.email, LIMITS.email); // always optional for community
  if (email && !looksLikeEmail(email)) errors.push({ field: "email", code: "invalid" });

  const appVersion = clean(b.appVersion, LIMITS.version) || null;
  const macosVersion = clean(b.macosVersion, LIMITS.version) || null;

  // publicConsent gates whether the *text* may ever be shown publicly after
  // approval. Default false — an un-consented item can be triaged internally
  // but never published.
  const publicConsent = isBool(b.publicConsent) ? b.publicConsent : false;
  const locale = String(b.locale || "en").toLowerCase() === "fr" ? "fr" : "en";

  if (errors.length) return { ok: false, errors };
  return {
    ok: true,
    value: {
      type,
      title,
      body: bodyText,
      email: email || null,
      appVersion,
      macosVersion,
      publicConsent,
      locale,
    },
  };
}

function parseReview(body) {
  const errors = [];
  const b = body || {};

  const rating = Number(b.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    errors.push({ field: "rating", code: "invalid" });
  }
  const bodyText = cleanMultiline(b.body, LIMITS.body);
  if (bodyText.length < 10) errors.push({ field: "body", code: "too_short" });

  const name = clean(b.name, LIMITS.name) || null; // optional display name
  const email = clean(b.email, LIMITS.email);
  if (email && !looksLikeEmail(email)) errors.push({ field: "email", code: "invalid" });

  // Must be explicitly true to ever be published. Never default-checked.
  const publishConsent = b.publishConsent === true;
  const locale = String(b.locale || "en").toLowerCase() === "fr" ? "fr" : "en";

  if (errors.length) return { ok: false, errors };
  return {
    ok: true,
    value: {
      rating,
      body: bodyText,
      name,
      email: email || null,
      publishConsent,
      locale,
    },
  };
}

// Admin moderation mutation. `token` auth is handled separately.
function parseModeration(body) {
  const errors = [];
  const b = body || {};

  const id = clean(b.id, 64);
  if (!/^[0-9a-f-]{6,64}$/i.test(id)) errors.push({ field: "id", code: "invalid" });

  let moderationStatus = null;
  if (b.moderationStatus != null) {
    const m = String(b.moderationStatus).toLowerCase();
    if (!MOD_STATUS.has(m)) errors.push({ field: "moderationStatus", code: "invalid" });
    else moderationStatus = m;
  }
  let publicStatus = null;
  if (b.publicStatus != null) {
    const p = String(b.publicStatus).toLowerCase();
    if (!PUBLIC_STATUS.has(p)) errors.push({ field: "publicStatus", code: "invalid" });
    else publicStatus = p;
  }
  // Optional pre-publication redaction of the shown text.
  const publicTitle = b.publicTitle != null ? clean(b.publicTitle, LIMITS.title) : null;
  const publicBody = b.publicBody != null ? cleanMultiline(b.publicBody, LIMITS.body) : null;

  if (!moderationStatus && !publicStatus && publicTitle == null && publicBody == null) {
    errors.push({ field: "_", code: "no_change" });
  }
  if (errors.length) return { ok: false, errors };
  return { ok: true, value: { id, moderationStatus, publicStatus, publicTitle, publicBody } };
}

module.exports = {
  parseContact,
  parseCommunitySubmission,
  parseReview,
  parseModeration,
  honeypotTripped,
  looksLikeEmail,
  clean,
  cleanMultiline,
  CONTACT_TYPES,
  COMMUNITY_TYPES,
  PUBLIC_STATUS,
  MOD_STATUS,
  LIMITS,
};
