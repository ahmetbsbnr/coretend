# Audit Evidence — session 3 load-bearing claims

Structured evidence blocks for the most important claims made this
session. Not exhaustive — see the individual audit docs for full detail.

---

**EVIDENCE-DIST-001**
Claim: The zip and dmg release artifacts' checksums/sizes in
`Release/latest.json` match the actual files exactly (session-2 fix holds).
Files: `Release/latest.json`, `Release/CoreTend-0.7.0-arm64-unsigned.{zip,dmg}`
Command: `shasum -a 256 Release/CoreTend-0.7.0-arm64-unsigned.{zip,dmg}`
Result: `0515ea18...` (zip) / `36aae052...` (dmg) — both equal `latest.json`'s
`zipSHA256`/`dmgSHA256`; `ls -la` sizes (2430463 / 2950713) equal
`zipSize`/`dmgSize`.

**EVIDENCE-DIST-002**
Claim: The shipped binary is arm64-only, not a fat/universal binary.
Files: extracted `CoreTend.app/Contents/MacOS/CoreTend`
Command: `file` + `lipo -info` on the extracted binary
Result: `Mach-O 64-bit executable arm64`; `lipo -info` → `Non-fat file ...
architecture: arm64`.

**EVIDENCE-DIST-003**
Claim: The zip archive extracts, launches, and quits cleanly outside the
repo.
Command: `unzip` in a scratch temp dir, `open` the `.app`, `pgrep`,
AppleScript `quit`, `pgrep` again
Result: process appeared after open, disappeared after quit — no crash,
no hang.

**EVIDENCE-DIST-004**
Claim: License files ship inside the distributable zip.
Command: `unzip -l Release/CoreTend-0.7.0-arm64-unsigned.zip | grep -v "\.app/"`
Result: `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` present at zip root.
Symbols: `Scripts/package-zip.sh:19,23`, `Scripts/package-dmg.sh:20`.

**EVIDENCE-WEB-001**
Claim: No analytics/tracker scripts on the website.
Command: `grep -irl "google-analytics|gtag|analytics|facebook.net|hotjar|
mixpanel|segment.io|plausible|fathom" website/en website/fr website/assets`
Result: 2 matches, both prose stating "no analytics" (`en/faq.html`,
`en/privacy.html`), zero actual script tags. Corroborated by
`grep -ohE 'src="https?://[^"]+"|href="https?://[^"]+"' website/en/*.html`
returning zero matches (no external resource loads at all).

**EVIDENCE-WEB-002**
Claim: FR and EN website page sets are structurally identical (13 pages
each).
Command: `find website/en website/fr -type f`
Result: identical basenames in both directories (index, features,
download, documentation, open-source, roadmap, faq, privacy, security,
changelog, licenses, legal, 404).

**EVIDENCE-L10N-001**
Claim: 327 localization keys, 100% EN/FR parity, zero unused keys.
Files: `Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings`,
`.../fr.lproj/Localizable.strings`
Command: extracted `^"key"` lines from both files, sorted+diffed; then for
each of the 327 base keys, `grep -rlF '"key"' Sources/CoreTendApp` excluding
the Resources dir.
Result: `diff` of key sets → 0 lines different; unused-key count → 0/327.

**EVIDENCE-L10N-002**
Claim: Only one hardcoded, non-localized `Text("...")` literal exists in
the app, and it's the correct exception (the product name).
Command: `grep -rn 'Text("' Sources/CoreTendApp --include="*.swift" | grep
-v 'Text(L(' | grep -v '""'`
Result: 1 match — `Sources/CoreTendApp/OnboardingView.swift:57:
Text("CoreTend")`.

