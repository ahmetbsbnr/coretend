# Manual Acceptance Test Plan

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Concrete tests a human must run
on real hardware/network/GUI — this environment is headless (no display) and single-machine, so
these cannot be automated here. Each item references the requirement ID(s) it would close out.

---

## 1. Protection tab visual states (PROTECTION-001)
- **Setup**: on a Mac without `clamscan` installed, launch the built app, open the Protection tab.
- **Expect**: an honest "unavailable" card — not a fake scan progress bar, not a silently-passing
  "0 threats found" result.
- **Then**: `brew install clamav`, relaunch, open Protection tab again, run a real scan against a
  test directory (e.g. containing the EICAR test file).
- **Expect**: a real scan runs, EICAR is detected and reported.
- **Closes out**: PROTECTION-001 (visual evidence), partially SEC-001 (real subprocess behavior
  under a real ClamAV install, not just code inspection).

## 2. VoiceOver walkthrough (A11Y — no baseline requirement ID exists yet)
- **Setup**: enable VoiceOver, navigate the full app (Cleanup, Duplicates, Applications,
  Leftovers, Privacy Cleaner, Protection, Settings) using only VoiceOver + keyboard.
- **Expect**: every interactive control has a label, every destructive action is announced clearly
  before commit, dry-run vs. real-delete state is audibly distinguishable.
- **Closes out**: nothing in the current 28-requirement baseline (no A11Y-* IDs exist yet) — this
  test plan entry exists so session 3's baseline extension has a ready-made test to point at.

## 3. Gatekeeper warning flow on a real unsigned download (SEC-003, DIST-002)
- **Setup**: download the built ZIP/DMG from a real distribution point (not `file://` or a local
  copy) on a clean Mac that has never seen this app before.
- **Expect**: macOS shows the standard "cannot be opened because the developer cannot be
  verified" Gatekeeper dialog; the app is NOT pre-authorized; `INSTALL_UNSIGNED.md`'s documented
  right-click-Open workaround is the only path presented to the user (no `sudo spctl
  --master-disable` or `xattr -cr` shortcuts appear anywhere in the actual UI or in any
  first-run dialog).
- **Closes out**: SEC-003 (real-world confirmation, beyond the doc-text grep this session ran),
  DIST-002.

## 4. Multi-Mac / multi-macOS-version compatibility (MAC-001, MAC-002, MAC-003)
- **Setup**: run the built app on at least 2 different physical Macs (different chip generation if
  possible) and at least 2 different macOS versions within the 14.0+ floor (e.g. 14.x and the
  latest available).
- **Expect**: launches, all tabs functional, no `@Observable`-related crashes, no
  architecture-specific crashes.
- **Closes out**: MAC-003's disclosed limitation ("single physical Mac... no multi-OS or
  multi-hardware verification performed") — this is the test that would let MAC-003 graduate from
  a disclosed limitation to a verified claim.

## 5. Real network-monitor capture during a full app session (PRIV-001)
- **Setup**: run Little Snitch (or equivalent) or `nettop`/Wireshark while exercising every tab and
  action in the app for a full session (scan, dry-run delete, real delete, diagnostic export,
  Protection scan with ClamAV installed).
- **Expect**: zero outbound network connections initiated by the app process.
- **Closes out**: PRIV-001 at full confidence (this session's grep-based verification covers
  known Swift networking symbol names, not e.g. a hypothetical raw syscall path).

## 6. Diagnostic export preview-before-save flow (PRIV-003)
- **Setup**: open Settings > Data, trigger diagnostic export.
- **Expect**: a mandatory preview sheet appears showing the exact report contents before any save
  dialog; username/paths/personal data are visibly redacted in the preview, not just in the
  eventual file.
- **Closes out**: PRIV-003's visual-evidence gap (the redaction logic itself was verified by
  reading `DiagnosticReportTests.swift` this session; the UI gating was not).

## 7. Website on real Vercel deployment (WEB — no baseline requirement ID exists yet)
- **Setup**: deploy `Website/` to Vercel for real (not just `python3 -m http.server` locally),
  confirm the live URL renders correctly across Chrome/Safari/Firefox, mobile viewport, and that
  the legal-identity values render for real. The `LEGAL_NAME_TO_DEFINE` token and its neighbours
  were resolved in the 0.9.0 launch phase (publisher, security contact and domain all set from
  `Configuration/PublicIdentity.local.json`); the site placeholder count is now zero. Re-confirm
  with `Scripts/check-placeholders.sh` against the deployed HTML before any public announcement.
- **Expect**: page loads correctly on Vercel's actual edge network; zero placeholder tokens remain
  in the rendered HTML.
- **Closes out**: nothing in the current baseline directly (no WEB-* IDs exist yet), but per this
  session's brief: "works on Vercel" can only ever be IMPLEMENTED_UNVERIFIED until this test runs,
  and "domain"/"final legal content" are BLOCKED_HUMAN regardless (someone has to actually decide
  the legal entity name, address, and domain — no amount of testing resolves that).

## 8. GitHub Actions workflows on real GitHub infrastructure (OPS — no baseline requirement ID
   exists yet)
- **Setup**: push a branch to a real GitHub remote and let `.github/workflows/*.yml` actually run
  (build, test, any release-drafting workflow).
- **Expect**: workflows complete green on GitHub's actual runners (Ubuntu/macOS images differ from
  this local CommandLineTools-only environment in ways local YAML linting cannot catch — Xcode
  version availability, signing identity absence, etc.).
- **Closes out**: nothing in the current baseline directly. Per this session's brief: every
  workflow-related claim is IMPLEMENTED_UNVERIFIED at best until this runs at least once for real,
  regardless of how clean the YAML looks locally.

## 9. UserContentRoots — folder picker cannot target protected roots (SAFE-004, follow-up)
- **Setup**: in every view that lets a user pick/add a custom scan root (Cleanup, Duplicates),
  attempt to navigate the folder picker to Documents/Desktop/Pictures/Music/Movies/home and select
  it directly.
- **Expect**: either the picker itself restricts selection, or `PathValidator` rejects it
  immediately with a visible error — never a silent scan of a protected root.
- **Closes out**: extends SAFE-003/SAFE-004's code-level guarantee (confirmed this session by
  reading `PathValidator.validate`) to the UI-interaction level, which a unit test cannot reach.
