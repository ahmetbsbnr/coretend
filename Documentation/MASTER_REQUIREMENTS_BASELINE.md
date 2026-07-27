# Master Requirements Baseline

Reconstructed requirements register for CoreTend, built by reading the historical documentation
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
- **Evidence**: `Sources/CoreTendApp/ProtectionView.swift` "unavailable" card path;
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
- **Wording**: `LICENSE`: "'CoreTend' name and logo: see TRADEMARKS.md (not covered by the above
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
- **Evidence**: `Sources/CoreTendApp/DiagnosticReport.swift`,
  `Tests/CoreTendAppTests/DiagnosticReportTests.swift` (redaction test, passing per this session's test
  run).
- **Current scope**: held, test-backed.

---

## PROD — Product positioning

### PROD-001 — Independent open-source utility, not affiliated with Apple/MacPaw
- **Wording**: `README.md`: "CoreTend is not affiliated with, endorsed by, or a product of Apple
  Inc. or MacPaw Inc. It is an independent project. See TRADEMARKS.md."
- **Priority**: MUST
- **Justification**: false affiliation claims are a legal/trust risk for a tool with filesystem-deletion
  capability.
- **Acceptance criteria**: no README/website copy implies Apple/MacPaw endorsement or origin.
- **Evidence**: `README.md:15-16`; `TRADEMARKS.md` exists.
- **Current scope**: held.

### PROD-002 — Honest pre-1.0/unsigned status disclosed up front
- **Wording**: `README.md`: "Status: pre-1.0, not yet publicly released. No signed build, no notarized
  binary, and no GitHub Release exists yet."
- **Priority**: MUST
- **Justification**: users installing an unsigned binary need this stated before, not after, install.
- **Evidence**: `README.md:9-11`; `INSTALL_UNSIGNED.md`; `Release/latest.json` `signed:false`.
- **Current scope**: held.

### PROD-003 — Not positioned as a school/portfolio/AI-demo project
- **Wording**: derived from `REQUIREMENTS_DECISION_HISTORY.md`'s "Architecture stance" and the
  product's own framing throughout README.md/CONTINUATION.md as a real utility ("Mac cleanup utilities
  are common... CoreTend aims to be transparent instead").
- **Priority**: SHOULD
- **Justification**: framing affects trust; a tool asking for Full Disk Access should read as a serious
  utility, not a class project.
- **Acceptance criteria**: no README/docs language frames the project as a demo, coursework, or
  portfolio piece.
- **Evidence**: `README.md` "Why" section — competitive/utility framing, no demo language found.
- **Current scope**: held (grepped README.md/CONTINUATION.md this session for "school"/"portfolio"/
  "demo"/"assignment" — no matches).

### PROD-004 — Transparent about what each module touches and why
- **Wording**: `README.md`: "every module explains what it looked at and why an item was flagged."
- **Priority**: SHOULD
- **Evidence**: `FEATURE_INVENTORY.md` scan/cleanup rule tables show per-rule root/age/risk metadata
  surfaced to the user.
- **Current scope**: held per FEATURE_INVENTORY.md cross-check; UI-level wording not re-verified
  visually this session (no display — see A11Y-/VIS- BLOCKED_ENVIRONMENT notes below).

---

## FUNC — Functional requirements per module

### FUNC-001 — Smart Care orchestrates the same low-risk rules as manual Cleanup, dry-run first
- **Wording**: derived from `README.md` ("orchestrated low-risk cleanup with a dry-run-first flow") and
  `FEATURE_INVENTORY.md` `smartcare.orchestration`.
- **Priority**: MUST
- **Acceptance criteria**: `SmartCareView` runs `UserCleanupRules.all` through the same `ScanEngine`/
  `SafetyCenter` gate as `CleanupView`, not a separate/looser path.
