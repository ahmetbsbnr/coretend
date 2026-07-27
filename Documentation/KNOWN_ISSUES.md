<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Known Issues

Open items at 0.9.0. **None blocks the beta.** Each says why it is open rather
than being quietly closed.

Limitations disclosed to users live in the release notes and in
`Release/latest.template.json` under `knownLimitations`; this file is the
engineering view.

## Accepted for 0.9.0

### 1. Unsigned and not notarized
`security find-identity -v -p codesigning` reports **0 valid identities**. A
Developer ID needs a paid Apple Developer Program membership, which is out of
scope. Gatekeeper rejects the app; `spctl --assess` returns `rejected`.

Disclosed in README, release notes, the download page, `INSTALL_UNSIGNED.md`
and the security documentation. The per-app right-click → Open step is given;
disabling Gatekeeper is never suggested.

**Closes when:** a membership exists. That makes 1.0.0 signed possible.

### 2. Not sandboxed, no hardened runtime
No entitlements file; `codesign` reports `flags=0x2(adhoc)` only.

App Sandbox is incompatible with the product: a tool that scans arbitrary user
directories cannot work inside a container. It relies on user-granted Full Disk
Access, an explicit and revocable grant. Hardened runtime is only meaningful
alongside a Developer ID signature, so enabling it here would add nothing.

**Closes when:** signing becomes possible; then hardened runtime should follow.

### 3. Interactive accessibility unverified
Code-level accessibility is real — 39 labels, 31 hidden decorative elements,
Reduce Motion through a single choke point, WCAG 2.1 contrast asserted in both
directions by tests that run in the suite.

But this environment has no display session, so **interactive VoiceOver,
keyboard traversal, focus visibility and Dynamic Type were never observed.**
Not claimed as verified. See `VISUAL_QA.md`.

**Closes when:** run on a machine with a display and a screen reader.

### 4. No `FocusState` anywhere
Focus order is entirely SwiftUI's default and has never been watched. For a
desktop app, explicit focus order on form-heavy screens would be better.

Not changed for 0.9.0: without a display session a focus-order change cannot be
verified, and altering it blind risks degrading behaviour that may already be
correct.

**Closes when:** interactive QA is possible.

### 5. Sparse SPDX headers
2/86 `.swift`, 5/44 `.sh`, 0/4 `.py` carry SPDX identifiers.

Not a compliance defect — Apache-2.0 is satisfied by the root `LICENSE`, and
`Documentation/LICENSING.md` maps every content type. The narrow consequence is
that a file copied out of the repository in isolation carries no marker.

Deliberately not fixed by bulk-stamping headers onto files whose scope nobody
has checked.

**Closes when:** someone verifies scope per file and adds headers accordingly.

### 6. DMG has no saved icon positions
Writing them needs the Finder, which refused automation here.
`package-dmg.sh` reports `BLOCKED_ENVIRONMENT`. Drag-and-drop works; background
and volume icon are present.

**Closes when:** built on a machine where Finder automation is permitted.

### 7. Incomplete "After" screenshot set
`Documentation/VisualAudit/After/` is partial — no display session. A
completeness gap, not a provenance one.

### 8. Single-machine testing
One Apple Silicon Mac, one macOS version. No multi-hardware or multi-OS
verification, and none claimed. `.github/workflows/compat-matrix.yml` exists but
has never run.

### 9. COREXTEND trademark watch
`COREXTEND` (MIPS Tech, live class 9) is one letter from CoreTend. TMview
returned zero marks containing `coretend` across ~141.8M records, but that is
screening, not clearance.

Not a bar to a free beta. **Attorney review is required before any trademark
filing or commercial use.** No definitive legal validation is claimed anywhere.

### 10. Secret-scanning extras disabled
`secret_scanning_non_provider_patterns` and `secret_scanning_validity_checks`
are `disabled` on the repository. Optional hardening; never claimed as enabled.

### 11. No `NS…UsageDescription` strings in `Info.plist`
macOS supplies default prompts for the TCC-protected folders this app reaches,
so this is not functional breakage — but custom purpose strings would explain
the request in the app's own words. Worth doing before 1.0.

## Unverified until something is pushed

### 12. GitHub licence detection
`LICENSE` was restructured to the verbatim Apache-2.0 text specifically so
GitHub stops reporting `NOASSERTION`. **This has not been confirmed against the
live API**, because nothing has been pushed since the change.

**Verify with:** `gh api repos/ahmetbsbnr/coretend --jq .license.spdx_id`
→ expect `Apache-2.0`.

## Resolved, kept for the record

- **`check-version-consistency.sh` could not run.** It read the local identity
  file instead of overlaying it on the example, so any key the partial override
  omitted raised a `KeyError`. It crashed rather than passing, hiding real
  version drift. Fixed by overlaying both, as the site generator does.
- **`check-legacy-brand-references.sh` was red at `4b70ba7`** despite a handoff
  note claiming every gate was green. Two files name the pre-rename identity on
  purpose; both are allowlisted with reasons.
- **Launch gate was nondeterministic.** `producer | grep -q` let grep exit early
  and SIGPIPE the producer, which under `pipefail` reported failure despite a
  match. Fixed at four sites.
- **The developer's account name was committed** into the security audit, by
  quoting the grep command that searched for it. Caught by
  `check-private-data.sh`, removed in `f9fc560`. Local-only; never pushed.
