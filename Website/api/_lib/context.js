// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Wires the default production dependencies for an API handler. Every handler
// accepts an optional `deps` override so `node --test` injects fakes and
// never touches Postgres, Resend, or the clock.

"use strict";

const crypto = require("node:crypto");
const { postgresStore } = require("./store");
const { makeMailer } = require("./mail");

let _storePromise = null;
function defaultStore() {
  if (!_storePromise) _storePromise = postgresStore();
  return _storePromise;
}

// Constant-time bearer-token check for the moderation admin surface.
function checkAdmin(req, expected = process.env.ADMIN_TOKEN) {
  const header = String(req.headers.authorization || "");
  const m = header.match(/^Bearer\s+(.+)$/i);
  const provided = m ? m[1].trim() : "";
  if (!expected || !provided) return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

async function buildDeps(overrides = {}) {
  return {
    store: overrides.store || (await defaultStore()),
    mailer: overrides.mailer || makeMailer(),
    now: overrides.now || (() => Date.now()),
    checkAdmin: overrides.checkAdmin || checkAdmin,
  };
}

module.exports = { buildDeps, checkAdmin, defaultStore };
