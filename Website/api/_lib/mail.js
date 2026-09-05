// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Transactional mail for the Contact / Community API.
//
//   * Production transport talks to the Resend REST API directly (one
//     `fetch` POST), so there is no SDK dependency and no client-side key.
//   * Tests inject a fake transport via `makeMailer({ transport })` and
//     assert on the captured envelope — no network, no real mail.
//
// RESEND_API_KEY is read only here, server-side.

"use strict";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

// Public-facing project addresses. community@ and noreply@ are
// infrastructure-facing (not shown in the UI as a contact path).
const ADDRESSES = {
  contact: "contact@ahmetbsbnr.com",
  support: "support@ahmetbsbnr.com",
  feedback: "feedback@ahmetbsbnr.com",
  community: "community@ahmetbsbnr.com",
  security: "security@ahmetbsbnr.com",
  privacy: "privacy@ahmetbsbnr.com",
  noreply: "noreply@ahmetbsbnr.com",
};

const FROM = `CoreTend <${ADDRESSES.noreply}>`;

// requestType -> human inbox that should receive it AND be the Reply-To on
// the acknowledgement the sender gets.
const CONTACT_ROUTING = {
  general: ADDRESSES.contact,
  support: ADDRESSES.support,
  bug: ADDRESSES.feedback,
  improvement: ADDRESSES.feedback,
  feature: ADDRESSES.feedback,
  privacy: ADDRESSES.privacy,
  security: ADDRESSES.security,
};

function contactInbox(requestType) {
  return CONTACT_ROUTING[requestType] || ADDRESSES.contact;
}

// Guard: no address handed to the transport may contain a CR/LF or a comma
// (header-injection / unintended multi-recipient). Throws -> caller 500s
// safely without sending.
function assertSafeAddress(addr) {
  if (typeof addr !== "string" || /[\r\n,]/.test(addr) || addr.length > 320) {
    throw new Error("unsafe_mail_address");
  }
  return addr;
}

// The default production transport.
function resendTransport({ apiKey, fetchImpl = globalThis.fetch }) {
  return async function send(message) {
    if (!apiKey) throw new Error("mail_not_configured");
    const res = await fetchImpl(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`mail_send_failed:${res.status}:${detail.slice(0, 200)}`);
    }
    return res.json().catch(() => ({}));
  };
}

function makeMailer({ apiKey = process.env.RESEND_API_KEY, transport, fetchImpl } = {}) {
  const send = transport || resendTransport({ apiKey, fetchImpl });

  return {
    addresses: ADDRESSES,
    contactInbox,

    // Low-level: one email. All addresses guarded.
    async send({ to, replyTo, subject, html, text }) {
      const message = {
        from: FROM,
        to: [assertSafeAddress(to)],
        subject: String(subject || "").replace(/[\r\n]+/g, " ").slice(0, 200),
        html,
        text,
      };
      if (replyTo) message.reply_to = assertSafeAddress(replyTo);
      return send(message);
    },
  };
}

module.exports = { makeMailer, resendTransport, ADDRESSES, FROM, contactInbox, assertSafeAddress };