**EVIDENCE-CI-001**
Claim: All 3 GitHub workflows declare `permissions: contents: read`, use
no `pull_request_target`, and reference no secrets.
Files: `.github/workflows/ci.yml`, `release-draft.yml`, `security.yml`
Command: `cat` all three, manual read.
Result: all three top-level `permissions: contents: read`; `on:` triggers
are `pull_request`/`push: branches: [main]`/`workflow_dispatch` only;
`release-draft.yml` explicitly comments it "does NOT publish a GitHub
Release... does NOT need any Apple secret"; no `secrets.` reference found
in any of the three files.
Status: **IMPLEMENTED_UNVERIFIED** — none of these workflows have ever run
on real GitHub Actions (no remote configured, per `git remote -v` empty
across all sessions), so this is YAML-correctness verification only.

**EVIDENCE-CI-002**
Claim: `security.yml`'s secret-scan step is intentionally a plain grep,
not an entropy-based scanner, self-documented as a known limitation.
File: `.github/workflows/security.yml`
Evidence: inline comment at the "Secret scan (grep-based)" step: `ponytail:
plain grep, not a full entropy scanner; upgrade to gitleaks/trufflehog if
false negatives show up in practice.`

**EVIDENCE-SCRIPTS-001**
Claim: 22/22 shell scripts have at least `set -e`; only 1/22 has the
stricter `set -euo pipefail`.
Command: `for f in Scripts/*.sh; do grep -m1 "^set " "$f"; done | sort |
uniq -c`
Result: `10 set -e`, `11 set -eu`, `1 set -euo pipefail`.

**EVIDENCE-PROTECTION-001**
Claim: Protection's `MCMeshView` containment-mesh motif is a real,
state-driven visualization (not decorative), and correctly has no
Reduce-Motion handling because it has no animation.
File: `Sources/DesignSystem/MeshView.swift` (full file read this session)
Evidence: doc comment: `"completeness" (0...1) is real — driven by
whether the engine is installed/ready, never decorative... Static Canvas
draw — no timers, no cost while idle.` No `@State`, `withAnimation`, or
`Environment` reads present in the file; `.accessibilityHidden(true)` plus
a separate `accessibilityDescription` computed property covering all 4
`Style` cases.

**EVIDENCE-A11Y-001**
Claim: Reduce Motion handling exists in the design-system components and
in the two screens with their own animated transitions.
Command: `grep -c "accessibilityReduceMotion" <file>` across all 9 module
views + `Sources/DesignSystem/{OverlapView,FragmentView,MeshView}.swift`
Result: present in `FragmentView.swift`, `OverlapView.swift`,
`SpaceLensView.swift:86`, `MyActivityView.swift:119`. Reduce Transparency
present in `DesignSystem.swift:10` (`MCCard`). Not found (and not
expected, per EVIDENCE-PROTECTION-001) in `MeshView.swift`.

**EVIDENCE-ENV-001**
Claim: A display *is* attached in this session's environment (differs
from the "no display attached" `BLOCKED_ENVIRONMENT` claim recorded in
earlier project phases, e.g. `VISUAL_AUDIT.md`'s v0.4.0-era note).
Command: `screencapture -x <path>` in this session
Result: produced a valid, non-trivial (~4MB) PNG of the live desktop,
confirming display/screen-capture access works in this specific
environment right now. **Not** used to re-capture app screenshots this
session — the live screen showed unrelated foreground content at capture
time, and re-driving the running desktop via AppleScript for a fresh
capture was judged out of scope for a non-interactive audit pass. The
existing dated screenshots in `Documentation/VisualAudit/After/` (dated
2026-07-20, committed at `b8c587d`, v0.4.0 phase) remain the most recent
on-file evidence; this finding should update `KNOWN_LIMITATIONS.md` so a
future session doesn't assume the display constraint still holds
universally — it is environment-dependent, not a permanent sandbox fact.

**EVIDENCE-TEST-001**
Claim: 86/86 tests pass this session (re-run, not just cited from a prior
session).
Command: `bash Scripts/test.sh`
Result: `Test run with 86 tests in 27 suites passed after 0.943 seconds.`