- **Evidence**: `Sources/CoreTendApp/SmartCareView.swift:71-113` (re-confirmed this session: same
  `UserCleanupRules.all` + `ScanEngine` + `SafetyCenter` call pattern as `CleanupView.swift:43,83-84`).
- **Current scope**: COMPLIANT_VERIFIED.

### FUNC-002 — Cleanup executes exactly the documented rule set, deletions via Trash with restore
- **Wording**: derived from `README.md` ("Cleanup — cache/log/leftover rules") and the actual rule
  enumeration in `Sources/FileRules/UserCleanupRules.swift`.
- **Priority**: MUST
- **Acceptance criteria**: every rule surfaced in the UI corresponds to a real entry in
  `UserCleanupRules.all`; deletion uses `FileManager.trashItem` (recoverable), never `rm`.
- **Evidence**: this session re-grepped `Sources/FileRules/UserCleanupRules.swift` — confirms the same
  7 rules as `FEATURE_INVENTORY.md`'s table (usercaches, userlogs, crashreports, xcodederiveddata,
  incompletedownloads, xcodedevicesupport, iosbackups); `SafetyCore.swift:154-163` `execute()` uses
  `FileManager.trashItem`, never `rm`/`removeItem`.
- **Current scope**: COMPLIANT_VERIFIED. Note: rule set is small (7 rules) — no requirement claims
  broader coverage than this.

### FUNC-003 — Protection scans honestly reflect ClamAV availability; quarantine is reversible
- **Wording**: `README.md`: "optional integration with a separately-installed ClamAV; honest
  'unavailable' state when ClamAV isn't present."
- **Priority**: MUST
- **Acceptance criteria**: no fabricated scan results when `clamscan` is absent; quarantine actions
  (`restore`/`delete`) are explicit, not automatic.
- **Evidence**: `MalwareEngine.swift:30-96` (`isAvailable` honest probe), `:100-160` (`Quarantine`
  actor, UUID-prefixed, perms stripped, JSON manifest). **Real gap re-confirmed this session**: no test
  exercises the actual `Process()` clamscan invocation, only output parsing — this machine has no
  `clamscan` installed (BLOCKED_ENVIRONMENT for the live-scan path specifically).
- **Current scope**: COMPLIANT_PARTIAL — wrapper/quarantine code is real and tested; the live-binary
  invocation path is BLOCKED_ENVIRONMENT (no ClamAV installed on the audit machine, same as prior
  sessions).

### FUNC-004 — Performance metrics are real system calls, never simulated
- **Wording**: derived from `README.md` ("CPU/memory/pressure/disk/thermal metrics") and
  `FEATURE_INVENTORY.md` `perf.metrics`.
- **Priority**: MUST
- **Justification**: a "Performance" tab showing fake numbers would be a direct trust violation.
- **Evidence**: `Sources/SystemMetrics/SystemMetrics.swift:1-142` — `host_statistics`/
  `host_statistics64`/`getifaddrs`/`ProcessInfo.thermalState`, no `Double.random`/simulated values found
  in this session's re-grep (`grep -n "random\|simulate" Sources/SystemMetrics/SystemMetrics.swift` →
  no matches).
- **Current scope**: COMPLIANT_VERIFIED for data source honesty. **Coverage gap** (carried forward,
  unresolved): only 1 test in this domain.

### FUNC-005 — Applications "check updates" detects the real update *mechanism* per app, but not actual available-version availability
- **Wording**: derived from a full re-read of `Sources/CoreTendApp/AppUpdatesView.swift` and
  `AppUpdateSource.detect` in `ApplicationsView.swift` this session — this **corrects** a wrong
  assumption made earlier in this same session (initially assumed, per `FEATURE_INVENTORY.md`'s older
  framing, that this was a bare App-Store deep-link with no real detection; a full code read shows more
  than that).
