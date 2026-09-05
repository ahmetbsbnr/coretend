// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// /api/admin/community — the token-gated moderation surface.
//
//   GET   -> list pending submissions (admin view: adds moderation fields +
//            hasEmail, never the email address itself).
//   PATCH -> mutate one submission: moderationStatus (pending|approved|
//            rejected), publicStatus (under_review|planned|in_progress|
//            completed|declined), and optional pre-publication redaction of
//            publicTitle / publicBody.
//
// Auth: `Authorization: Bearer <ADMIN_TOKEN>` — constant-time compared,
// server-side only. A missing/invalid token gets a bare 401 (no hint about
// whether the token exists).

"use strict";

const { json, fail, readJson } = require("../_lib/respond");
const { parseModeration } = require("../_lib/validate");
const { buildDeps } = require("../_lib/context");

async function handle(req, res, deps) {
  if (!deps.checkAdmin(req)) {
    res.setHeader("WWW-Authenticate", 'Bearer realm="coretend-admin"');
    return fail(res, 401, "unauthorized");
  }

  if (req.method === "GET") {
    let items;
    try {
      items = await deps.store.listPendingSubmissions({ limit: 200 });
    } catch (_) {
      return fail(res, 503, "store_unavailable");
    }
    return json(res, 200, { ok: true, items });
  }

  if (req.method === "PATCH" || req.method === "POST") {
    const parsedBody = await readJson(req);
    if (!parsedBody.ok) return fail(res, 400, parsedBody.code);
    const parsed = parseModeration(parsedBody.value);
    if (!parsed.ok) return json(res, 422, { ok: false, error: "invalid", fields: parsed.errors });

    let updated;
    try {
      updated = await deps.store.updateSubmissionModeration(parsed.value.id, parsed.value);
    } catch (_) {
      return fail(res, 503, "store_unavailable");
    }
    if (!updated) return fail(res, 404, "not_found");
    return json(res, 200, { ok: true, item: updated });
  }

  res.setHeader("Allow", "GET, PATCH");
  return fail(res, 405, "method_not_allowed");
}

module.exports = async (req, res) => handle(req, res, await buildDeps());
module.exports.handle = handle;
