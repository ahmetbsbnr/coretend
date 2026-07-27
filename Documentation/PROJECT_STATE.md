<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Project State

Snapshot for session handover. Written 2026-07-27.
For the release specifically, see `RELEASE_STATE.md`.

## What CoreTend is

A local macOS maintenance utility. It finds reclaimable disk space, duplicate
and similar files, large and old files, leftovers from uninstalled apps,
browser caches and cloud-storage usage, and reports what it finds.

It runs entirely on the user's Mac. **No telemetry, no analytics, no account,
no network calls of its own** — substantiated structurally: grepping `Sources/`
for `URLSession`, `NSURLConnection`, `CFNetwork`, `Network` and `socket(`
returns no network client code at all.

## Position

- Branch: `feat/coretend-rebrand-workspace`
- Version: **0.9.0**, unsigned public beta
- Repository: `github.com/ahmetbsbnr/coretend`, public, default branch `main`
- Published history: **one commit** (`b2bca85`) from the sanitised export. The
  private development history has never been pushed.

## Architecture

SwiftPM package, no Xcode project (no Xcode on this machine — Command Line
Tools only, so `xcodebuild` is unavailable).

| Target | Responsibility |
|---|---|
| `CoreTendApp` | SwiftUI app, all screens, onboarding, settings |
| `DesignSystem` | Living System palette, motion, shared components |
| `ScanCore` | Scanning engine, findings |
| `SafetyCore` | Path validation and Trash-based deletion |
| `FileRules` | Cleanup rule catalogue |
| `Persistence` | SQLite store, history, legacy data migration |
| `SystemMetrics` | CPU, memory, disk metrics |
| `AppDiscovery` | Installed apps, update mechanisms |
| `MalwareEngine` | Optional ClamAV integration, quarantine |

**Zero external SwiftPM dependencies.** `Package.swift` declares no
`.package(url:…)` entry.

## Component state

| Component | State |
|---|---|
| Cleanup | Working. Deletion via Trash, through `SafetyCore` path validation. |
| Smart Care | Working. Only reversible low-risk findings auto-execute. |
| My Clutter — Large & Old | Working, **read-only**. No deletion path exists. |
| My Clutter — Duplicates | Working. Keeper never removable; mid-scan edits deselected before trashing. |
| My Clutter — Similar Images | Working, **read-only**. Vision feature-print pipeline. |
| Space Lens | Working, **read-only**. |
| Cloud Cleanup | Working. Never hydrates cloud files to size them. |
| Privacy Cleaner | Working, **cache-only**. History/cookies measured and shown, never deleted. |
| Protection | Working. ClamAV optional; flags for review, no auto-quarantine. |
| Applications / App Updates | Working. |
| My Activity / Safety Log | Working. |
| Onboarding | Working. 8-step wizard, no privilege escalation. |
| Legacy data migration | Working, copy-only, verified once on a real machine. |
| Website | Generated, bilingual, deterministic. Not deployed. |

## Build and test commands

```sh
swift build                     # Debug
swift build -c release          # Release
bash Scripts/test.sh            # tests — ONLY supported runner
python3 Website/generate.py     # site, robots.txt, sitemap.xml, vercel.json
bash Scripts/build-release.sh   # artifacts + Release/latest.json
```

`Scripts/test.sh` is required rather than `swift test`: XCTest ships with Xcode,
which is absent, so the script points at the Swift Testing framework explicitly.

Verified at this state: **296 tests in 58 suites, 0 failures**; Debug and
Release both build clean.

Full gate list: `COMMANDS.md`.

## Site state

Generated and complete; **not deployed**. Reproducible by digest across runs.
Indexing is governed by `siteIndexable` in
`Configuration/PublicIdentity.example.json`, currently `false`, which drives the
per-page robots meta, `robots.txt` and the `X-Robots-Tag` header together.

`coretend.ahmetbsbnr.com` already resolves in DNS but returns 404 — the name
points somewhere real that is not serving this site yet.

## Application state

Builds, tests pass, artifacts produced and verified. **Unsigned and not
notarized**; Gatekeeper rejects it, which is expected and documented rather
than worked around.

## Remaining work

1. Push the tag and publish the GitHub prerelease.
2. Deploy the site to Vercel and confirm the domain.
3. Flip `siteIndexable` to `true` only after the site is verified reachable.
4. Confirm GitHub reports `Apache-2.0` rather than `NOASSERTION` after the push.
5. Open findings in `KNOWN_ISSUES.md` — none blocking for 0.9.0.

## Environment limits

Command Line Tools only, no Xcode, no display session. Interactive VoiceOver,
real keyboard traversal, Dynamic Type and the screenshot campaign cannot be
verified here and are not claimed as verified. One Apple Silicon Mac, one macOS
version — no multi-hardware or multi-OS testing.