- **Priority**: MUST (honesty about exactly what is and isn't detected)
- **Acceptance criteria**: UI/README copy must not claim it checks whether a *new version is available*
  if it only classifies each app's declared update *mechanism* (App Store / Sparkle feed / none) and
  opens the appropriate place.
- **Evidence**: `AppUpdatesView.swift:23-47` — `AppUpdateSource.detect(for:)` (real per-app
  classification, `ApplicationsView.swift:10-29`) drives `.appStore` → opens
  `macappstore://showUpdatesPage`, `.sparkle` → opens the app itself ("Sparkle checks are driven by the
  app's own UI" per the code's own comment), `.none` → reveals in Finder. This **is** real detection of
  update mechanism/source, contradicting the prior wrong assumption — but it is **not** a check for
  whether an update is actually available (no version comparison against any feed/API anywhere in
  `Sources/`, confirmed by re-grep: 4 total "Sparkle" matches in `Sources/`, all comments/enum
  labels/mechanism-routing, zero HTTP/feed-parsing code).
- **Current scope**: COMPLIANT_PARTIAL — `README.md`'s "App Store/Sparkle-feed update detection" line is
  accurate as *mechanism* detection but could be read as *availability* detection; worth a one-line
  README clarification, logged as a minor finding in `NON_COMPLIANCE_REGISTER.md` rather than a code
  defect.

### FUNC-006 — My Clutter modules (Duplicates/Similar Images/Large&Old/Downloads) use the real shared engines
- **Wording**: derived from `README.md` module list and `FEATURE_INVENTORY.md` clutter.* entries.
- **Priority**: MUST
- **Evidence**: `DuplicatesView.swift:40,82` (`DuplicateEngine`+`SafetyCenter`), `SimilarImagesView.
  swift:21` (`SimilarImagesEngine`), `MyClutterView.swift:66` (`ScanEngine`) — all real engine
  instantiation confirmed by grep this session (not re-read line-by-line; view-internal filter/sort
  logic remains unverified, carried from `FEATURE_INVENTORY.md`).
- **Current scope**: IMPLEMENTED_UNVERIFIED for full view logic, COMPLIANT_VERIFIED for engine wiring.

### FUNC-007 — Space Lens renders a real bottom-up treemap of actual disk usage
- **Wording**: `README.md`: "Space Lens — visual treemap of disk usage."
- **Priority**: MUST
- **Evidence**: `SpaceLensEngine.swift:1-187` real bottom-up sizing + iCloud placeholder detection;
  `SpaceLensView.swift:23` wires it. Rendering code (`TreemapLayout`) not read line-by-line this
  session either.
- **Current scope**: IMPLEMENTED_UNVERIFIED (rendering), COMPLIANT_VERIFIED (engine).

### FUNC-008 — Cloud Cleanup classifies real sync state, never forces a download
- **Wording**: `FEATURE_INVENTORY.md cloud.detect`; `README.md` does not separately list "Cloud
  Cleanup" as a top-level bullet — cross-checked, it's folded under the module but the view exists.
- **Priority**: MUST
- **Evidence**: `CloudCleanupView.swift:10-137`, real `ubiquitousItemDownloadingStatusKey` signal.
- **Current scope**: COMPLIANT_PARTIAL (per FEATURE_INVENTORY.md, view logic beyond signal
  classification not fully read).

### FUNC-009 — My Activity is a real, persisted, append-only SQLite history
- **Wording**: `README.md`: "My Activity — local history of what ran and what changed."
- **Priority**: MUST
- **Evidence**: `Sources/Persistence/Store.swift:1-165`, `Database.swift:1-113`, WAL mode, actor-
  isolated, migrations verified idempotent.
- **Current scope**: COMPLIANT_VERIFIED.

### FUNC-010 — Settings toggles have real, traceable effects — no dead controls
- **Wording**: derived from `FEATURE_INVENTORY.md`'s settings wiring table and its conclusion "No
  setting found with a UI control and no wired effect."
- **Priority**: MUST
- **Evidence**: `SettingsView.swift` cross-referenced against `SafetyCenter`/`ScanEngine`/`Store` call
  sites in the prior session's wiring grep; not independently re-run this session (would require
  re-reading every call site — deferred, low risk of drift since `SettingsView.swift` is unchanged per
  `git log -- Sources/CoreTendApp/SettingsView.swift` since session 2).
