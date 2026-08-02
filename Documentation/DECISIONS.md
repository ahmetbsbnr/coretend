# DECISIONS

## D-W2 — Website adopts the app's Living System directly (2026-07-27)

The prior site was structurally correct but visually too documentary. The
replacement uses the real CoreTend interface as primary proof, Core Bloom as
its motion signature, and the app's semantic palette, spacing, radii, and
150/300/550 ms motion tokens. A small local enhancement script is accepted for
mobile navigation and scroll reveals because it adds no tracking, storage, or
essential-content dependency and respects Reduced Motion.

## D-G1 — Publish through the sanitised-tree boundary (2026-07-27)

GitHub `main` is intentionally a single sanitised public export and has no
merge base with the internal development branch. Publication therefore
creates a new verified export tree with `origin/main` as its parent. This keeps
the PR mergeable while excluding internal continuity/workspace records and
without rewriting `main`, the development branch, or `v0.9.0`.

## D-M2 — New Smart Care screenshot is post-v0.9.0 evidence (2026-07-27)

The newest user-supplied screenshot contains only the CoreTend Smart Care
window and passed complete pixel and metadata review. It is published as a
post-v0.9.0 development-interface image, not evidence of a change included in
the immutable 0.9.0 binary. Metadata-cleaned PNG and WebP exports are used.

## D-M1 — Only supplied ACCEPTED media is integrated (2026-07-27)

The menu-bar PNG and genuine Gatekeeper clip passed full pixel and metadata
review. Rejected footage, the download clip requiring recapture, and all
uncertified ranges remain excluded. Small video is never enlarged.

## D-W1 — First paint is response-level, not a splash screen (2026-07-27)

Production `/` must redirect directly to `/en/index.html`. Each localized page
also carries a tiny light/dark background rule whose exact hash is generated
into CSP. This fixes the white intermediate document and cold CSS gap without
hiding them behind a splash screen.

## D-Q1 — Browser QA always uses an isolated profile (2026-07-27)

Any automated browser run must pass a new `--user-data-dir` under
`/tmp/coretend-agent`, disable background networking, record its PID, stop it,
and remove the profile. A run that omitted isolation was aborted; none of its
browser-profile state or output is used as project evidence.

## D1 — SwiftPM instead of Xcode project (2026-07-19)
Machine has only CommandLineTools; `xcodebuild` unavailable. Project is a SwiftPM package;
the .app bundle is assembled by `Scripts/package-local.sh` (release binary + Info.plist +
ad-hoc codesign). If Xcode is installed later, an .xcodeproj can be generated without
restructuring.

## D2 — Swift Testing instead of XCTest (2026-07-19)
XCTest is not shipped with CommandLineTools. Swift Testing framework is (under
Library/Developer/Frameworks) but needs explicit -F/-rpath flags → `Scripts/test.sh`.

## D3 — Preview mode ON by default (2026-07-19; superseded 2026-08-02)
This historical product decision was superseded by D-R5. The preview-mode
setting and behavior no longer exist in the current app, site or product
fixture; migration v4 removes its retired persisted preference.

## D-R5 — Review, confirm, then move to Trash (2026-08-02)
Scanning is read-only. Every destructive surface presents the selection and
requires an explicit confirmation before execution. `SafetyCenter` accepts
only approved operations, re-validates every path at execution time and uses
the macOS Trash. No user-selectable preview mode remains.

## D4 — Symlinks skipped during scans (2026-07-19)
ScanEngine skips symlinks entirely (no descend, no finding). Prevents loops and
allowlist escapes. Following-with-loop-guard can be added later if a real need appears.

## D5 — macOS deployment target 14 (2026-07-19)
Target machine runs macOS 26; .v14 keeps Observation/NavigationSplitView available with
headroom. No reason to require .v26 APIs yet.

## D6 — Ship v0.5.0 without new screenshots (2026-07-20)
Step D's screenshot capture (`Scripts/capture.sh`) has failed identically in every
session since v0.3.0 because this sandbox has no attached display — not a code bug,
not something a retry fixes. Rather than block the version bump indefinitely on an
environment fact outside the codebase's control, v0.5.0 ships on code-level
verification instead: grep-confirmed design-system component usage per module, real
Release-bundle launches (default + `AppleLanguages (fr-FR)`) with no crash/fault, 0
compiler warnings, 0 failing tests including a new totals-parity regression test.
Documented plainly in KNOWN_LIMITATIONS.md so it isn't mistaken for "screenshots were
skipped" — they were structurally unobtainable here. Next session with a real display
should run `Scripts/capture.sh` per VISUAL_QA.md and fill in Documentation/VisualAudit/After.

