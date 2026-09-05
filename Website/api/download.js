// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Resolves the public /download route to the correct CoreTend DMG for a
// release channel, so no per-release edit of vercel.json is ever needed and
// a prerelease can never silently resolve to the stable build.
//
//   /download                  -> current stable DMG
//   /download?channel=stable    -> current stable DMG
//   /download?channel=beta      -> current beta DMG, or stable if no beta is
//                                  published yet (channels.beta === null)
//
// The channel table lives in api/_lib/releases.json. `stable` mirrors
// Configuration/published-release.json (the native updater's source of
// truth); `beta` is filled in only once a real 1.1.0-beta.N artifact exists.
// If everything is missing we fall back to the GitHub "latest release" page
// rather than ever emitting a 404 or a dead file link.

const channels = require("./_lib/releases.json");

const FALLBACK = "https://github.com/ahmetbsbnr/coretend/releases/latest";

module.exports = (req, res) => {
  let channel = "stable";
  try {
    const url = new URL(req.url, `https://${req.headers.host || "coretend.ahmetbsbnr.com"}`);
    const requested = (url.searchParams.get("channel") || "stable").toLowerCase();
    if (requested === "beta" || requested === "stable") channel = requested;
  } catch (_) {
    /* keep the stable default */
  }

  const entry =
    (channel === "beta" && channels.beta && channels.beta.dmgURL && channels.beta) ||
    (channels.stable && channels.stable.dmgURL && channels.stable) ||
    null;

  const target = entry ? entry.dmgURL : FALLBACK;

  res.statusCode = 302;
  res.setHeader("Location", target);
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.end(`Redirecting to ${target}\n`);
};
