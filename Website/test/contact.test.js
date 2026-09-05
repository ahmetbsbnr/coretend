// SPDX-License-Identifier: Apache-2.0
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { handle } = require("../api/contact");
const { call, makeDeps, makeMailerSpy } = require("./helpers");

const GOOD = {
  requestType: "support", wantsReply: true, email: "user@example.com",
  subject: "Cannot open a folder", message: "A scan can't see my external drive.",
  locale: "en",
};

test("POST valid -> 201, persisted, routed to support@, sender acknowledged", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "POST", body: GOOD }, deps);
  assert.equal(res.statusCode, 201);
  assert.equal(res.json().ok, true);
  assert.equal(deps.store._dump().contacts.length, 1);

  assert.equal(deps.mailer.sent.length, 2, "forward + acknowledgement");
  const fwd = deps.mailer.sent[0];
  assert.equal(fwd.to[0], "support@ahmetbsbnr.com");
  assert.equal(fwd.reply_to, "user@example.com");
  const ack = deps.mailer.sent[1];
  assert.equal(ack.to[0], "user@example.com");
  assert.equal(ack.reply_to, "support@ahmetbsbnr.com");
  assert.match(ack.from, /noreply@ahmetbsbnr\.com/);
});

test("bug/improvement/feature route to feedback@; general to contact@; security to security@", async () => {
  for (const [type, inbox] of [
    ["bug", "feedback@ahmetbsbnr.com"],
    ["feature", "feedback@ahmetbsbnr.com"],
    ["general", "contact@ahmetbsbnr.com"],
    ["security", "security@ahmetbsbnr.com"],
    ["privacy", "privacy@ahmetbsbnr.com"],
  ]) {
    const deps = makeDeps();
    await call(handle, { method: "POST", body: { ...GOOD, requestType: type } }, deps);
    assert.equal(deps.mailer.sent[0].to[0], inbox, type);
  }
});

test("no email + wantsReply=false -> only the forward is sent", async () => {
  const deps = makeDeps();
  const res = await call(handle, {
    method: "POST",
    body: { requestType: "general", wantsReply: false, subject: "A note", message: "Nice work on CoreTend." },
  }, deps);
  assert.equal(res.statusCode, 201);
  assert.equal(deps.mailer.sent.length, 1);
});

test("wantsReply=true without email -> 422 with a field error, nothing stored", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "POST", body: { ...GOOD, email: "" } }, deps);
  assert.equal(res.statusCode, 422);
  assert.equal(res.json().error, "invalid");
  assert.equal(deps.store._dump().contacts.length, 0);
});

test("honeypot filled -> 200 ok but nothing stored or mailed", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "POST", body: { ...GOOD, company: "Spam Inc" } }, deps);
  assert.equal(res.statusCode, 200);
  assert.equal(deps.store._dump().contacts.length, 0);
  assert.equal(deps.mailer.sent.length, 0);
});

test("oversized body -> 413", async () => {
  const deps = makeDeps();
  const huge = "x".repeat(20 * 1024);
  const res = await call(handle, { method: "POST", body: JSON.stringify({ ...GOOD, message: huge }) }, deps);
  assert.equal(res.statusCode, 413);
});

test("invalid JSON -> 400", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "POST", body: "{not json" }, deps);
  assert.equal(res.statusCode, 400);
});

test("GET -> 405 with Allow header", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "GET" }, deps);
  assert.equal(res.statusCode, 405);
  assert.equal(res.getHeader("allow"), "POST");
});

test("rate limit: the 5th attempt in the window is 429", async () => {
  const deps = makeDeps();
  let last;
  for (let i = 0; i < 6; i++) {
    last = await call(handle, { method: "POST", body: { ...GOOD, subject: `Attempt ${i} here` } }, deps);
  }
  assert.equal(last.statusCode, 429);
  assert.ok(Number(last.getHeader("retry-after")) > 0);
});

test("store failure -> 503, no unhandled error", async () => {
  const store = require("../api/_lib/store").memoryStore();
  store.insertContact = async () => { throw new Error("db down"); };
  const deps = makeDeps({ store });
  const res = await call(handle, { method: "POST", body: GOOD }, deps);
  assert.equal(res.statusCode, 503);
  assert.equal(res.json().error, "store_unavailable");
});

test("mail failure after persist -> 202 { mailed:false }, message is still saved", async () => {
  const deps = makeDeps({ mailer: makeMailerSpy({ fail: true }) });
  const res = await call(handle, { method: "POST", body: GOOD }, deps);
  assert.equal(res.statusCode, 202);
  assert.equal(res.json().mailed, false);
  assert.equal(deps.store._dump().contacts.length, 1);
});

test("error responses never contain a stack or internal detail", async () => {
  const deps = makeDeps();
  const res = await call(handle, { method: "POST", body: { requestType: "nope" } }, deps);
  const raw = res.body.toLowerCase();
  assert.ok(!raw.includes("error:"));
  assert.ok(!raw.includes("at object."));
  assert.ok(!raw.includes("/website/api/"));
});