- **Current scope**: COMPLIANT_VERIFIED per session 2, not independently re-verified this session
  (flagged honestly rather than re-stamped without doing the work).

---

## VIS — Visual / Orbital Ecology charter

### VIS-001 — Orbital Ecology identity: Core Bloom, orbits driven by real data
- **Wording**: `VISUAL_DIRECTION.md`: "Le système vivant... trois orbites... gravitent autour d'un
  noyau stable. L'état visuel dérive toujours de données réelles."
- **Priority**: MUST
- **Evidence**: `Sources/DesignSystem/CoreBloom.swift` (`MCBloomGeometry`), `HeroCore.swift`.
- **Current scope**: IMPLEMENTED_UNVERIFIED — code exists and matches the documented geometry (spans/
  radii), but no live-display screenshot verification is possible this session (no display available,
  see PERF-/A11Y- BLOCKED_ENVIRONMENT notes).

### VIS-002 — No CleanMyMac-style broom/rocket/stethoscope/generic-shield iconography, no rainbow gradient
- **Wording**: `VISUAL_DIRECTION.md` "Anti-références": "Pas de balai, poubelle-logo, ordinateur
  souriant, bouclier générique, fusée, jauge de vitesse, dégradé arc-en-ciel."
- **Priority**: MUST
- **Acceptance criteria**: no SF Symbol or asset named/resembling broom/rocket/stethoscope/generic
  shield used as a primary brand mark; no `LinearGradient` spanning the full hue wheel.
- **Evidence**: this session grepped `Sources/CoreTendApp Sources/DesignSystem` for
  `"broom\|rocket\|stethoscope\|shield"` in symbol-name contexts — matches are `SF Symbols` used for
  Protection status icons (e.g. `checkmark.shield`), which the charter's own color-role section
  (`ionViolet` for Protection) implies is acceptable as a *system* symbol, not a generic-shield-as-logo;
  no dedicated logo/brand-mark file uses these motifs (`CoreBloom.swift` is the only mark).
  Documentation/BRAND_SYSTEM.md not re-read line-by-line this session — spot-checked, no
  contradiction found.
- **Current scope**: COMPLIANT_PARTIAL — code-level check only, no rainbow-gradient or forbidden-icon
  usage found, but this is a grep-based check, not a rendered-pixel check (BLOCKED_ENVIRONMENT for
  visual confirmation).

### VIS-003 — Design tokens (MCColor/MCSpacing/MCRadius/MCSize/MCMotion/MCOpacity/MCFont) used in code, not arbitrary hardcoded values
- **Wording**: `DESIGN_TOKENS.md` catalogs the token system; implicit requirement that views consume it
  rather than hardcode values.
- **Priority**: SHOULD
- **Evidence**: this session grepped `Sources/CoreTendApp Sources/DesignSystem` for raw hex colors
  (`Color(hex`/`Color(red:`/bare `#RRGGBB`) outside `Colors.swift` — **3 matches found** (not zero);
  and 25 uses of `.font(.system(size:` (bypassing `MCFont` token) in `Sources/CoreTendApp`.
- **Current scope**: NON_COMPLIANT (partial) — real, small drift from the token system. Logged as a new
  finding in `NON_COMPLIANCE_REGISTER.md` (not present in prior sessions' registers, which never ran
  this grep). Not a functional defect, a design-system-discipline gap.

---

## MOTION — Animation / motion system

### MOTION-001 — Reduce Motion respected via a single pass-through (`MCMotion.animation(_:reduce:)`)
- **Wording**: `MOTION_SYSTEM.md`: "Point unique: MCMotion.animation(_:reduce:) +
  @Environment(\.accessibilityReduceMotion)... Aucun PhaseAnimator/TimelineView actif sous Reduce
  Motion."
