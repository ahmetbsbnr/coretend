// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// /api/community
//   GET  -> the public feed: APPROVED + publicly-consented submissions only.
//           Filters: ?type=bug|improvement|feature|feedback  ?completed=1
//           Never returns email, moderation notes, or raw un-redacted body
//           when a redaction override exists.
//   POST -> a new submission. Defaults to moderation_status = 'pending';
//           nothing is ever shown publicly on submit.

"use strict";

const { json, fail, readJson, clientKey } = require("./_lib/respond");
const { parseCommunitySubmission, honeypotTripped, COMMUNITY_TYPES } = require("./_lib/validate");
const ratelimit = require("./_lib/ratelimit");
const templates = require("./_lib/templates");
const { buildDeps } = require("./_lib/context");

const RATE_SALT = process.env.RATE_SALT || "coretend-community";

async function handleGet(req, res, deps) {
  let type = null;
  let completed = null;
  try {
    const url = new URL(req.url, "https://coretend.ahmetbsbnr.com");
    const t = url.searchParams.get("type");
    if (t && COMMUNITY_TYPES.has(t)) type = t;
    if (url.searchParams.get("completed") === "1") completed = true;
  } catch (_) {
    /* defaults */
  }

  let items;
  try {
    items = await deps.store.listApprovedSubmissions({ type, completed, limit: 100 });
  } catch (_) {
    return fail(res, 503, "store_unavailable");
  }
  res.setHeader("Cache-Control", "public, max-age=60, stale-while-revalidate=300");
  return json(res, 200, { ok: true, items });
}

async function handlePost(req, res, deps) {
  const parsedBody = await readJson(req);
  if (!parsedBody.ok) return fail(res, parsedBody.code === "payload_too_large" ? 413 : 400, parsedBody.code);
  const body = parsedBody.value;

  if (honeypotTripped(body)) return json(res, 200, { ok: true });

  const now = deps.now();
  const rl = await ratelimit.take(deps.store, clientKey(req, RATE_SALT), {
    capacity: 5,
    windowMs: 15 * 60 * 1000,
    now,
  });
  if (!rl.allowed) {
    res.setHeader("Retry-After", Math.ceil(rl.retryAfterMs / 1000));
    return fail(res, 429, "rate_limited");
  }

  const parsed = parseCommunitySubmission(body);
  if (!parsed.ok) return json(res, 422, { ok: false, error: "invalid", fields: parsed.errors });
  const v = parsed.value;

  let stored;
  try {
    stored = await deps.store.insertSubmission(v);
  } catch (_) {
    return fail(res, 503, "store_unavailable");
  }

  // Notify moderation; acknowledge the submitter only if they gave an email.
  const fwd = templates.communityForward(v, stored.id);
  try {
    await deps.mailer.send({
      to: deps.mailer.addresses.community,
      subject: fwd.subject,
      text: fwd.text,
      html: fwd.html,
    });
    if (v.email) {
      const t = templates.pick(v.locale);
      await deps.mailer.send({
        to: v.email,
        replyTo: deps.mailer.addresses.community,
        subject: t.communityAckSubject,
        text: t.communityAckText(v.title),
        html: t.communityAckHtml(v.title),
      });
    }
  } catch (_) {
    return json(res, 202, { ok: true, id: stored.id, mailed: false });
  }

  return json(res, 201, { ok: true, id: stored.id, status: "pending" });
}

async function handle(req, res, deps) {
  if (req.method === "GET") return handleGet(req, res, deps);
  if (req.method === "POST") return handlePost(req, res, deps);
  res.setHeader("Allow", "GET, POST");
  return fail(res, 405, "method_not_allowed");
}

module.exports = async (req, res) => handle(req, res, await buildDeps());
module.exports.handle = handle;
