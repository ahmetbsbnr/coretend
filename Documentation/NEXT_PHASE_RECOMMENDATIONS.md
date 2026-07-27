# Next Phase Recommendations — grounded in sessions 1-3 findings

Three honest trajectories. None prescribes a version number as an
assumed next step — pick the one whose prerequisites match what's
actually available (human time for legal/signing vs. more machine time
for hardening vs. more product work).

## Trajectory A — Cautious, security-first

Advantages: builds on the strongest existing evidence (security audit is
already the best-scored axis at 80/100; privacy at 90/100). Low risk of
regressing something that currently works.

Risks: doesn't move the project toward being usable by anyone but the
developer — public operability stays at 35/100 indefinitely if this is
the *only* track taken.

Prerequisites: none blocking — all doable with current access.

Recommended milestones:
1. Fix the `LICENSE` dead cross-references (XS, `TECHNICAL_DEBT.md` #1).
2. Upgrade all 22 scripts to `set -euo pipefail`, audit for any script
   relying on a tolerated non-zero exit in a pipe before flipping the
   flag (`TECHNICAL_DEBT.md` #4).
3. Add a real, on-disk (not in-memory-only) audit log for
   delete/quarantine actions — the single highest-value trust feature
   for a security-adjacent tool, and currently the most-cited partial
   feature across two sessions.
4. Run a manual VoiceOver walkthrough of at least the Protection and
   Cleanup screens to convert the accessibility score from "code-reading
   confirmed" to "interaction confirmed."

## Trajectory B — Public-beta-first

Advantages: the packaging pipeline is already solid (`DISTRIBUTION_AUDIT.md`
— zip/dmg build, checksum, extract, launch, quit all verified this
session) — the remaining blockers are mostly human/procedural
(signing cert, legal identity, hosting) rather than more engineering.

Risks: shipping unsigned still means most users hit a Gatekeeper wall on
first launch; shipping to a public repo with placeholder legal text
(`[LEGAL_NAME_TO_DEFINE]` etc.) is a real professionalism/legal risk if
rushed.

Prerequisites (human-gated, out of this audit's scope): resolve legal
identity placeholders, decide on and obtain a signing/notarization path
(or explicitly ship unsigned with very clear install instructions —
`INSTALL_UNSIGNED.md` already exists for this), create the actual GitHub
repo and push.

Recommended milestones:
1. Resolve legal placeholders (website + any repo-facing legal text).
2. Push the repo, verify all 3 GitHub workflows actually run green on
   real GitHub Actions — currently every CI claim in this audit is
   `IMPLEMENTED_UNVERIFIED` because nothing has ever executed remotely.
3. Deploy the website (currently never deployed, structurally ready per
   `WEBSITE_AUDIT.md`).
4. Cut a first real GitHub Release using `release-draft.yml`'s artifacts,
   openly labeled unsigned/prerelease (the workflow already self-checks
   it never claims `signed:true`/`notarized:true`).
5. Get at least one test install on a second physical Mac before calling
   anything "beta" — every session so far has run on one machine only.

## Trajectory C — Full-product-polish-first

Advantages: closes the largest number of real partial-feature gaps
(`PRODUCT_DEBT.md`) before any public exposure — App Updates real
self-check, full view-layer verification for Cloud Cleanup/My
Clutter/Duplicates/Similar Images, persistent audit log.

Risks: highest time cost, and polish work on features nobody outside the
developer has used yet may target the wrong things — without early
external feedback (Trajectory B), "polish" is a guess.

Prerequisites: none blocking, all engineering work.

Recommended milestones:
1. Trace and verify (not just grep-confirm) the SwiftUI view-layer logic
   for the 5 `IMPLEMENTED_UNVERIFIED` features in `FEATURE_INVENTORY.md`.
2. Implement real App Store update-checking instead of the current
   deep-link-only `AppUpdatesView`.
3. Add UI/view-layer tests — currently 100% of the 86 tests are
   engine/persistence/logic-level; zero exercise SwiftUI view state
   directly.
4. Run an automated accessibility scan (Accessibility Inspector or
   equivalent) now that this session confirmed a display is reachable in
   at least some environments — re-attempt `Scripts/capture.sh` in a
   session where the live screen is clear of unrelated content, to
   refresh `Documentation/VisualAudit/After/` beyond the v0.4.0-era set.

## Cross-cutting recommendation (applies to any trajectory)

Every session including this one has run on a single physical Mac,
single macOS version, single architecture. Whichever trajectory is
picked, the single highest-leverage unblock is getting the app onto a
second machine — it would immediately upgrade the "Compatibility" axis
(currently 40/100, the second-lowest score in `PUBLIC_READINESS_SCORECARD.md`)
from asserted-policy to tested-fact.