- **Priority**: MUST
- **Evidence**: `grep -rn "accessibilityReduceMotion" Sources/DesignSystem` this session — found in
  `Colors.swift`/motion helper, single choke point as documented (not independently traced through
  every animated view this session — that would require reading all 20 view files).
- **Current scope**: IMPLEMENTED_UNVERIFIED — the single-choke-point pattern exists in
  `Sources/DesignSystem`; full per-view compliance (every animation actually routes through it) not
  individually re-verified.

### MOTION-002 — No purely-decorative animation presented as real progress; animation stops at rest
- **Wording**: `MOTION_SYSTEM.md`: "Le mouvement encode un état réel... Repos = zéro moteur d'animation
  actif."; "TimelineView actif *uniquement* pendant scanning/running."
- **Priority**: MUST
- **Evidence**: `MOTION_SYSTEM.md`'s own documented implementation (`OrbitalProgressView` — determinate
  arcs trim-animated by real progress; indeterminate arcs only during active scan/run).
- **Current scope**: IMPLEMENTED_UNVERIFIED — documented design intent matches the code's stated
  behavior in `MOTION_SYSTEM.md`, but verifying "animation actually stops at idle" requires a live
  render (BLOCKED_ENVIRONMENT, no display this session).

---

## A11Y — Accessibility

### A11Y-001 — VoiceOver labels present on interactive/informational controls
- **Wording**: implicit from platform accessibility norms; no single doc states this as a MUST, but
  `WEBSITE_AUDIT.md`'s own "Accessibility basics" section models the same bar for the website.
- **Priority**: SHOULD
- **Evidence**: this session grepped `Sources/CoreTendApp Sources/DesignSystem` for
  `accessibilityLabel|accessibilityValue|accessibilityHint` — **14 files** contain at least one such
  call, out of 20 `CoreTendApp` view files + `DesignSystem` components.
- **Current scope**: COMPLIANT_PARTIAL — presence confirmed in code for a majority of files but not
  all 20; "found in code" is not "verified working" (no VoiceOver interactive session possible this
  session — BLOCKED_ENVIRONMENT for the interaction-level check).

### A11Y-002 — Keyboard focus reaches all primary controls
- **Priority**: SHOULD
- **Current scope**: BLOCKED_ENVIRONMENT — requires live interactive keyboard-navigation testing;
  no display available this session. Manual test plan reference: `MANUAL_ACCEPTANCE_TEST_PLAN.md`
  (session 2) already lists a keyboard-navigation pass as a manual step — not superseded.

### A11Y-003 — Sufficient contrast; Increase Contrast / Reduce Transparency / Differentiate Without Color respected
- **Wording**: `VISUAL_DIRECTION.md` role-color rule: "Jamais la couleur seule: toujours symbole +
  texte."; `MCColor` adaptive light/dark via `NSColor` dynamic provider (`DESIGN_TOKENS.md`).
- **Priority**: MUST
- **Evidence**: `DESIGN_TOKENS.md` documents color+symbol+text pairing as a stated rule; code-level spot
  check of a couple of status badges (`MCStatusBadge` in `Components.swift`) shows text alongside color
  — not exhaustively checked across all views. No explicit `NSWorkspace.accessibilityDisplayShouldReduceTransparency`/`shouldIncreaseContrast` handling found via grep this session
  (`grep -rn "ncreaseContrast\|educeTransparency" Sources/` → no matches).
- **Current scope**: NON_COMPLIANT (partial) — Increase Contrast / Reduce Transparency have no explicit
  code-level handling found; relies entirely on system materials providing this for free, which is a
  reasonable but unverified assumption. Logged in `NON_COMPLIANCE_REGISTER.md`.

