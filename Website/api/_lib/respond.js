// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Small HTTP helpers shared by every CoreTend API function. They keep error
// output deterministic and free of stack traces / internal detail.

"use strict";

const MAX_BODY_BYTES = 16 * 1024; // 16 KB — generous for a contact message, hostile to abuse.

function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.end(body);
}

// A single safe error shape. `code` is a short machine string; never a message
// that reflects internal state.
function fail(res, status, code) {
  json(res, status, { ok: false, error: code });
}

// Read and JSON-parse a request body with a hard size cap. Resolves to
// { ok:true, value } or { ok:false, code }. Never throws.
function readJson(req, maxBytes = MAX_BODY_BYTES) {
  return new Promise((resolve) => {
    // A pre-parsed body (some runtimes populate req.body).
    if (req.body && typeof req.body === "object") {
      resolve({ ok: true, value: req.body });
      return;
    }
    let size = 0;
    const chunks = [];
    let done = false;
    const finish = (result) => {
      if (done) return;
      done = true;
      resolve(result);
    };
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        finish({ ok: false, code: "payload_too_large" });
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (done) return;
      const raw = Buffer.concat(chunks).toString("utf8").trim();
      if (!raw) {
        finish({ ok: true, value: {} });
        return;
      }
      try {
        const value = JSON.parse(raw);
        if (value === null || typeof value !== "object" || Array.isArray(value)) {
          finish({ ok: false, code: "invalid_json" });
          return;
        }
        finish({ ok: true, value });
      } catch (_) {
        finish({ ok: false, code: "invalid_json" });
      }
    });
    req.on("error", () => finish({ ok: false, code: "invalid_json" }));
  });
}

// Best-effort client key for rate limiting: a salted hash of the forwarded
// IP, never the raw address. Falls back to "unknown" so a missing header can
// never bypass the limiter silently (it just shares one bucket).
function clientKey(req, salt) {
  const fwd = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim();
  const ip = fwd || String(req.socket?.remoteAddress || "").trim() || "unknown";
  const crypto = require("node:crypto");
  return crypto.createHash("sha256").update(`${salt}:${ip}`).digest("hex").slice(0, 32);
}

module.exports = { json, fail, readJson, clientKey, MAX_BODY_BYTES };
