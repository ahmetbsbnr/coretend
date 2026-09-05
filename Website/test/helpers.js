// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Test doubles: a minimal req/res pair and injectable deps (in-memory store,
// capturing mailer, fixed clock). No network, no Postgres, no real mail.

"use strict";

const { EventEmitter } = require("node:events");
const { memoryStore } = require("../api/_lib/store");

// A req that streams a JSON body once and carries headers/method/url.
function makeReq({ method = "POST", url = "/", headers = {}, body } = {}) {
  const req = new EventEmitter();
  req.method = method;
  req.url = url;
  req.headers = { "x-forwarded-for": "203.0.113.7", ...headers };
  req.socket = { remoteAddress: "203.0.113.7" };
  req.destroy = () => {};
  process.nextTick(() => {
    if (body !== undefined) {
      req.emit("data", Buffer.from(typeof body === "string" ? body : JSON.stringify(body)));
    }
    req.emit("end");
  });
  return req;
}

function makeRes() {
  const res = {
    statusCode: 200,
    headers: {},
    body: "",
    ended: false,
    setHeader(k, v) {
      this.headers[k.toLowerCase()] = v;
    },
    getHeader(k) {
      return this.headers[k.toLowerCase()];
    },
    end(chunk) {
      if (chunk) this.body += chunk;
      this.ended = true;
    },
    json() {
      try {
        return JSON.parse(this.body);
      } catch (_) {
        return null;
      }
    },
  };
  return res;
}

// A real makeMailer() wired to a capturing transport, so the envelope logic
// in api/_lib/mail.js (From, to-array, subject sanitize, reply_to guard) is
// exercised. `sent` holds the final envelopes handed to the transport.
function makeMailerSpy({ fail = false } = {}) {
  const { makeMailer } = require("../api/_lib/mail");
  const sent = [];
  const mailer = makeMailer({
    transport: async (message) => {
      if (fail) throw new Error("mail_send_failed:503");
      sent.push(message);
      return { id: "test-" + sent.length };
    },
  });
  mailer.sent = sent;
  return mailer;
}

function makeDeps(overrides = {}) {
  return {
    store: overrides.store || memoryStore(),
    mailer: overrides.mailer || makeMailerSpy(),
    now: overrides.now || (() => 1_700_000_000_000),
    checkAdmin: overrides.checkAdmin || ((req) => req.headers.authorization === "Bearer test-admin-token"),
  };
}

async function call(handler, reqOpts, deps) {
  const req = makeReq(reqOpts);
  const res = makeRes();
  await handler(req, res, deps);
  return res;
}

module.exports = { makeReq, makeRes, makeMailerSpy, makeDeps, call, memoryStore };
