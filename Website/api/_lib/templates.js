// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// EN/FR transactional email templates. Every interpolated user value passes
// through `esc()` — the HTML bodies never contain raw submitted text, and the
// plain-text bodies never contain a CR that could reach a header (mail.js
// also strips subjects, and validate.js strips control chars on the way in).

"use strict";

function esc(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const WRAP = (bodyHtml) => `<!doctype html><html><body style="margin:0;background:#f6f4ef;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#16191e">
<div style="max-width:560px;margin:0 auto;padding:32px 24px">
<div style="font-weight:600;font-size:15px;letter-spacing:-.01em;color:#0b6e6c;margin-bottom:20px">CoreTend</div>
${bodyHtml}
<hr style="border:none;border-top:1px solid #e3ded4;margin:28px 0 14px">
<div style="font-size:12px;color:#7b7f86">CoreTend — free software for macOS · <a href="https://coretend.ahmetbsbnr.com" style="color:#0b6e6c">coretend.ahmetbsbnr.com</a></div>
</div></body></html>`;

const L = {
  en: {
    ackSubject: (t) => `We received your ${t} message`,
    ackHtml: (name) =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Hi${name ? " " + esc(name) : ""},</p>
<p style="font-size:15px;line-height:1.6">Thanks for reaching out. Your message has been received. If you asked for a reply, a human will get back to you at the address you gave.</p>
<p style="font-size:15px;line-height:1.6">CoreTend does not attach anything from your Mac — only what you typed in the form was sent.</p>`),
    ackText: (name) =>
      `Hi${name ? " " + name : ""},\n\nThanks for reaching out. Your message has been received. If you asked for a reply, a human will get back to you.\n\nCoreTend does not attach anything from your Mac — only what you typed in the form was sent.\n\n— CoreTend`,
    communityAckSubject: "Your CoreTend Community submission was received",
    communityAckHtml: (title) =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Thanks — your submission <strong>${esc(title)}</strong> was received.</p>
<p style="font-size:15px;line-height:1.6">It is <strong>pending review</strong>. Nothing appears publicly until it is approved, and only if you allowed the text to be shown.</p>`),
    communityAckText: (title) =>
      `Thanks — your submission "${title}" was received.\n\nIt is pending review. Nothing appears publicly until it is approved, and only if you allowed the text to be shown.\n\n— CoreTend`,
    reviewAckSubject: "Your CoreTend review was received",
    reviewAckHtml: () =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Thanks for the review. It is private by default; it will only ever be shown publicly if you ticked the box allowing that, and after review.</p>`),
    reviewAckText: () =>
      `Thanks for the review. It is private by default; it will only ever be shown publicly if you ticked the box allowing that, and after review.\n\n— CoreTend`,
    fwdSubject: (type, subject) => `[CoreTend ${type}] ${subject}`,
  },
  fr: {
    ackSubject: (t) => `Nous avons bien reçu votre message (${t})`,
    ackHtml: (name) =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Bonjour${name ? " " + esc(name) : ""},</p>
<p style="font-size:15px;line-height:1.6">Merci de votre message. Il a bien été reçu. Si vous avez demandé une réponse, une personne vous répondra à l’adresse indiquée.</p>
<p style="font-size:15px;line-height:1.6">CoreTend ne joint rien depuis votre Mac — seul ce que vous avez saisi dans le formulaire a été envoyé.</p>`),
    ackText: (name) =>
      `Bonjour${name ? " " + name : ""},\n\nMerci de votre message. Il a bien été reçu. Si vous avez demandé une réponse, une personne vous répondra.\n\nCoreTend ne joint rien depuis votre Mac — seul ce que vous avez saisi dans le formulaire a été envoyé.\n\n— CoreTend`,
    communityAckSubject: "Votre contribution à la communauté CoreTend a été reçue",
    communityAckHtml: (title) =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Merci — votre contribution <strong>${esc(title)}</strong> a été reçue.</p>
<p style="font-size:15px;line-height:1.6">Elle est <strong>en attente de modération</strong>. Rien n’apparaît publiquement avant approbation, et seulement si vous avez autorisé l’affichage du texte.</p>`),
    communityAckText: (title) =>
      `Merci — votre contribution « ${title} » a été reçue.\n\nElle est en attente de modération. Rien n’apparaît publiquement avant approbation, et seulement si vous avez autorisé l’affichage du texte.\n\n— CoreTend`,
    reviewAckSubject: "Votre avis sur CoreTend a été reçu",
    reviewAckHtml: () =>
      WRAP(`<p style="font-size:15px;line-height:1.6">Merci pour votre avis. Il est privé par défaut ; il ne sera affiché publiquement que si vous avez coché la case l’autorisant, et après modération.</p>`),
    reviewAckText: () =>
      `Merci pour votre avis. Il est privé par défaut ; il ne sera affiché publiquement que si vous avez coché la case l’autorisant, et après modération.\n\n— CoreTend`,
    fwdSubject: (type, subject) => `[CoreTend ${type}] ${subject}`,
  },
};

function pick(locale) {
  return L[locale === "fr" ? "fr" : "en"];
}

// The message forwarded to the human inbox. User content is escaped in HTML
// and control-stripped already; kept compact and factual.
function contactForward(v, locale) {
  const t = pick(locale);
  const lines = [
    `Type: ${v.requestType}`,
    v.name ? `Name: ${v.name}` : null,
    `Reply requested: ${v.wantsReply ? "yes" : "no"}`,
    v.email ? `Email: ${v.email}` : "Email: (none given)",
    v.appVersion ? `CoreTend version: ${v.appVersion}` : null,
    v.macosVersion ? `macOS: ${v.macosVersion}` : null,
    v.reproducibility ? `Reproducibility: ${v.reproducibility}` : null,
    "",
    v.message,
  ].filter((x) => x !== null);
  const html = WRAP(
    `<p style="font-size:13px;color:#7b7f86;margin:0 0 12px">New ${esc(v.requestType)} message via the website form.</p>` +
      lines
        .map((l) => `<div style="font-size:14px;line-height:1.6;white-space:pre-wrap">${esc(l)}</div>`)
        .join("")
  );
  return {
    subject: t.fwdSubject(v.requestType, v.subject),
    text: lines.join("\n"),
    html,
  };
}

function communityForward(v, id) {
  const lines = [
    `Type: ${v.type}`,
    `Title: ${v.title}`,
    `Public consent: ${v.publicConsent ? "yes" : "no"}`,
    v.email ? `Contact email: ${v.email}` : "Contact email: (none)",
    v.appVersion ? `CoreTend version: ${v.appVersion}` : null,
    v.macosVersion ? `macOS: ${v.macosVersion}` : null,
    `Moderate: https://coretend.ahmetbsbnr.com/community#${id}`,
    "",
    v.body,
  ].filter((x) => x !== null);
  return {
    subject: `[CoreTend community/${v.type}] ${v.title}`,
    text: lines.join("\n"),
    html: WRAP(
      lines
        .map((l) => `<div style="font-size:14px;line-height:1.6;white-space:pre-wrap">${esc(l)}</div>`)
        .join("")
    ),
  };
}

function reviewForward(v) {
  const lines = [
    `Rating: ${v.rating}/5`,
    v.name ? `Name: ${v.name}` : "Name: (anonymous)",
    v.email ? `Email: ${v.email}` : "Email: (none)",
    `Publish consent: ${v.publishConsent ? "YES" : "no"}`,
    "",
    v.body,
  ];
  return {
    subject: `[CoreTend review] ${v.rating}/5`,
    text: lines.join("\n"),
    html: WRAP(
      lines
        .map((l) => `<div style="font-size:14px;line-height:1.6;white-space:pre-wrap">${esc(l)}</div>`)
        .join("")
    ),
  };
}

module.exports = { pick, esc, contactForward, communityForward, reviewForward, WRAP };
