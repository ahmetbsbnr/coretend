# Product Debt — sessions 1-3

Partial features, missing states, UX gaps, trust gaps. Not code architecture
debt (see `TECHNICAL_DEBT.md`) — this is what a real user would notice or
be blocked by.

## Partial features / incomplete UX

- **App Updates**: deep-links to the App Store's Updates pane instead of
  checking for updates itself (session 2, `FEATURE_INVENTORY.md`). A user
  clicking "Check for Updates" gets handed off rather than seeing an
  in-app result.
- **Audit log is in-memory only** (session 2 finding) — quarantine/delete
  history does not survive an app restart in the audited state; a user
  who wants to review "what did I delete last week" after relaunching
  cannot.
- **Cloud Cleanup / My Clutter / Duplicates / Similar Images view-layer
  logic**: engines are real and tested, but the surrounding SwiftUI view
  code wasn't traced line-by-line in any session (`IMPLEMENTED_UNVERIFIED`
  in `FEATURE_INVENTORY.md`) — unknown whether every edge case (empty
  state, partial permission, huge result set) renders correctly without
  manual QA.

## Missing states / text

- Design/UI audit this session found `MCMeshView` (Protection's
  containment-mesh motif, `Sources/DesignSystem/MeshView.swift`) is a
  static `Canvas` draw with 4 well-defined states (incomplete/ready/
  scanning/alert) and a VoiceOver-facing `accessibilityDescription` — this
  one is solid. Reduce Motion isn't wired into it because there's no
  animation to reduce (confirmed by reading the file — no `@State`, no
  timers). Not a gap.
- Reduce Motion / Reduce Transparency handling is centralized in the
  design-system components that need it (`MCFragmentView`,
  `MCOverlapStack` read `accessibilityReduceMotion`; `MCCard` reads
  `accessibilityReduceTransparency`) rather than duplicated per-screen —
  `SpaceLensView` and `MyActivityView` additionally read
  `accessibilityReduceMotion` directly for their own animated transitions.
  No screen was found driving an animation without a reduce-motion path
  during this session's spot check, but this was a targeted grep, not an
  exhaustive per-screen manual audit under Reduce Motion turned on.

## Permission gaps

- Full Disk Access / permission-denied states were previously documented
  (`FULL_DISK_ACCESS.md`) but not re-verified end-to-end with a live
  denied-permission run this session (would require toggling real macOS
  TCC permissions, out of scope for a non-interactive audit pass).

## Install / support / first-run / restore / uninstall gaps

- Distribution is unsigned/unnotarized (see `DISTRIBUTION_AUDIT.md`) — the
  *first* thing a real downloading user hits is a Gatekeeper block, and
  `INSTALL_UNSIGNED.md` exists to walk them through overriding it. That's
  a real first-run friction point for anyone who isn't comfortable with
  right-click-Open, not just a documentation gap.
- `UNINSTALL.md` / `Scripts/uninstall.sh` and `test-uninstall.sh` exist and
  pass (4/4, session 1) — uninstall path itself is in reasonable shape.

## User-trust gaps

- No code signature, no notarization — every install requires the user to
  trust an unsigned binary from an unknown publisher.
- No user feedback mechanism verified working end-to-end this session
  beyond GitHub issue templates (which require a public repo that doesn't
  exist yet — `git remote -v` is empty).
- No physical multi-Mac / multi-macOS-version testing — built and tested
  on a single machine (macOS 26.5.1, arm64) across all three audit
  sessions. No Intel Mac coverage, no older macOS version coverage beyond
  the documented `MACOS_VERSION_POLICY.md` claim.
- Website `download.html` is explicit that there's no public release yet
  — honest, but means "download" is currently a dead end for a real
  visitor.
