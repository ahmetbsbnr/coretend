// SPDX-License-Identifier: Apache-2.0
// Regression: server-only secrets must never reach client-visible output or
// an API response body. Uses a synthetic canary; the real token is never
// printed.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { mkdtempSync, readFileSync, readdirSync, statSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join, extname } = require("node:path");

const SITE = join(__dirname, "..");
const SECRET_NAMES = ["ADMIN_TOKEN", "RESEND_API_KEY", "POSTGRES_URL", "AUTH_SECRET",
                      "RATE_SALT"];
const CANARY = "canary-a1b2c3d4e5f60718293a4b5c6d7e8f90"; // 32 hex, obviously fake

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

test("built site contains no secret name or value in any client-served file", () => {
  const OUT = mkdtempSync(join(tmpdir(), "coretend-leak-"));
  execFileSync("python3", ["build.py", "--output", OUT], {
    cwd: SITE,
    stdio: "pipe",
    env: { ...process.env, ...Object.fromEntries(SECRET_NAMES.map((n) => [n, CANARY])) },
  });
  const clientExt = new Set([".html", ".js", ".json", ".map", ".css", ".webmanifest", ".txt"]);
  for (const f of walk(OUT)) {
    if (!clientExt.has(extname(f))) continue;
    const t = readFileSync(f, "utf8");
    assert.ok(!t.includes(CANARY), `${f}: secret value leaked into a client file`);
    for (const name of ["ADMIN_TOKEN", "RESEND_API_KEY", "POSTGRES_URL", "AUTH_SECRET"]) {
      assert.ok(!t.includes(name), `${f}: mentions ${name}`);
    }
  }
});

test("server secrets are referenced only under api/ in the source tree", () => {
  for (const name of ["ADMIN_TOKEN", "RESEND_API_KEY", "POSTGRES_URL"]) {
    const hits = execFileSync("git", ["grep", "-l", "--full-name", `process.env.${name}`], {
      cwd: SITE, encoding: "utf8",
    }).trim().split("\n").filter(Boolean)
      .map((h) => h.replace(/^Website\//, ""));
    // Server code only: the Functions dir and the migration CLI. Never a
    // client asset, never the gold-master HTML, never build.py output.
    for (const h of hits) {
      assert.ok(h.startsWith("api/") || h.startsWith("scripts/"),
                `${name} referenced outside server code: ${h}`);
    }
  }
  // client JS / the gold-master must not name them at all
  for (const f of ["index.html", "assets/shell/public.js"]) {
    const t = readFileSync(join(SITE, f), "utf8");
    for (const name of ["ADMIN_TOKEN", "RESEND_API_KEY", "POSTGRES_URL", "AUTH_SECRET"]) {
      assert.ok(!t.includes(name), `${f}: names ${name}`);
    }
  }
});

test("admin handler never echoes the ADMIN_TOKEN (wrong or right token)", async () => {
  const prev = process.env.ADMIN_TOKEN;
  process.env.ADMIN_TOKEN = CANARY;
  try {
    const { handle } = require("../api/admin/community");
    const { checkAdmin } = require("../api/_lib/context");
    const { call, memoryStore } = require("./helpers");
    const deps = {
      store: memoryStore(),
      mailer: { send: async () => ({ id: "x" }) },
      now: () => 1_700_000_000_000,
      checkAdmin, // the REAL one, reads process.env.ADMIN_TOKEN
    };

    // wrong token -> 401, no canary anywhere in the response
    let res = await call(handle, { method: "GET", headers: { authorization: "Bearer nope" } }, deps);
    assert.equal(res.statusCode, 401);
    assert.ok(!res.body.includes(CANARY));
    assert.ok(!JSON.stringify(res.headers).includes(CANARY));

    // right token -> 200, still never echoes the token
    res = await call(handle, { method: "GET", headers: { authorization: `Bearer ${CANARY}` } }, deps);
    assert.equal(res.statusCode, 200);
    assert.ok(!res.body.includes(CANARY), "200 response echoed the admin token");
  } finally {
    if (prev === undefined) delete process.env.ADMIN_TOKEN;
    else process.env.ADMIN_TOKEN = prev;
  }
});

test("checkAdmin fails closed and does not expose the expected value", () => {
  const { checkAdmin } = require("../api/_lib/context");
  assert.equal(checkAdmin({ headers: {} }, CANARY), false);
  assert.equal(checkAdmin({ headers: { authorization: "Bearer wrong" } }, CANARY), false);
  assert.equal(checkAdmin({ headers: { authorization: `Bearer ${CANARY}` } }, CANARY), true);
  // no expected configured -> always false
  assert.equal(checkAdmin({ headers: { authorization: "Bearer anything" } }, ""), false);
});
