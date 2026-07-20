# Master Requirements Baseline

Reconstructed requirements register for MacCare Local, built by reading the historical documentation
and commit history and extracting requirement-shaped statements (must/never/shall/should/interdit).
Each requirement gets a stable ID for later traceability-matrix work (session 2+ of this audit phase).

**Scope note (honest, not exhaustive):** this pass covers the highest-signal sources — DECISIONS.md,
SAFETY_MODEL.md/SAFETYCORE.md, KNOWN_LIMITATIONS.md, COMPATIBILITY.md/MACOS_VERSION_POLICY.md,
CLAMAV.md/PROTECTION_LIMITATIONS.md, LEGAL_AND_LICENSE_STATUS.md, and the prior audit reports — plus
`git log --oneline --all` for phase-defining commits. ROADMAP.md, VISUAL_DIRECTION.md/BRAND_SYSTEM.md/
DESIGN_TOKENS.md/MOTION_SYSTEM.md were read for the VIS-/MOTION- entries below but not mined line by
line for every token value; a deeper visual-requirements pass is explicitly deferred to session 2 (see
`Documentation/CONTINUATION.md`). AUDITED_SOURCE_COMMIT for this baseline: `b33c06b8d68b9b03316821c3f6cfb17252f35011`.

Priority key: **MUST** (hard requirement, violated = defect), **SHOULD** (strong default, documented
exception allowed), **MAY** (optional, discretionary).

---

## SAFE — Safety / deletion model

### SAFE-001 — Scans never delete
- **Wording**: "Scans never delete. Deletion is a separate, explicit step." (`SAFETY_MODEL.md:4`)
- **Priority**: MUST
- **Justification**: prevents silent data loss during a read-only discovery phase.
- **Acceptance criteria**: no scan-path code calls a delete/trash API; deletion only reachable from a
  distinct user-initiated action.
- **Evidence**: `Sources/ScanCore/*Engine.swift` (read-only enumeration), `SafetyCenter` gate before any
  `FileManager.trashItem`. Confirmed by `Documentation/SECURITY_AUDIT_CURRENT.md`'s grep sweep.
- **Current scope**: held.

### SAFE-002 — Deletion engines only accept a validated candidate type, never a raw URL
- **Wording**: "The only type deletion engines accept — never a raw `URL` from the UI"
  (`SAFETYCORE.md:35`); "must pass the right [validated] type" (`SAFETYCORE.md:25`).
- **Priority**: MUST
- **Justification**: forces every deletion path through `PathValidator`/`SafetyCenter`, closing the gap
  where a UI bug could hand an arbitrary path to a delete call.