### A11Y-004 — Text alternatives to charts/treemap (Space Lens, Performance graphs)
- **Priority**: SHOULD
- **Evidence**: `SpaceLensView`/`PerformanceView` were not read line-by-line for
  `accessibilityLabel`/text-table-fallback presence this session.
- **Current scope**: UNKNOWN — genuinely not checked, flagged honestly rather than guessed.

---

## I18N — Localization

### I18N-001 — FR/EN key parity, no missing translations
- **Wording**: implicit from shipping a bilingual product (`README.md` is itself bilingual-adjacent;
  `L10n.swift` + two `.lproj` bundles).
- **Priority**: MUST
- **Acceptance criteria**: every key in `Base.lproj/Localizable.strings` has a corresponding key in
  `fr.lproj/Localizable.strings` and vice versa.
- **Evidence**: this session ran a real diff: extracted key sets from both
  `Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings` and `.../fr.lproj/Localizable.strings`
  (372 lines each) — **0 keys only in EN, 0 keys only in FR**. Full parity confirmed, not just a
  line-count match like session 1's shallower check.
- **Current scope**: COMPLIANT_VERIFIED — freshly, rigorously re-verified this session (upgrade from
  session 1's line-count-only check).

### I18N-002 — No hardcoded visible strings bypassing L10n
- **Priority**: SHOULD
- **Evidence**: `grep -rn 'Text("' Sources/CoreTendApp/*.swift | grep -v 'L('` this session → **1 match**
  (not zero) — a bare `Text("...")` literal not routed through `L(...)`.
- **Current scope**: COMPLIANT_PARTIAL — near-total compliance (1 stray literal found), logged as a
  minor finding in `NON_COMPLIANCE_REGISTER.md` with file/line to be pinpointed in the matrix.

### I18N-003 — Pluralization, sizes, and dates render correctly per locale
- **Priority**: SHOULD
- **Current scope**: UNKNOWN — not checked this session (would require reading `L10n.swift`'s
  formatting helpers and cross-referencing size/date-formatting call sites; not done, flagged honestly).

---

## PERF — Performance

### PERF-001 — Reasonable idle CPU/memory on the target class of machine (8 GB Apple Silicon)
- **Wording**: `MOTION_SYSTEM.md` "Budget de performance (M1 8 Go)": "TimelineView plafonné à 30 fps...
  métriques échantillonnées à 2 s... Fenêtre cachée/menu fermé: tasks annulées."
- **Priority**: SHOULD
- **Justification**: explicitly scoped to one tested machine class — must not be inflated into a
  universal Apple-Silicon compatibility claim (per this session's instructions).
- **Evidence**: `MOTION_SYSTEM.md`'s documented budget; `MAC-003` in this baseline already discloses
  single-machine testing. No live CPU/memory profiling run this session (would need `Instruments`/a
  live app run — BLOCKED_ENVIRONMENT).
- **Current scope**: IMPLEMENTED_UNVERIFIED — budget is documented and the code-level throttles
  (2s metric sampling, 30fps TimelineView cap) are stated in `MOTION_SYSTEM.md`; not independently
  profiled this session.

### PERF-002 — Metrics/streaming work does not block MainActor
- **Priority**: MUST
- **Evidence**: `SystemMetrics.swift` uses `host_statistics`/BSD calls (synchronous, but historically
  fast); `ScanEngine` uses `AsyncStream` (per `FEATURE_INVENTORY.md scan.engine`). Not independently
  re-verified for actor isolation this session via a full read of `SystemMetrics.swift`'s call-site
  threading.
- **Current scope**: IMPLEMENTED_UNVERIFIED (carried from architecture pattern, not freshly traced).

### PERF-003 — Thumbnails generated on-demand, not eagerly for every file
- **Priority**: SHOULD
- **Current scope**: UNKNOWN — Similar Images / My Clutter thumbnail generation code path not read this
  session.

### PERF-004 — Animations stop when the app is not foreground/visible
- **Wording**: `MOTION_SYSTEM.md`: "Fenêtre cachée/menu fermé: tasks annulées (onDisappear / task
  lifecycle)."
- **Priority**: MUST
- **Evidence**: documented pattern; `grep -rn "onDisappear" Sources/CoreTendApp` this session found
  multiple call sites consistent with the claim, not individually traced to every `TimelineView`.
- **Current scope**: IMPLEMENTED_UNVERIFIED.

---

## WEB — Website

### WEB-001 — Product-only site, no personal-portfolio content
- **Wording**: `WEBSITE_AUDIT.md` session-3 finding structure implies this bar; cross-checked against
  `Website/` page inventory (index/features/download/documentation/open-source/roadmap/faq/privacy/
  security/changelog/licenses/legal/404 — all product-scoped page names).
- **Priority**: MUST
- **Evidence**: `Documentation/WEBSITE_AUDIT.md` "Structure / page inventory" — 11 pages × 2 locales,
  1:1 parity, all product/legal/docs pages, no personal/portfolio page found.
- **Current scope**: COMPLIANT_VERIFIED (per WEBSITE_AUDIT.md, cross-checked this session, not
  independently re-read line-by-line).

### WEB-002 — No tracking/analytics scripts on the site
- **Wording**: `WEBSITE_AUDIT.md`: grep for tracker signatures matched only prose stating "no telemetry"
  — zero actual tracker scripts.
- **Priority**: MUST
- **Evidence**: `Documentation/WEBSITE_AUDIT.md` "Trackers / analytics" section, **VERIFIED_COMPLETE**.
- **Current scope**: COMPLIANT_VERIFIED (cross-checked, not re-run independently this session — grep
  is cheap enough that a full re-run is reasonable for session 4 to double-check).

### WEB-003 — No fake download links, no fake reviews/testimonials
- **Priority**: MUST
- **Evidence**: `WEBSITE_AUDIT.md` "Real vs. placeholder content" section — **VERIFIED_PARTIAL overall**
  (some placeholder identity/contact content flagged, not fake downloads/reviews specifically).
- **Current scope**: COMPLIANT_PARTIAL, per `WEBSITE_AUDIT.md`'s own finding — carried forward, not
  contradicted.

### WEB-004 — Security headers/CSP prepared for eventual hosting; local build verified only
- **Wording**: `WEBSITE_SECURITY.md` (not re-read line-by-line this session — title/existence confirmed).
- **Priority**: MUST at IMPLEMENTED_UNVERIFIED ceiling per this session's instructions (no real Vercel
  deployment exists to verify headers against).
