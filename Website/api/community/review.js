// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// POST /api/community/review — a CoreTend review / testimonial.
//
// Stored as moderation_status = 'pending'. It is PRIVATE unless the sender
// explicitly ticked publishConsent === true, and even then only after
// moderation. A private review is never converted into marketing content.

"use strict";

const { json, fail, readJson, clientKey } = require("../_lib/respond");
const { parseReview, honeypotTripped } = require("../_lib/validate");
const ratelimit = require("../_lib/ratelimit");
const templates = require("../_lib/templates");
const { buildDeps } = require("../_lib/context");

const RATE_SALT = process.env.RATE_SALT || "coretend-review";

async function handle(req, res, deps) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return fail(res, 405, "method_not_allowed");
  }

  const parsedBody = await readJson(req);
  if (!parsedBody.ok) return fail(res, parsedBody.code === "payload_too_large" ? 413 : 400, parsedBody.code);
  const body = parsedBody.value;

  if (honeypotTripped(body)) return json(res, 200, { ok: true });

  const rl = await ratelimit.take(deps.store, clientKey(req, RATE_SALT), {
    capacity: 3,
    windowMs: 30 * 60 * 1000,
    now: deps.now(),
  });
  if (!rl.allowed) {
    res.setHeader("Retry-After", Math.ceil(rl.retryAfterMs / 1000));
    return fail(res, 429, "rate_limited");
  }

  const parsed = parseReview(body);
  if (!parsed.ok) return json(res, 422, { ok: false, error: "invalid", fields: parsed.errors });
  const v = parsed.value;

  let stored;
  try {
    stored = await deps.store.insertReview(v);
  } catch (_) {
    return fail(res, 503, "store_unavailable");
  }

  const fwd = templates.reviewForward(v);
  try {
    await deps.mailer.send({
      to: deps.mailer.addresses.feedback,
      subject: fwd.subject,
      text: fwd.text,
      html: fwd.html,
    });
    if (v.email) {
      const t = templates.pick(v.locale);
      await deps.mailer.send({
        to: v.email,
        replyTo: deps.mailer.addresses.feedback,
        subject: t.reviewAckSubject,
        text: t.reviewAckText(),
        html: t.reviewAckHtml(),
      });
    }
  } catch (_) {
    return json(res, 202, { ok: true, id: stored.id, mailed: false });
  }

  return json(res, 201, { ok: true, id: stored.id, status: "pending" });
}

module.exports = async (req, res) => handle(req, res, await buildDeps());
module.exports.handle = handle;
