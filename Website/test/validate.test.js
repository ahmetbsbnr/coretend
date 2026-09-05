// SPDX-License-Identifier: Apache-2.0
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const v = require("../api/_lib/validate");

test("contact: accepts a well-formed bug report", () => {
  const r = v.parseContact({
    requestType: "bug", wantsReply: true, email: "a@b.co",
    subject: "Crash on scan", message: "It crashes every time I scan Downloads.",
    reproducibility: "always", locale: "fr",
  });
  assert.equal(r.ok, true);
  assert.equal(r.value.locale, "fr");
  assert.equal(r.value.reproducibility, "always");
});

test("contact: wantsReply without email is rejected", () => {
  const r = v.parseContact({ requestType: "general", wantsReply: true, subject: "Hello there", message: "A question about CoreTend." });
  assert.equal(r.ok, false);
  assert.ok(r.errors.some((e) => e.field === "email" && e.code === "required_for_reply"));
});

test("contact: unknown requestType is rejected", () => {
  const r = v.parseContact({ requestType: "spam", subject: "hi there", message: "0123456789abc" });
  assert.equal(r.ok, false);
  assert.ok(r.errors.some((e) => e.field === "requestType"));
});

test("clean strips CR/LF so header injection is impossible", () => {
  const r = v.parseContact({
    requestType: "general", subject: "Subject\r\nBcc: evil@x.com", wantsReply: false,
    message: "line one\r\nline two\r\n\r\n\r\n\r\nline three",
  });
  assert.equal(r.ok, true);
  assert.ok(!r.value.subject.includes("\n"));
  assert.ok(!r.value.subject.includes("\r"));
  assert.ok(!r.value.message.includes("\r"));
  assert.ok(!/\n{4,}/.test(r.value.message));
});

test("community: defaults publicConsent to false", () => {
  const r = v.parseCommunitySubmission({ type: "feature", title: "Dark menu bar icon", body: "Please add a dark variant." });
  assert.equal(r.ok, true);
  assert.equal(r.value.publicConsent, false);
});

test("review: publishConsent must be explicitly true", () => {
  const a = v.parseReview({ rating: 5, body: "Really useful tool for me.", publishConsent: "yes" });
  assert.equal(a.value.publishConsent, false, "string 'yes' is not consent");
  const b = v.parseReview({ rating: 5, body: "Really useful tool for me.", publishConsent: true });
  assert.equal(b.value.publishConsent, true);
});

test("review: rating out of range rejected", () => {
  assert.equal(v.parseReview({ rating: 9, body: "0123456789abc" }).ok, false);
  assert.equal(v.parseReview({ rating: 0, body: "0123456789abc" }).ok, false);
});

test("moderation: id must look like a uuid-ish token and needs a change", () => {
  assert.equal(v.parseModeration({ id: "not a real id!!" }).ok, false);
  assert.equal(v.parseModeration({ id: "abc123-def456" }).ok, false, "no field to change");
  assert.equal(v.parseModeration({ id: "abc123-def456", moderationStatus: "approved" }).ok, true);
  assert.equal(v.parseModeration({ id: "abc123-def456", publicStatus: "orbit" }).ok, false);
});

test("honeypot: any content in company/website/hp trips it", () => {
  assert.equal(v.honeypotTripped({ company: "Acme" }), true);
  assert.equal(v.honeypotTripped({ website: " " }), false);
  assert.equal(v.honeypotTripped({}), false);
});
