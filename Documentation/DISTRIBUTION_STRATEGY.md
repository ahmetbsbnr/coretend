<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Distribution strategy: what CoreTend ships, and what it deliberately does not

Written while hardening the release pipeline after the v1.0.0 incident, with a
point-by-point comparison against [TalkInk](https://github.com/hasso5703/talkink),
a macOS app with a comparable shape (Swift, Developer ID, notarized, DMG + ZIP,
public site). The comparison is recorded because the conclusions are not
obvious in either direction: TalkInk is ahead of CoreTend in places, and behind
it in others.

---

## Where each project stands

| | TalkInk | CoreTend |
|---|---|---|
| Release execution | **Local and manual.** Its `release.yml` is explicitly marked *do not use*: it signs ad-hoc, which cannot be notarized and changes the app's TCC identity. Releases are cut by hand on the maintainer's Mac. | **CI on a self-hosted signing runner.** Tag-triggered, reproducible, with the non-exportable key staying on one machine. |
| ZIP built after stapling | Yes — `notarize.sh` stapled first, then packaged | Was **no** (the v1.0.0 defect), now yes |
| Preflight before Apple | Asserts hardened runtime and Developer ID before uploading | Full preflight: version coherence, key registry, CI state, runner, secrets, tools, launch test |
| Verification of *distributed* bytes | **None.** The appcast is generated from the local ZIP; nothing re-checks what GitHub actually serves | Draft → download → verify → publish |
| Checksums / detached signatures | None (relies on Sparkle's EdDSA) | `SHA256SUMS` + Minisign, key resolved per version |
| SBOM / provenance attestation | None | SPDX SBOM + GitHub build attestation |
| Key → version mapping | None; one `SUPublicEDKey` in `Info.plist` | `Configuration/minisign-keys.json`, range-keyed, gated |
| Auto-update | Sparkle, EdDSA-signed appcast | Manual, user-initiated check against `latest.json` |
| Homebrew | Separate tap, bumped by hand | None |
| Runbook | Short, accurate, matches the scripts | `RELEASE_RUNBOOK.md` |

**Adopted from TalkInk:** packaging the distributable archive *after* stapling
(it had this right and CoreTend did not); asserting signing properties before
spending an Apple round trip; and error messages that name the command to run
next (`xcrun notarytool log <id>` rather than "notarization failed").

**Not adopted, with reasons below:** Sparkle, Homebrew, and local manual
releases. TalkInk's release workflow being a documented dead end is a warning,
not a model: a release path that only one machine and one person can execute is
the path CoreTend spent this incident moving away from.

---

## Auto-update: CoreTend does not adopt Sparkle

TalkInk uses Sparkle: an `appcast.xml` served from its site, enclosures signed
with an EdDSA key, in-app download and install.

CoreTend's updater is a **user-initiated check** that fetches
`https://coretend.ahmetbsbnr.com/latest.json`, compares versions, and links to
the release page. It downloads nothing and installs nothing.

Sparkle is not adopted, for four reasons:

1. **It adds a third signing key to manage.** The incident this pipeline was
   hardened after was a key-custody failure: a Minisign key rotated in one place
   and not another. Sparkle would add an EdDSA key whose loss silently ends the
   ability to ship updates to every installed copy — a strictly worse failure
   mode than a Minisign key, which only affects supplemental verification.
2. **It converts a manual, visible action into an automatic one.** CoreTend's
   product position is that it does nothing to a user's Mac without an explicit
   confirmation. An updater that downloads and replaces the application in the
   background contradicts that in the one place where trust matters most.
3. **The feed URL becomes a permanent commitment.** TalkInk already carries the
   cost: it serves the appcast from two locations because installs at or below
   v0.3.3 read the old one. CoreTend has no such obligation yet and should not
   take one on lightly.
4. **It solves a problem CoreTend does not have.** The update check works, and
   nothing in the incident involved users failing to learn about a new version.

This is a decision, not a permanent verdict. If it is revisited, the open
questions are: feed permanence and redirect policy; EdDSA key custody and
rotation (with the same registry discipline as Minisign); minimum-OS gating;
migrating already-installed copies; separate beta and stable channels; and a
path for critical updates and rollback. That work is independent of any
particular version and must not be bundled into a patch release.

---

## Homebrew: not a supported channel

TalkInk publishes a cask in its own tap, bumped by hand after each release with
the published DMG's SHA-256, with `brew livecheck` flagging drift.

CoreTend does not, and this is not a gap to close before a patch release. A cask
is a second distribution surface with its own staleness failure mode: a tap that
lags behind is worse than no tap, because `brew upgrade` silently reports
success while installing an old build — precisely the shape of the bug this
release fixes.

If it is ever added, the constraints are already clear from CoreTend's pipeline:
the cask must be bumped **only after** a stable release is published and
`verify-published-artifacts.sh` has passed, from the SHA-256 recorded in
`release-manifest.json` rather than one computed locally, and never for a
prerelease.

---

## What the site is allowed to say

The site reads `Configuration/published-release.json`, a committed pointer at a
release GitHub is actually serving. It is written by
`Scripts/sync-published-release.sh` **after** publication, never before, and
`Scripts/test-release-sync.sh` gates the agreement between it, the template, the
generated pages and the newest published stable release.

Consequently the site cannot announce a version that does not exist yet, which
is the inverse of the usual failure: a download button pointing at a 404, or at
a build no one verified.
