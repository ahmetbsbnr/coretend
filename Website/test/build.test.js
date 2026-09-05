// SPDX-License-Identifier: Apache-2.0
// Build-output assertions: runs `python3 build.py` into a temp dir once and
// checks the generated site for the properties this vertical guarantees.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { mkdtempSync, readFileSync, readdirSync, existsSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");

const SITE = join(__dirname, "..");
let OUT;

test.before(() => {
  OUT = mkdtempSync(join(tmpdir(), "coretend-build-"));
  execFileSync("python3", ["build.py", "--output", OUT], { cwd: SITE, stdio: "pipe" });
});

const read = (f) => readFileSync(join(OUT, f), "utf8");
const htmlFiles = () => readdirSync(OUT).filter((f) => f.endsWith(".html"));

test("every expected route is generated (EN + FR)", () => {
  for (const f of [
    "index.html", "en-route.html", "fr-route.html",
    "privacy.html", "support.html", "legal.html", "licenses.html",
    "contact.html", "community.html",
    "fr-privacy.html", "fr-support.html", "fr-contact.html", "fr-community.html",
    "404.html",
  ]) {
    assert.ok(existsSync(join(OUT, f)), `missing ${f}`);
  }
});

test("no crypto / verification clutter on any user page", () => {
  for (const f of htmlFiles()) {
    const t = read(f);
    for (const bad of ["minisign", "SHA256SUMS", "shasum", "xcrun stapler", "spctl "]) {
      assert.ok(!t.includes(bad), `${f} contains "${bad}"`);
    }
    assert.ok(!/SHA-?256/i.test(t.replace(/latest\.json/g, "")), `${f} mentions SHA-256`);
  }
  for (const f of readdirSync(join(OUT, "assets/generated"))) {
    assert.ok(!/SHA-?256|minisign/i.test(read(join("assets/generated", f))), `${f}`);
  }
});

test("no AI-assistant credit line anywhere in the output", () => {
  for (const f of htmlFiles()) {
    assert.ok(!/Claude \(Anthropic\)|supervised assistant/i.test(read(f)), f);
  }
});

test("no simulated security dialog text", () => {
  for (const f of htmlFiles()) {
    assert.ok(!/checked it for malicious software|Developer ID verified/i.test(read(f)), f);
  }
});

test("Contact page: fetch-based form, all request types, honeypot, no mailto", () => {
  const t = read("contact.html");
  assert.match(t, /data-api-form="\/api\/contact"/);
  for (const v of ["general", "support", "bug", "improvement", "feature", "privacy", "security"]) {
    assert.match(t, new RegExp(`value="${v}"`));
  }
  assert.match(t, /name="company"/); // honeypot
  assert.ok(!/href="mailto:/.test(t), "no mailto fallback in the form");
  assert.match(t, /CoreTend never attaches anything from your Mac/i);
});

test("Community page: feed + submit form with un-checked public consent", () => {
  const t = read("community.html");
  assert.match(t, /id="community-feed"/);
  assert.match(t, /data-api-form="\/api\/community"/);
  assert.match(t, /name="publicConsent"/);
  assert.ok(!/name="publicConsent"[^>]*checked/.test(t), "consent must not be pre-checked");
  assert.match(t, /name="website"/); // honeypot
});

test("nav + footer expose Community and Contact on every shell page", () => {
  for (const f of ["privacy.html", "support.html", "contact.html", "community.html"]) {
    const t = read(f);
    assert.match(t, /href="\/community"/);
    assert.match(t, /href="\/contact"/);
    assert.match(t, /href="\/download"/);
  }
});

test("sitemap lists the new routes; robots allows crawling", () => {
  const sm = read("sitemap.xml");
  for (const p of ["/contact", "/community", "/fr/contact", "/fr/community"]) {
    assert.ok(sm.includes(`<loc>https://coretend.ahmetbsbnr.com${p}</loc>`), p);
  }
  assert.match(read("robots.txt"), /Allow: \//);
});

test("every page has a canonical + EN/FR hreflang pair and is indexable", () => {
  for (const f of ["contact.html", "community.html", "privacy.html"]) {
    const t = read(f);
    assert.match(t, /rel="canonical"/);
    assert.match(t, /hreflang="en"/);
    assert.match(t, /hreflang="fr"/);
    assert.ok(!/name="robots"[^>]*noindex/i.test(t), `${f} is noindex`);
  }
});

test("no server secret leaked into the built site", () => {
  for (const f of htmlFiles().concat(readdirSync(join(OUT, "assets/generated")).map((x) => join("assets/generated", x)))) {
    const t = read(f);
    assert.ok(!/RESEND_API_KEY|ADMIN_TOKEN|POSTGRES_URL|re_[A-Za-z0-9]{20}/.test(t), f);
  }
});
