// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// POST /api/contact — a private message to the CoreTend project.
//
// Flow: method check -> body size/JSON -> honeypot -> rate limit ->
// server-side validation -> persist -> forward to the routed human inbox ->
// acknowledgement to the sender (only if they gave an email). Nothing from
// the user's Mac is ever attached; only the submitted fields are stored/sent.

"use strict";

const { json, fail, readJson, clientKey } = require("./_lib/respond");
const { parseContact, honeypotTripped } = require("./_lib/validate");
const ratelimit = require("./_lib/ratelimit");
const templates = require("./_lib/templates");
const { buildDeps } = require("./_lib/context");

const RATE_SALT = process.env.RATE_SALT || "coretend-contact";

async function handle(req, res, deps) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return fail(res, 405, "method_not_allowed");
  }

  const parsedBody = await readJson(req);
  if (!parsedBody.ok) return fail(res, parsedBody.code === "payload_too_large" ? 413 : 400, parsedBody.code);
  const body = parsedBody.value;

  // Honeypot: a filled hidden field means a bot. Respond 200 so the bot
  // learns nothing, but do nothing.
  if (honeypotTripped(body)) return json(res, 200, { ok: true });

  const now = deps.now();
  const rl = await ratelimit.take(deps.store, clientKey(req, RATE_SALT), {
    capacity: 4,
    windowMs: 10 * 60 * 1000,
    now,
  });
  if (!rl.allowed) {
    res.setHeader("Retry-After", Math.ceil(rl.retryAfterMs / 1000));
    return fail(res, 429, "rate_limited");
  }

  const parsed = parseContact(body);
  if (!parsed.ok) return json(res, 422, { ok: false, error: "invalid", fields: parsed.errors });
  const v = parsed.value;

  let stored;
  try {
    stored = await deps.store.insertContact(v);
  } catch (_) {
    return fail(res, 503, "store_unavailable");
  }

  const inbox = deps.mailer.contactInbox(v.requestType);
  const fwd = templates.contactForward(v, v.locale);
  try {
    await deps.mailer.send({
      to: inbox,
      replyTo: v.email || undefined,
      subject: fwd.subject,
      text: fwd.text,
      html: fwd.html,
    });
    if (v.email) {
      const t = templates.pick(v.locale);
      await deps.mailer.send({
        to: v.email,
        replyTo: inbox,
        subject: t.ackSubject(v.requestType),
        text: t.ackText(v.name),
        html: t.ackHtml(v.name),
      });
    }
  } catch (_) {
    // Persisted but not mailed — surface a soft failure so the UI can tell
    // the user their message is saved and will be read.
    return json(res, 202, { ok: true, id: stored.id, mailed: false });
  }

  return json(res, 201, { ok: true, id: stored.id, mailed: true });
}

module.exports = async (req, res) => handle(req, res, await buildDeps());
module.exports.handle = handle;
