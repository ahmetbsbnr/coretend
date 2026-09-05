// SPDX-License-Identifier: Apache-2.0
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const community = require("../api/community");
const review = require("../api/community/review");
const admin = require("../api/admin/community");
const { call, makeDeps } = require("./helpers");

const SUB = {
  type: "feature", title: "Dark menu-bar icon variant",
  body: "The menu-bar icon is hard to see on a light menu bar.",
  email: "reporter@example.com", publicConsent: true, locale: "en",
};
const ADMIN_HEADERS = { authorization: "Bearer test-admin-token" };

test("POST submission -> 201 pending; nothing public yet", async () => {
  const deps = makeDeps();
  const res = await call(community.handle, { method: "POST", body: SUB }, deps);
  assert.equal(res.statusCode, 201);
  assert.equal(res.json().status, "pending");

  const feed = await call(community.handle, { method: "GET", url: "/api/community" }, deps);
  assert.deepEqual(feed.json().items, [], "pending item is not in the public feed");
});

test("moderation approve -> item appears in the public feed WITHOUT the email", async () => {
  const deps = makeDeps();
  const created = await call(community.handle, { method: "POST", body: SUB }, deps);
  const id = created.json().id;

  const patched = await call(admin.handle, {
    method: "PATCH", headers: ADMIN_HEADERS,
    body: { id, moderationStatus: "approved", publicStatus: "planned" },
  }, deps);
  assert.equal(patched.statusCode, 200);

  const feed = await call(community.handle, { method: "GET", url: "/api/community" }, deps);
  const items = feed.json().items;
  assert.equal(items.length, 1);
  assert.equal(items[0].publicStatus, "planned");
  assert.equal(items[0].title, SUB.title);
  const raw = JSON.stringify(items);
  assert.ok(!raw.includes("reporter@example.com"), "email must never reach the public feed");
  assert.ok(!("email" in items[0]));
});

test("approved but publicConsent=false is still NOT shown publicly", async () => {
  const deps = makeDeps();
  const created = await call(community.handle, { method: "POST", body: { ...SUB, publicConsent: false } }, deps);
  await call(admin.handle, {
    method: "PATCH", headers: ADMIN_HEADERS, body: { id: created.json().id, moderationStatus: "approved" },
  }, deps);
  const feed = await call(community.handle, { method: "GET", url: "/api/community" }, deps);
  assert.deepEqual(feed.json().items, []);
});

test("pre-publication redaction: publicBody overrides the raw body in the feed", async () => {
  const deps = makeDeps();
  const created = await call(community.handle, {
    method: "POST", body: { ...SUB, body: "It broke at /Users/jane/secret-project, ugh." },
  }, deps);
  await call(admin.handle, {
    method: "PATCH", headers: ADMIN_HEADERS,
    body: { id: created.json().id, moderationStatus: "approved", publicBody: "The icon is hard to see on a light menu bar." },
  }, deps);
  const feed = await call(community.handle, { method: "GET", url: "/api/community" }, deps);
  assert.ok(!JSON.stringify(feed.json().items).includes("/Users/jane"));
});

test("reject keeps it out of the feed", async () => {
  const deps = makeDeps();
  const created = await call(community.handle, { method: "POST", body: SUB }, deps);
  await call(admin.handle, {
    method: "PATCH", headers: ADMIN_HEADERS, body: { id: created.json().id, moderationStatus: "rejected" },
  }, deps);
  const feed = await call(community.handle, { method: "GET", url: "/api/community" }, deps);
  assert.deepEqual(feed.json().items, []);
});

test("feed filters by type and by completed=1", async () => {
  const deps = makeDeps();
  for (const t of ["bug", "feature", "feature"]) {
    const c = await call(community.handle, { method: "POST", body: { ...SUB, type: t, title: `${t} example here` } }, deps);
    await call(admin.handle, {
      method: "PATCH", headers: ADMIN_HEADERS,
      body: { id: c.json().id, moderationStatus: "approved", publicStatus: t === "bug" ? "completed" : "planned" },
    }, deps);
  }
  const features = await call(community.handle, { method: "GET", url: "/api/community?type=feature" }, deps);
  assert.equal(features.json().items.length, 2);
  const completed = await call(community.handle, { method: "GET", url: "/api/community?completed=1" }, deps);
  assert.equal(completed.json().items.length, 1);
});

test("admin GET lists pending with hasEmail but never the address", async () => {
  const deps = makeDeps();
  await call(community.handle, { method: "POST", body: SUB }, deps);
  const res = await call(admin.handle, { method: "GET", headers: ADMIN_HEADERS }, deps);
  assert.equal(res.statusCode, 200);
  const item = res.json().items[0];
  assert.equal(item.hasEmail, true);
  assert.ok(!("email" in item));
  assert.equal(item.moderationStatus, "pending");
});

test("admin without a token -> 401, no hint", async () => {
  const deps = makeDeps({ checkAdmin: () => false });
  const res = await call(admin.handle, { method: "GET" }, deps);
  assert.equal(res.statusCode, 401);
  assert.equal(res.json().error, "unauthorized");
});

test("admin: real constant-time token check accepts the exact token only", async () => {
  const { checkAdmin } = require("../api/_lib/context");
  const req = (auth) => ({ headers: auth ? { authorization: auth } : {} });
  assert.equal(checkAdmin(req("Bearer s3cret"), "s3cret"), true);
  assert.equal(checkAdmin(req("Bearer s3cre"), "s3cret"), false);
  assert.equal(checkAdmin(req("Bearer wrong!"), "s3cret"), false);
  assert.equal(checkAdmin(req(), "s3cret"), false);
  assert.equal(checkAdmin(req("Bearer x"), ""), false, "no configured token => always deny");
});

test("submission honeypot -> 200 ok, nothing stored", async () => {
  const deps = makeDeps();
  const res = await call(community.handle, { method: "POST", body: { ...SUB, website: "http://x" } }, deps);
  assert.equal(res.statusCode, 200);
  assert.equal(deps.store._dump().submissions.length, 0);
});

test("review: private by default; forwarded to feedback@; publish consent surfaced", async () => {
  const deps = makeDeps();
  const res = await call(review.handle, {
    method: "POST", body: { rating: 5, body: "Saved me a lot of disk space.", publishConsent: false, email: "r@example.com" },
  }, deps);
  assert.equal(res.statusCode, 201);
  assert.equal(deps.store._dump().reviews[0].publishConsent, false);
  assert.equal(deps.mailer.sent[0].to[0], "feedback@ahmetbsbnr.com");
  assert.match(deps.mailer.sent[0].text, /Publish consent: no/);
});

test("community submission rate limit trips", async () => {
  const deps = makeDeps();
  let last;
  for (let i = 0; i < 7; i++) {
    last = await call(community.handle, { method: "POST", body: { ...SUB, title: `Idea number ${i} here` } }, deps);
  }
  assert.equal(last.statusCode, 429);
});

test("malformed submission -> 422", async () => {
  const deps = makeDeps();
  const res = await call(community.handle, { method: "POST", body: { type: "bug", title: "x", body: "y" } }, deps);
  assert.equal(res.statusCode, 422);
});
