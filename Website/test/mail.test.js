// SPDX-License-Identifier: Apache-2.0
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { makeMailer, resendTransport, assertSafeAddress, FROM } = require("../api/_lib/mail");
const templates = require("../api/_lib/templates");

test("From is CoreTend <noreply@…>; reply_to is set when provided", async () => {
  let captured;
  const mailer = makeMailer({ transport: async (m) => { captured = m; return {}; } });
  await mailer.send({ to: "x@y.co", replyTo: "human@ahmetbsbnr.com", subject: "Hi", html: "<p>hi</p>", text: "hi" });
  assert.equal(captured.from, FROM);
  assert.match(captured.from, /^CoreTend <noreply@ahmetbsbnr\.com>$/);
  assert.equal(captured.reply_to, "human@ahmetbsbnr.com");
  assert.deepEqual(captured.to, ["x@y.co"]);
});

test("subject is single-line (CR/LF collapsed) before it reaches the transport", async () => {
  let captured;
  const mailer = makeMailer({ transport: async (m) => { captured = m; } });
  await mailer.send({ to: "x@y.co", subject: "Line1\r\nBcc: evil@x.com", text: "t" });
  assert.ok(!/[\r\n]/.test(captured.subject));
});

test("assertSafeAddress rejects header-injection / multi-recipient attempts", () => {
  assert.throws(() => assertSafeAddress("a@b.co\r\nBcc: c@d.co"));
  assert.throws(() => assertSafeAddress("a@b.co, e@f.co"));
  assert.throws(() => assertSafeAddress("x".repeat(400)));
  assert.equal(assertSafeAddress("ok@example.com"), "ok@example.com");
});

test("resend transport without an API key throws mail_not_configured (never sends)", async () => {
  const send = resendTransport({ apiKey: "", fetchImpl: async () => { throw new Error("should not be called"); } });
  await assert.rejects(() => send({ from: FROM, to: ["x@y.co"], subject: "s" }), /mail_not_configured/);
});

test("resend transport surfaces a non-2xx as a generic failure (no body leak upstream)", async () => {
  const send = resendTransport({
    apiKey: "re_test",
    fetchImpl: async () => ({ ok: false, status: 422, text: async () => "detailed internal error", json: async () => ({}) }),
  });
  await assert.rejects(() => send({ from: FROM, to: ["x@y.co"], subject: "s" }), /mail_send_failed:422/);
});

test("EN and FR acknowledgement templates are picked by locale and escape user content", () => {
  const en = templates.pick("en");
  const fr = templates.pick("fr");
  assert.match(en.ackSubject("bug"), /received/i);
  assert.match(fr.ackSubject("bug"), /reçu/i);
  const html = fr.communityAckHtml('<script>alert(1)</script> & "co"');
  assert.ok(!html.includes("<script>"));
  assert.ok(html.includes("&lt;script&gt;"));
});

test("contactForward never contains a raw CR and puts the routing type in the subject", () => {
  const fwd = templates.contactForward(
    { requestType: "bug", name: "Jo", wantsReply: true, email: "j@x.co", message: "a\nb", subject: "Crash" },
    "en"
  );
  assert.ok(!fwd.text.includes("\r"));
  assert.match(fwd.subject, /\[CoreTend bug\]/);
});