---

# 0.9.0 launch decisions (2026-07-27)

Do not reverse these without new technical or legal evidence.

## D-N1 — The name is CoreTend
TMview, aggregating ~80 offices including EUIPO, INPI, USPTO, WIPO and UKIPO,
returns **zero marks containing `coretend`** across 141,856,516 records.
GitHub, npm, PyPI, Homebrew and the Mac App Store are clear. Status:
`PRELIMINARY_CLEARANCE_NO_HIGH_CONFLICT_FOUND`.

Keep using it. **Do not re-run the whole trademark search** — it is recorded in
`CORETEND_TRADEMARK_SCREENING.md`.

## D-N2 — COREXTEND is a WATCH item, not a blocker
`COREXTEND` (MIPS Tech, live class 9) is one letter away, in a different
industry. Not a bar to a free beta.

## D-N3 — No definitive legal validation is claimed
Screening is not clearance. Every document that mentions the name must keep the
recommendation that **an attorney reviews it before any trademark filing or
significant commercial use.** Do not upgrade this language.

## D-N4 — Public identity is "Ahmet" only
The publisher of record is the given name the owner already publishes on their
own GitHub, plus their handle and domain.

**Never infer, publish or invent a surname** from a filesystem path, a system
account name, local metadata, an email address or any technical identifier.
This is absolute.

## D-N5 — The personal address is withheld
`legalAddress` is `null`. Under LCEN Art. 6 III-2 a non-professional publisher
may withhold their personal address provided the host holds their identity;
Vercel Inc. does, via the account. The site states the omission openly.

**Never substitute an invented or inferred address.**

## D-N6 — 0.9.0 unsigned public beta, not 1.0.0 signed
`security find-identity -v -p codesigning` reports 0 valid identities, and a
Developer ID requires a paid membership that is out of scope. That fixes the
outcome. **Do not renumber this to 1.0.0** and never claim it is signed or
notarized. The launch gate refuses any 1.x while this holds.

## D-N7 — Gatekeeper rejection is disclosed, not hidden
`spctl --assess` returns `rejected`. Record it as a rejection everywhere. Give
the per-app right-click → Open step; **never recommend disabling Gatekeeper
system-wide.** The gate fails if release notes contain `spctl --master-disable`.

## D-N8 — PublicIdentity drives the site, and undefined values stay visible
`Website/generate.py` reads `Configuration/PublicIdentity.example.json` and
overlays the gitignored `PublicIdentity.local.json`. Undefined keys render as
literal tokens inside a `placeholder-token` span. **That is the intended failure
mode**, not a bug: better a visible gap than a reassuring legal page over an
undefined publisher.

The example file keeps its bracketed defaults and is the only file excluded
from the placeholder scan. Filling them in would delete the safety net.

## D-N9 — Version lives in the tracked file
`marketingVersion`, `buildNumber` and `channel` belong in
`PublicIdentity.example.json`, not the gitignored local override. They are
public product metadata, not identity; keeping them local made the public
repository advertise a different version from the one being released.

## D-N10 — Export builds a commit, never checks out an orphan
`Scripts/build-public-branch.sh` builds its commit with `commit-tree` against a
throwaway index, leaving the working tree untouched. An earlier orphan-checkout
method destroyed the working tree and failed on a UTF-16 catalogue.

**Never reintroduce** anything that switches branch temporarily, creates an
orphan checkout in the active repository, resets the working tree, or can leave
the repository on an unborn branch.

## D-N11 — Licence presentation changed; licences did not
`LICENSE` is now the verbatim Apache-2.0 text so GitHub stops reporting
`NOASSERTION`. The multi-licence map moved to `Documentation/LICENSING.md`.
Confirmed byte-identical beforehand, so no licence text changed and nothing was
relicensed. **Do not change any licence type without the owner's explicit
instruction.**

## D-N12 — Indexing is one flag
`siteIndexable` drives the per-page robots meta, `robots.txt` and the
`X-Robots-Tag` header together. It stays `false` until the site is verified
reachable — indexing a page nobody can load is a promise nobody can keep.

## D-N13 — Gate exit codes are never read through a pipe
`gate.sh | tail -1` reports `tail`'s status and turns a failure into a pass;
that already caused one bad commit here. Inside gates, avoid
`producer | grep -q`: grep exits at the first match and SIGPIPEs the producer,
which under `pipefail` reports failure despite the match. Capture output into a
variable and match with `case`.
