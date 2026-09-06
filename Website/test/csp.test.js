// SPDX-License-Identifier: Apache-2.0
// CSP regression: the deployed policy (vercel.json) must stay tight. Any
// broadening is a deliberate, reviewed act — not something a refactor slips in.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

const SITE = join(__dirname, "..");
const cfg = JSON.parse(readFileSync(join(SITE, "vercel.json"), "utf8"));

function csp() {
  for (const rule of cfg.headers || []) {
    for (const h of rule.headers || []) {
      if (h.key.toLowerCase() === "content-security-policy") return h.value;
    }
  }
  throw new Error("no Content-Security-Policy header in vercel.json");
}

const POLICY = csp();
const directive = (name) => {
  const m = POLICY.split(";").map((s) => s.trim()).find((d) => d === name || d.startsWith(name + " "));
  return m ? m.slice(name.length).trim() : null;
};

test("no wildcard / unsafe token anywhere in the CSP", () => {
  assert.ok(!/\*/.test(POLICY), "CSP contains '*'");
  assert.ok(!/unsafe-eval/.test(POLICY), "CSP allows unsafe-eval");
  // 'unsafe-inline' is permitted ONLY for style-src-attr (inline style="" on
  // elements — never a <style> block, never for scripts).
  const inlineHits = [...POLICY.matchAll(/([a-z-]+) [^;]*'unsafe-inline'/g)].map((m) => m[1]);
  assert.deepEqual(inlineHits, ["style-src-attr"],
    `'unsafe-inline' allowed on unexpected directive(s): ${inlineHits.join(", ")}`);
});

test("script-src is self-only: no host, no CDN, no inline, no eval", () => {
  assert.equal(directive("script-src"), "'self'");
  assert.equal(directive("script-src-attr"), "'none'");
});

test("connect-src is same-origin only (Resend / Postgres are server-side)", () => {
  assert.equal(directive("connect-src"), "'self'");
  assert.ok(!/resend|postgres|neon\.tech|vercel-storage/i.test(POLICY),
    "a backend provider appears as a client connect origin");
});

test("form-action, frame-ancestors and base-uri are locked down", () => {
  assert.equal(directive("form-action"), "'none'");     // forms are fetch-based
  assert.equal(directive("frame-ancestors"), "'none'"); // no embedding
  assert.equal(directive("base-uri"), "'none'");
  assert.equal(directive("object-src"), "'none'");
});

test("img-src only widens to data: (inline SVG / placeholders), nothing remote", () => {
  const v = directive("img-src");
  assert.ok(v === "'self' data:" || v === "'self'", `img-src is '${v}'`);
});

test("default-src is 'self' and every fetch directive is present", () => {
  assert.equal(directive("default-src"), "'self'");
  for (const d of ["script-src", "style-src", "img-src", "font-src", "connect-src",
                   "media-src"]) {
    assert.ok(directive(d) !== null, `missing ${d}`);
  }
});

test("supporting security headers stay strict", () => {
  const header = (k) => {
    for (const r of cfg.headers || []) {
      for (const h of r.headers || []) if (h.key.toLowerCase() === k) return h.value;
    }
    return null;
  };
  assert.equal(header("x-frame-options"), "DENY");
  assert.equal(header("x-content-type-options"), "nosniff");
  assert.equal(header("referrer-policy"), "no-referrer");
  assert.match(header("strict-transport-security") || "", /max-age=\d{7,}/);
  assert.equal(header("cross-origin-opener-policy"), "same-origin");
});