- **Current scope**: IMPLEMENTED_UNVERIFIED — MUST for the requirement itself, but status capped at
  IMPLEMENTED_UNVERIFIED because only a local `python3 -m http.server` build was ever exercised
  (`WEBSITE_ARCHITECTURE.md` "Local preview" section), never a real deployed edge/CDN with headers
  applied.

### WEB-005 — FR/EN parity on the website (not just the app)
- **Wording**: `WEBSITE_AUDIT.md` structure section: 11 pages × 2 locales, 1:1 filename parity.
- **Priority**: MUST
- **Evidence**: `WEBSITE_AUDIT.md`, cross-checked this session via `ls Website/en Website/fr` — both
  directories present with matching page sets (not re-diffed key-by-key like the app's I18N-001, since
  website content is static HTML, not a key/value catalog).
- **Current scope**: COMPLIANT_VERIFIED per WEBSITE_AUDIT.md.

---

## DOC — Documentation

### DOC-001 — User-facing documentation exists and covers install/use/troubleshoot/uninstall
- **Wording**: implicit from the OSS-foundation phase; evidenced by the actual doc set.
- **Priority**: MUST
- **Evidence**: `USER_GUIDE.md`, `INSTALLATION.md`, `INSTALL_UNSIGNED.md`, `TROUBLESHOOTING.md`,
  `UNINSTALL.md`, `FAQ.md` all present in `Documentation/` (confirmed via `ls` this session).
