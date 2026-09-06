// SPDX-License-Identifier: Apache-2.0
// Contract for Website/screenshots.json and the exported web assets.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync, existsSync } = require("node:fs");
const { join } = require("node:path");
const { execFileSync } = require("node:child_process");

const SITE = join(__dirname, "..");
const ROOT = join(SITE, "..");
const manifest = JSON.parse(readFileSync(join(SITE, "screenshots.json"), "utf8"));
const shots = manifest.screenshots;

test("manifest shape: productVersion + a non-empty screenshots array", () => {
  assert.equal(manifest.productVersion, "1.1.0-beta.1");
  assert.ok(Array.isArray(shots) && shots.length >= 40);
});

test("every id is unique", () => {
  const ids = shots.map((s) => s.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("every entry has the required fields with valid values", () => {
  const locales = new Set(["en", "fr"]);
  const themes = new Set(["light", "dark"]);
  for (const s of shots) {
    for (const k of ["id", "module", "state", "locale", "theme", "alt", "notes"]) {
      assert.ok(typeof s[k] === "string" && s[k].length > 0, `${s.id}: bad ${k}`);
    }
    assert.ok(locales.has(s.locale), `${s.id}: locale`);
    assert.ok(themes.has(s.theme), `${s.id}: theme`);
    assert.ok(Number.isInteger(s.width) && s.width > 0, `${s.id}: width`);
    assert.ok(Number.isInteger(s.height) && s.height > 0, `${s.id}: height`);
    assert.equal(typeof s.approved, "boolean", `${s.id}: approved must be boolean`);
    assert.ok(s.alt.length >= 15, `${s.id}: alt text too short`);
  }
});

test("alt text exists for EN and FR of every module/state/theme", () => {
  const key = (s) => `${s.module}|${s.state}|${s.theme}`;
  const byKey = new Map();
  for (const s of shots) {
    byKey.set(key(s) + "|" + s.locale, s.alt);
  }
  for (const s of shots) {
    const other = s.locale === "en" ? "fr" : "en";
    assert.ok(byKey.has(key(s) + "|" + other), `${s.id}: no ${other} counterpart`);
  }
  // FR alt must not be a verbatim copy of the EN alt
  for (const s of shots.filter((x) => x.locale === "fr")) {
    const en = byKey.get(key(s) + "|en");
    assert.notEqual(s.alt, en, `${s.id}: FR alt is a copy of EN`);
  }
});

test("approved:true requires a real source and both 1x/2x outputs", () => {
  for (const s of shots.filter((x) => x.approved)) {
    assert.ok(s.source, `${s.id}: approved with no source`);
    assert.ok(existsSync(join(ROOT, s.source)), `${s.id}: approved source missing`);
    assert.ok(s.web1x && s.web2x, `${s.id}: approved without 1x/2x`);
  }
});

test("every non-null source exists and lives in an approved capture dir", () => {
  const allowed = ["Documentation/VisualAudit/After/", "Website/assets/app/screens/",
                   "Resources/DemoFixtures/"];
  for (const s of shots) {
    if (!s.source) continue;
    assert.ok(existsSync(join(ROOT, s.source)), `${s.id}: source ${s.source} missing`);
    assert.ok(allowed.some((p) => s.source.startsWith(p)),
              `${s.id}: source outside approved dirs`);
  }
});

test("every declared web1x/web2x asset exists on disk", () => {
  for (const s of shots) {
    for (const k of ["web1x", "web2x"]) {
      if (!s[k]) continue;
      assert.ok(existsSync(join(SITE, s[k])), `${s.id}: ${k} ${s[k]} missing`);
    }
  }
});

test("no private path / identity patterns anywhere in the manifest", () => {
  const raw = JSON.stringify(manifest);
  assert.ok(!/\/Users\/(?!demo\b)[A-Za-z0-9._-]+\//.test(raw), "real /Users/ path");
  assert.ok(!/@(?!example\.|demo\.|synthetic\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}"/.test(raw),
            "non-synthetic email");
  assert.ok(!/\b(MacBook|iMac|Mac Studio|Mac mini|Mac Pro)\b/.test(raw), "device name");
});

test("Scripts/site/check-screenshots.py passes", () => {
  execFileSync("python3", [join(ROOT, "Scripts/site/check-screenshots.py")],
              { stdio: "pipe" });
});

test("export is deterministic: re-running produces byte-identical assets", () => {
  execFileSync("python3", [join(ROOT, "Scripts/site/export-screenshots.py")],
              { cwd: ROOT, stdio: "pipe" });
  const out = execFileSync("git", ["status", "--porcelain", "Website/assets/app/screens/"],
                           { cwd: ROOT, encoding: "utf8" });
  assert.equal(out.trim(), "", `export-screenshots.py changed committed assets:\n${out}`);
});