- **Acceptance criteria**: no deletion function signature in `Sources/` takes a bare `URL` parameter.
- **Evidence**: `Sources/SafetyCore/SafetyCore.swift`.
- **Current scope**: held per `SAFETYCORE.md`; not independently re-verified this session (relies on
  session 2's audit).

### SAFE-003 — Home directory itself is never an auto-selectable deletion target
- **Wording**: "Rejects the user's home directory itself (never auto-select `~`...)" (`SAFETYCORE.md:16`)
- **Priority**: MUST
- **Justification**: catastrophic-scope guard.
- **Evidence**: `SAFETYCORE.md:16`, `SafetyCore.swift` validation logic.
- **Current scope**: held.

### SAFE-004 — User content roots are never auto-included in scan scope
- **Wording**: "User content roots (Documents, Desktop, Pictures, Music, Movies) are never..."
  (`SAFETY_MODEL.md:18`, truncated in source but unambiguous in context — never auto-scanned/deleted).
- **Priority**: MUST
- **Justification**: cleanup tooling must not treat a user's primary content libraries as cleanup targets.
- **Evidence**: `SAFETY_MODEL.md:18`; regression-tested by `ScanCoreTests` "Scan root isolation" suite
  (`downloadsOnlyScanNeverTouchesSiblingDirectories`, confirmed passing in this session's test run).
- **Current scope**: held, test-backed.

### SAFE-005 — Dry-run is the default state
- **Wording**: D3, "SafetyCenter defaults to dryRun=true; the user must explicitly flip the toggle to
  move anything to the Trash." (`DECISIONS.md:13-15`)
- **Priority**: MUST
- **Justification**: safest default for a destructive-capable tool.
- **Evidence**: `SafetyCenter` default value.
- **Current scope**: held.

### SAFE-006 — Symlinks are never followed during scans
- **Wording**: D4, "ScanEngine skips symlinks entirely (no descend, no finding)." (`DECISIONS.md:17-19`)
- **Priority**: MUST
- **Justification**: prevents scan loops and allowlist/scope escapes via symlink traversal.
- **Evidence**: `KNOWN_LIMITATIONS.md:6`; test `hardLinksNotTreatedAsDuplicates` and general scan-root
  isolation suite (passing, this session).
- **Current scope**: held. Decision explicitly leaves room to add loop-guarded following later — no
  such change has happened.

---

## PROTECTION / SEC — Malware scanning and security posture

### PROTECTION-001 — Protection must not fabricate scan capability when ClamAV is absent
- **Wording**: "Protection (malware scanning) requires ClamAV installed locally; when absent the UI
  states this honestly rather than pretending to scan." (`KNOWN_LIMITATIONS.md:7-8`)
- **Priority**: MUST
- **Justification**: false security signal is worse than an honest "unavailable" state.
- **Evidence**: `Sources/MacCareApp/ProtectionView.swift` "unavailable" card path;
  `Documentation/CLAMAV.md`, `PROTECTION_LIMITATIONS.md`.
- **Current scope**: held (re-verified via `Documentation/CLAMAV.md` session-2 note: "the Protection tab
  renders an honest 'unavailable' card when [ClamAV is] absent").

### SEC-001 — No shell-injectable subprocess invocation
- **Wording**: derived from `SECURITY_AUDIT_CURRENT.md`: "the one `Process()` call uses an argument
  array (no shell injection surface)."
- **Priority**: MUST
- **Justification**: the app shells out to `clamscan`; argument-array invocation (not string-interpolated
  shell) is the baseline injection defense.
- **Evidence**: `Sources/MalwareEngine/MalwareEngine.swift:56`.
- **Current scope**: held, per session 2's audit; not re-verified independently this session.

### SEC-002 — No sudo invocations from the app
- **Wording**: SECURITY_AUDIT_CURRENT.md: "zero actual `sudo` invocations (only string-detector
  references)."
- **Priority**: MUST
- **Evidence**: session-2 grep sweep of `Sources/`.
- **Current scope**: held per session 2; not re-verified independently this session (candidate for a
  fresh grep in session 2 of this reconciliation phase).

### SEC-003 — No Gatekeeper/SIP bypass instructions in shipped docs
- **Wording**: `INSTALL_UNSIGNED.md:72`, "Do not work around Gatekeeper by disabling platform security
  instead of trusting this specific app."
- **Priority**: MUST
- **Evidence**: `Scripts/test-release-manifest.sh` "no dangerous Gatekeeper-bypass commands documented
  as steps to follow" check — **passing**, verified fresh this session.
- **Current scope**: held, freshly re-verified.

---

## DIST — Distribution / release manifest

### DIST-001 — SHA256SUMS must verify against the actually-built artifacts
- **Wording**: implicit acceptance criterion of `Scripts/test-release-manifest.sh`; explicitly framed
  as a regression in the script's own comment: "DMG/ZIP output is not byte-reproducible run to run, so
  a rebuild without resync silently desyncs the manifest."
- **Priority**: MUST
- **Origin phase**: found broken in AUDIT SESSION 1 (2 real defects); fixed in commit `88bbb9a`
  ("auto-sync latest.json checksums/sizes on every build").
- **Acceptance criteria**: `bash Scripts/test-release-manifest.sh` exits clean after a fresh
  `Scripts/build-release.sh` run.
- **Evidence**: this session ran a fresh `build-release.sh` + `test-release-manifest.sh` end to end —
  **ALL CHECKS PASSED**, including the specific regression check for this requirement.
- **Current scope**: held, freshly re-verified this session (not just trusted from session 2's claim).

### DIST-002 — Manifest must declare signed/notarized status truthfully
- **Wording**: derived from `test-release-manifest.sh`'s "unsigned/non-notarized declared consistently"
  check.
- **Priority**: MUST
- **Evidence**: `Release/latest.json` `signed:false, notarized:false`, matches `INSTALL_UNSIGNED.md`.
- **Current scope**: held, freshly re-verified this session.

### DIST-003 — sourceCommit in the release manifest should reflect the actual audited/built HEAD
- **Wording**: no prior doc states this explicitly, but it follows from the manifest's purpose
  (a build provenance record) and is the kind of drift this reconciliation session was asked to fix.
- **Priority**: SHOULD
- **Justification**: `Release/latest.json`'s `sourceCommit` was found stale at `99bbe12...` (a commit
  from before the v0.7.0 release commit `b8266a2`, itself since superseded by `b33c06b`) — nothing in
  `Scripts/build-release.sh` sets this field programmatically; it's static JSON content that a human/
  agent must update by hand on each real release cut.
- **Acceptance criteria**: `sourceCommit` matches the commit `Scripts/build-release.sh` was actually run
  against.
- **Current scope**: **fixed this session** (`sourceCommit` updated to `b33c06b...`, `chore(release)`
  commit). **Gap noted, not fixed**: `build-release.sh` has no automated way to stamp this field from
  `git rev-parse HEAD` — a real script improvement, out of scope for a docs-reconciliation session,
  flagged for session 2 or a dedicated `feat(release)` follow-up.

---

## MAC — Platform / compatibility

### MAC-001 — Apple Silicon (arm64) only
- **Wording**: `COMPATIBILITY.md`: "Architecture: Apple Silicon (arm64) only. No Intel build is
  produced."
- **Priority**: MUST (as currently scoped — not a claim that Intel will never be supported, just that
  it isn't today)
- **Evidence**: `Release/latest.json`: `"architecture": "arm64"`.
- **Current scope**: held.

### MAC-002 — macOS 14.0 (Sonoma) minimum, justified by `@Observable`
- **Wording**: `MACOS_VERSION_POLICY.md`: "Floor: macOS 14.0 (Sonoma)... the single binding constraint."
- **Priority**: MUST
- **Justification**: `@Observable` macro requires macOS 14; every other API in use works on macOS 13 or
  earlier per the doc's own audit trail.
- **Acceptance criteria**: raising the floor requires no code change; lowering it requires removing/
  reimplementing all 16 `@Observable` usages.
- **Evidence**: `Package.swift` `.macOS(.v14)`, `API_AVAILABILITY_AUDIT.md`.
- **Current scope**: held.

### MAC-003 — Built/tested on a single physical machine; no multi-OS/hardware verification
- **Wording**: `Release/latest.json` knownLimitations: "Built and tested on a single physical Mac
  (macOS 26.5.1, arm64) — no multi-OS or multi-hardware verification performed."
- **Priority**: this is a documented limitation, not a requirement — included here because it bounds
  the confidence of every MAC- requirement above.
- **Current scope**: unchanged, honestly disclosed.

---

## LEGAL / OSS — Licensing

### LEGAL-001 — Source code under Apache-2.0
- **Wording**: `LICENSE`: "Source code: Apache License 2.0 — see LICENSES/Apache-2.0.txt"
- **Priority**: MUST
- **Evidence**: `LICENSES/Apache-2.0.txt` exists; `LEGAL_AND_LICENSE_STATUS.md` confirms zero SwiftPM
  dependencies to conflict with it.
- **Current scope**: held.

### LEGAL-002 — Original docs/illustrations under CC-BY-4.0
- **Wording**: `LICENSE`: "Original documentation and illustrations: CC-BY-4.0 — see
  LICENSES/CC-BY-4.0.txt"
- **Priority**: MUST
- **Evidence**: `LICENSES/CC-BY-4.0.txt` exists.
- **Current scope**: held.

### LEGAL-003 — Trademark handled separately from code/content licenses
- **Wording**: `LICENSE`: "'MacCare Local' name and logo: see TRADEMARKS.md (not covered by the above
  code/content licenses)"
- **Priority**: MUST
- **Evidence**: `TRADEMARKS.md` exists.
- **Current scope**: held.

### LEGAL-004 — LICENSE cross-references must point at files that exist
- **Wording**: no prior doc states this as a requirement, but it's implied by having cross-references
  at all — a license file pointing at nonexistent files is a real defect (`LEGAL_AND_LICENSE_STATUS.md`
  session-2 finding: "The two broken `LICENSE` cross-references... `Documentation/LICENSING.md`,
  `THIRD_PARTY_NOTICES.md`").
- **Priority**: MUST
- **Current scope**: **fixed this session** — commit `964f110`, `LICENSE` now points at
  `Documentation/LEGAL_AND_LICENSE_STATUS.md` and `Documentation/THIRD_PARTY.md` (the files that
  actually exist).

### OSS-001 — Zero external SwiftPM dependencies
- **Wording**: `DEPENDENCIES.md`: "this repo has zero external SwiftPM dependencies (every target is
  first-party)."
- **Priority**: SHOULD (a deliberate minimalism choice, not an absolute technical constraint)
- **Evidence**: `Package.swift`.
- **Current scope**: held.

### OSS-002 — ClamAV is a runtime-only, never-linked, never-bundled dependency
- **Wording**: `CLAMAV.md`/`PROTECTION_LIMITATIONS.md`: "libclamav is never linked, no ClamAV binaries/
  signatures are bundled, `ClamAVScanner` only probes known Homebrew/MacPorts paths for a
  user-installed `clamscan`."
- **Priority**: MUST
- **Justification**: keeps the GPL-2.0-licensed ClamAV outside the Apache-2.0 codebase's linkage
  boundary — a licensing-compatibility requirement, not just an architecture note.
- **Evidence**: `Sources/MalwareEngine/MalwareEngine.swift`.
- **Current scope**: held.

---

## TEST — Testing

### TEST-001 — `bash Scripts/test.sh` is the only sanctioned test entry point
- **Wording**: this session's own instructions plus D2 in `DECISIONS.md`: "Swift Testing framework...
  needs explicit -F/-rpath flags → `Scripts/test.sh`."
- **Priority**: MUST
- **Justification**: bare `swift test` doesn't have the right linker flags for Swift Testing under
  CommandLineTools-only toolchains (no Xcode).
- **Evidence**: this session ran `bash Scripts/test.sh` — 86/86 tests, 27 suites, passed.
- **Current scope**: held, freshly re-verified this session (86/86, matching `TEST_INVENTORY.md`).

---

## ARCH — Architecture

### ARCH-001 — SwiftPM package, no Xcode project required
- **Wording**: D1, "Machine has only CommandLineTools; `xcodebuild` unavailable. Project is a SwiftPM
  package."
- **Priority**: MUST (environment-driven)
- **Evidence**: `Package.swift`, no `.xcodeproj` in the tree.
- **Current scope**: held.

### ARCH-002 — Native Swift/SwiftUI, no Electron/Tauri/WebView-as-primary-UI
- **Wording**: not written explicitly in any single doc as a "MUST" statement — inferred from the
  entire architecture (9 native SwiftPM targets, zero web-rendering dependency in `Sources/`) and
  confirmed as a deliberate stance in this session's cross-check (see
  `REQUIREMENTS_DECISION_HISTORY.md` "Architecture stance").
- **Priority**: MUST
- **Evidence**: `grep -rl "WKWebView" Sources/` → no matches; `Package.swift` has zero dependencies.
- **Current scope**: held.

---

## PRIV — Privacy / data

### PRIV-001 — No network access from the app
- **Wording**: `PRIVACY_AUDIT_CURRENT.md`: "zero `URLSession`/network-framework/socket usage found
  anywhere in `Sources/`."
- **Priority**: MUST
- **Evidence**: session-2 grep sweep; not re-run independently this session.
- **Current scope**: held per session 2; flagged for independent re-verification in session 2 of this
  reconciliation phase (see `REQUIREMENTS_DECISION_HISTORY.md`).

### PRIV-002 — No telemetry, no account system
- **Wording**: `Release/latest.json`: `"telemetry": false, "accountRequired": false`.
- **Priority**: MUST
- **Evidence**: manifest field, cross-checked against `PRIVACY_AUDIT_CURRENT.md`'s code-level finding of
  zero analytics/crash-reporter/account-system code.
- **Current scope**: held, freshly re-verified this session (manifest rebuilt and re-checked).

### PRIV-003 — Diagnostic export is opt-in, previewed, and redacted
- **Wording**: `Documentation/CONTINUATION.md` session "public-distribution punch list, continued":
  "anonymized diagnostic export, wired into Settings > Data with a mandatory preview sheet before save."
- **Priority**: MUST
- **Evidence**: `Sources/MacCareApp/DiagnosticReport.swift`,
  `Tests/MacCareAppTests/DiagnosticReportTests.swift` (redaction test, passing per this session's test
  run).
- **Current scope**: held, test-backed.

---

## Known open gaps carried into this baseline (not fabricated as resolved)

- **PROD debt**: full per-view public-API line-by-line audit (§9 of `PROJECT_COMPLETE_AUDIT.md`) is
  still genuinely incomplete — 15 `MacCareApp` view files are `IMPLEMENTED_UNVERIFIED`, not
  `VERIFIED_COMPLETE`. This baseline does not claim FUNC-level requirements are traced to code yet —
  that's session 2's traceability-matrix job.
- No VIS-/MOTION-/A11Y-/I18N-/PERF- entries were added this session beyond what's implied above — a
  focused read of `VISUAL_DIRECTION.md`/`BRAND_SYSTEM.md`/`DESIGN_TOKENS.md`/`MOTION_SYSTEM.md` for
  requirement-shaped statements is deferred to session 2, flagged honestly rather than padded with
  shallow entries under budget pressure.