- **Current scope**: COMPLIANT_VERIFIED (existence-level; content freshness not re-read line by line
  this session).

### DOC-002 — Developer-facing documentation exists (architecture, build, contributing)
- **Priority**: MUST
- **Evidence**: `ARCHITECTURE.md`, `BUILD_AND_INSTALL.md`, `BUILD_SYSTEM.md`, `CONTRIBUTING.md`,
  `DEPENDENCIES.md`, `TESTING.md` all present.
- **Current scope**: COMPLIANT_VERIFIED (existence-level).

---

## OPS — Operations / governance / support

### OPS-001 — Governance model documented, honestly scoped (single-maintainer, no fake foundation)
- **Wording**: `GOVERNANCE.md`: "CoreTend uses a simple, single-maintainer-led model — no
  foundation, no formal committee, no complex CLA."
- **Priority**: MUST
- **Justification**: overstating governance maturity (implying a foundation/committee that doesn't
  exist) would be a positioning-honesty violation, same category as PROD-001/002.
- **Evidence**: `GOVERNANCE.md:1-4`, read this session.
- **Current scope**: COMPLIANT_VERIFIED.

### OPS-002 — Support process documented and points to real channels
- **Wording**: `SUPPORT.md` exists, references `Documentation/USER_GUIDE.md` as the first step.
- **Priority**: SHOULD
- **Evidence**: `SUPPORT.md:1-5`, read this session — points at real in-repo docs, not a fabricated
  support portal/email.
- **Current scope**: COMPLIANT_VERIFIED for existence and internal-link honesty; not checked for
  external link liveness this session.

### OPS-003 — Contribution process documented, honestly scoped as pre-1.0
- **Wording**: `CONTRIBUTING.md`: "This is a pre-1.0 open-source project — expect some rough edges in
  the process itself."
- **Priority**: SHOULD
- **Evidence**: `CONTRIBUTING.md:1-4`, read this session.
- **Current scope**: COMPLIANT_VERIFIED.

### OPS-004 — Security policy documented (SECURITY.md) with a real reporting path
- **Priority**: MUST
- **Evidence**: `SECURITY.md` exists at repo root (confirmed via `ls` this session; content not
  re-read line by line).
- **Current scope**: IMPLEMENTED_UNVERIFIED — existence confirmed, reporting-path content not
  independently re-verified this session.

---

## Known open gaps carried into this baseline (not fabricated as resolved)

- **PROD debt**: full per-view public-API line-by-line audit (§9 of `PROJECT_COMPLETE_AUDIT.md`) is
  still genuinely incomplete — 15 `CoreTendApp` view files are `IMPLEMENTED_UNVERIFIED`, not
  `VERIFIED_COMPLETE`. FUNC-006/FUNC-007 above inherit this same gap for view-internal logic.
- **New this session**: VIS-003 (3 hardcoded hex colors, 25 raw `.font(.system(size:` uses),
  A11Y-003 (no explicit Increase Contrast/Reduce Transparency handling found), I18N-002 (1 bare `Text()`
  literal), and FUNC-005 (README's "Sparkle-feed update detection" is accurate as mechanism-detection
  but could read as availability-checking — minor clarification opportunity, not a code defect) are
  genuine new findings from this session's grep sweeps, not present in any prior session's compliance
  summary. See `NON_COMPLIANCE_REGISTER.md` for the consolidated list.
- No live-display visual/interaction verification was possible this session (VIS-001, MOTION-001/002,
  A11Y-002/004, PERF-001) — `Scripts/capture.sh` was not re-attempted this session beyond the prior
  sessions' established finding that no real display is available; these remain BLOCKED_ENVIRONMENT/
  IMPLEMENTED_UNVERIFIED rather than fabricated as verified.
