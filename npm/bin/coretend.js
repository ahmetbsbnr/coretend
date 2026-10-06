#!/usr/bin/env node
// Runs the signed, notarized CoreTend command-line tool. On first use it downloads the release
// archive named in package.json, checks its SHA-256, and keeps it in ~/Library/Caches/coretend.
// Nothing else is downloaded and nothing is sent anywhere.
"use strict";
const { spawnSync } = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const pkg = require("../package.json");

if (process.platform !== "darwin" || process.arch !== "arm64") {
  console.error("coretend runs on macOS with Apple silicon.");
  process.exit(1);
}

const cacheDir = path.join(os.homedir(), "Library", "Caches", "coretend", pkg.version);
const binary = path.join(cacheDir, "coretend");

function download(url, redirects = 5) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { "User-Agent": "coretend-npm" } }, (response) => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location && redirects > 0) {
        response.resume();
        resolve(download(response.headers.location, redirects - 1));
        return;
      }
      if (response.statusCode !== 200) { reject(new Error(`download failed: HTTP ${response.statusCode}`)); return; }
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => resolve(Buffer.concat(chunks)));
      response.on("error", reject);
    }).on("error", reject);
  });
}

async function ensureBinary() {
  if (fs.existsSync(binary)) return;
  const archive = await download(pkg.coretend.url);
  const digest = crypto.createHash("sha256").update(archive).digest("hex");
  if (digest !== pkg.coretend.sha256) throw new Error(`checksum mismatch (expected ${pkg.coretend.sha256}, got ${digest})`);
  fs.mkdirSync(cacheDir, { recursive: true });
  const zip = path.join(cacheDir, "coretend.zip");
  fs.writeFileSync(zip, archive);
  const unzip = spawnSync("/usr/bin/ditto", ["-x", "-k", zip, cacheDir], { stdio: "inherit" });
  fs.rmSync(zip, { force: true });
  if (unzip.status !== 0 || !fs.existsSync(binary)) throw new Error("could not unpack the CoreTend command-line tool");
}

ensureBinary().then(() => {
  const result = spawnSync(binary, process.argv.slice(2), { stdio: "inherit" });
  process.exit(result.status === null ? 1 : result.status);
}).catch((error) => {
  console.error(`coretend: ${error.message}`);
  process.exit(1);
});
