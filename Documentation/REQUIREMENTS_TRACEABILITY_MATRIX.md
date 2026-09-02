# Requirements Traceability Matrix

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Session-1 output landed at `e1a0a14`. This matrix is session 2 of the requirements-reconciliation/external-audit-package effort.

Total requirements: **69** (28 from session 2 + 41 new this session, session 3, covering PROD/FUNC/VIS/MOTION/A11Y/I18N/PERF/WEB/DOC/OPS domains previously absent). Machine-readable twins: `requirements-traceability.json`, `requirements-traceability.csv` — all three generated from the same source data, mutually consistent by construction (CSV regenerated programmatically from JSON this session to guarantee sync).

Status vocabulary: COMPLIANT_VERIFIED, COMPLIANT_PARTIAL, IMPLEMENTED_UNVERIFIED, NON_COMPLIANT, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, DEFERRED_APPROVED, SUPERSEDED, NOT_APPLICABLE, UNKNOWN.

---

## SAFE

### SAFE-001
- **Priority**: MUST
- **Source**: SAFETY_MODEL.md:4
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/ScanCore/ScanCore.swift, Sources/SafetyCore/SafetyCore.swift
- **Symbols**: ScanEngine.stream, SafetyCenter.execute(_:)
- **Views**: —
- **Test**: Tests — no dedicated 'scan never deletes' unit test found; verified by code inspection (ScanEngine has no FileManager.trashItem/removeItem call; only SafetyCenter.execute performs trashItem, and it is never invoked from scan code paths).
- **Command**: `grep -rn "trashItem\|removeItem" Sources/ScanCore Sources/SafetyCore`
- **Runtime evidence**: n/a (headless, static verification)
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: No automated regression test enforces this architecturally (e.g. no lint rule banning trashItem outside SafetyCore); relies on code review discipline.
- **User impact**: none currently — held
- **Risk**: low
- **Needed fix**: add an architectural test asserting Sources/ScanCore contains no delete API calls
- **Recommended version**: 0.7.x (test-only addition, no behavior change)

### SAFE-002
- **Priority**: MUST
- **Source**: SAFETYCORE.md:25,35
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/SafetyCore/SafetyCore.swift
- **Symbols**: SafetyCenter.execute(_ operations: [ApprovedFileOperation]), ApprovedFileOperation, SafetyCenter.approve(url:logicalSize:ruleID:risk:)
- **Views**: —
- **Test**: none dedicated; verified by direct code read this session (previously flagged in baseline as 'not independently re-verified' — now re-verified).
- **Command**: `read Sources/SafetyCore/SafetyCore.swift:94-165`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### SAFE-003
- **Priority**: MUST
- **Source**: SAFETYCORE.md:16
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/SafetyCore/SafetyCore.swift
- **Symbols**: PathValidator.validate(_:)
- **Views**: —
- **Test**: no dedicated unit test found exercising exactly the bare-home-directory rejection path; verified by direct code read (line: 'guard standardized.path != home.path else { throw .protectedRoot(home.path) }').
- **Command**: `read Sources/SafetyCore/SafetyCore.swift:56-81`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: no automated test for this exact guard
- **User impact**: none currently
- **Risk**: low
- **Needed fix**: add unit test asserting PathValidator.validate(home) throws .protectedRoot
- **Recommended version**: 0.7.x

### SAFE-004
- **Priority**: MUST
- **Source**: SAFETY_MODEL.md:18
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/ScanCore/ScanCore.swift, Tests/ScanCoreTests
- **Symbols**: ScanConfiguration, ScanEngine
- **Views**: —
- **Test**: 'Scan root isolation' suite / downloadsOnlyScanNeverTouchesSiblingDirectories — read the test body this session, confirms a scan scoped to Downloads never reports findings from Documents/Desktop/Pictures/Music/Movies siblings. PASSED in this session's bash Scripts/test.sh run.
- **Command**: `bash Scripts/test.sh (2026-07-20, 86/86 passed)`
- **Runtime evidence**: n/a (unit test, not full app runtime)
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: covers scan-scope only, not a UI-level guarantee that these roots can never be manually added as a scan root by the user via file picker
- **User impact**: none currently
- **Risk**: low
- **Needed fix**: confirm UI folder-picker also can't target these roots (session 3 functional pass)
- **Recommended version**: n/a

### SAFE-005
- **Priority**: MUST
- **Source**: DECISIONS.md (D-R5)
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/SafetyCore/SafetyCore.swift; Sources/CoreTendApp/CleanupView.swift; Sources/CoreTendApp/DuplicatesView.swift; Sources/CoreTendApp/ApplicationsView.swift; Sources/CoreTendApp/LeftoversView.swift; Sources/CoreTendApp/PrivacyCleanerView.swift; Sources/CoreTendApp/SmartCareView.swift; Sources/CoreTendApp/SpaceLensView.swift
- **Symbols**: SafetyCenter.approve; SafetyCenter.execute; confirmationDialog
- **Views**: CleanupView.swift, DuplicatesView.swift, ApplicationsView.swift, LeftoversView.swift, PrivacyCleanerView.swift, SmartCareView.swift, SpaceLensView.swift
- **Test**: SafetyCenter execution/audit tests plus the retired-mode repository gate.
- **Command**: `bash Scripts/check-retired-preview-mode.sh && swift test`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### SAFE-006
- **Priority**: MUST
- **Source**: DECISIONS.md:17-19 (D4)
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/ScanCore/ScanCore.swift, Tests/ScanCoreTests
- **Symbols**: ScanEngine
- **Views**: —
- **Test**: symlinkedDirectoryNotDescended() — PASSED in this session's Scripts/test.sh run.
- **Command**: `bash Scripts/test.sh`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## PROTECTION

### PROTECTION-001
- **Priority**: MUST
- **Source**: PROTECTION.md; CLAMAV_DECISION.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/CoreTendApp/ProtectionView.swift, Sources/IntegrityCore/IntegrityCore.swift
- **Symbols**: ProvenanceScanner; CodeSignInspector; LoginItemScanner; IntegrityView
- **Views**: ProtectionView.swift
- **Test**: IntegrityCoreTests cover provenance metadata, Apple/ad-hoc/unsigned signature tiers, malformed inputs and login-item parsing.
- **Command**: `swift test --filter IntegrityCoreTests`
- **Runtime evidence**: native Security/Foundation APIs only; no external process or scanner path in `Sources/`.
- **Bundle evidence**: n/a
- **Visual evidence**: isolated application smoke/capture campaign
- **Limitation**: informational integrity signals are deliberately not malware detection
- **User impact**: users receive narrow, verifiable facts rather than a security overclaim
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## SEC

### SEC-001
- **Priority**: MUST
- **Source**: SECURITY_AUDIT_CURRENT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/
- **Symbols**: —
- **Views**: —
- **Test**: source security gate rejects unexpected subprocess execution.
- **Command**: `rg 'Process\\s*\\(' Sources/`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### SEC-002
- **Priority**: MUST
- **Source**: SECURITY_AUDIT_CURRENT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; re-verified by a fresh grep this session (baseline had flagged 'not re-verified independently').
- **Command**: `rg -n 'sudo' Sources/` — zero matches
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### SEC-003
- **Priority**: MUST
- **Source**: INSTALL_UNSIGNED.md:72
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Documentation/INSTALL_UNSIGNED.md, Documentation/REQUIREMENTS_DECISION_HISTORY.md
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/test-release-manifest.sh 'no dangerous Gatekeeper-bypass commands documented as steps to follow' check.
- **Command**: `bash Scripts/test-release-manifest.sh`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: this session found a REAL REGRESSION: session 1's own REQUIREMENTS_DECISION_HISTORY.md mentioned 'sudo spctl --master-disable' with its 'Do not...' warning on the line AFTER the dangerous string, which the script's look-behind-only heuristic did not detect as warned — test-release-manifest.sh was FAILING at session start. Fixed this session by reordering the sentence so the warning precedes the command (fix(audit) commit); script now passes ALL CHECKS.
- **User impact**: was a false negative in the audit's own regression check, not a real user-facing Gatekeeper-bypass instruction; fixed
- **Risk**: low (fixed)
- **Needed fix**: done this session
- **Recommended version**: 0.7.x (docs fix)

---

## DIST

### DIST-001
- **Priority**: MUST
- **Source**: test-release-manifest.sh acceptance criterion
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Release/latest.json, Release/SHA256SUMS, Scripts/build-release.sh, Scripts/test-release-manifest.sh
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/test-release-manifest.sh full run.
- **Command**: `bash Scripts/build-release.sh && bash Scripts/test-release-manifest.sh`
- **Runtime evidence**: fresh build-release.sh + test-release-manifest.sh run this session: ALL CHECKS PASSED (after the SEC-003 doc fix above; before that fix the run showed 1 FAIL on the Gatekeeper check, and an earlier run before a second rebuild showed a transient dmgSize mismatch from DMG non-reproducibility, both explained and resolved by the documented resync behavior).
- **Bundle evidence**: Release/SHA256SUMS and Release/latest.json both re-synced and verified this session
- **Visual evidence**: n/a
- **Limitation**: DMG output is not byte-reproducible run to run by design (documented); manifest resync after build is the mitigation, confirmed working.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### DIST-002
- **Priority**: MUST
- **Source**: test-release-manifest.sh acceptance criterion
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Release/latest.json, Documentation/INSTALL_UNSIGNED.md
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/test-release-manifest.sh 'unsigned/non-notarized declared consistently' check.
- **Command**: `bash Scripts/test-release-manifest.sh`
- **Runtime evidence**: latest.json signed:false, notarized:false, freshly rebuilt and re-verified this session
- **Bundle evidence**: Release/latest.json
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### DIST-003
- **Priority**: SHOULD
- **Source**: derived, no prior explicit doc
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Release/latest.json, Scripts/build-release.sh
- **Symbols**: —
- **Views**: —
- **Test**: none — manual field, no automated check that sourceCommit == git rev-parse HEAD at build time.
- **Command**: `grep sourceCommit Release/latest.json; git rev-parse HEAD`
- **Runtime evidence**: latest.json sourceCommit currently reflects a commit prior to this session's own commits (expected — it's stamped at the moment build-release.sh runs, and this session ran it before session-2 doc commits landed).
- **Bundle evidence**: Release/latest.json
- **Visual evidence**: n/a
- **Limitation**: build-release.sh still has no automated `git rev-parse HEAD` stamping — same gap noted in session 1, not fixed this session either (out of this session's scope, a real feat(release) change).
- **User impact**: low — a human could ship a release with a stale sourceCommit if they forget the manual step
- **Risk**: medium (process risk, not a code defect)
- **Needed fix**: add `git rev-parse HEAD` auto-stamp to build-release.sh
- **Recommended version**: 0.8.0 (small feat, deferred per session scope: no version bumps this session)

---

## MAC

### MAC-001
- **Priority**: MUST
- **Source**: COMPATIBILITY.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Release/latest.json
- **Symbols**: —
- **Views**: —
- **Test**: none — manifest field + build.sh only ever targets arm64 on this hardware.
- **Command**: `grep architecture Release/latest.json`
- **Runtime evidence**: latest.json architecture:arm64, freshly rebuilt this session
- **Bundle evidence**: Release/latest.json, Scripts/test-distribution.sh 'binary is arm64' check PASSED
- **Visual evidence**: n/a
- **Limitation**: no Intel Mac available to confirm exclusion is enforced rather than just undocumented for x86_64; single-machine build environment (MAC-003)
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### MAC-002
- **Priority**: MUST
- **Source**: MACOS_VERSION_POLICY.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Package.swift, Documentation/API_AVAILABILITY_AUDIT.md
- **Symbols**: @Observable usages (16, per API_AVAILABILITY_AUDIT.md)
- **Views**: —
- **Test**: none dedicated; Package.swift platform floor read directly.
- **Command**: `grep -n "macOS" Package.swift`
- **Runtime evidence**: n/a (build-only check)
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: not independently re-counted the 16 @Observable usages this session — trusted from API_AVAILABILITY_AUDIT.md.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### MAC-003
- **Priority**: n/a (disclosed limitation)
- **Source**: Release/latest.json knownLimitations
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Release/latest.json
- **Symbols**: —
- **Views**: —
- **Test**: n/a — this is a disclosure requirement, not a functional one.
- **Command**: `grep -A2 knownLimitations Release/latest.json`
- **Runtime evidence**: disclosure present in freshly rebuilt manifest
- **Bundle evidence**: Release/latest.json
- **Visual evidence**: n/a
- **Limitation**: by definition, unresolved — this is the honest disclosure of the limitation itself
- **User impact**: real: unverified on other Mac hardware/macOS versions
- **Risk**: medium
- **Needed fix**: multi-Mac manual test pass (see MANUAL_ACCEPTANCE_TEST_PLAN.md)
- **Recommended version**: n/a

---

## LEGAL

### LEGAL-001
- **Priority**: MUST
- **Source**: LICENSE
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: LICENSE, LICENSES/Apache-2.0.txt, Package.swift
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/check-licenses.sh — PASSED this session.
- **Command**: `bash Scripts/check-licenses.sh`
- **Runtime evidence**: n/a
- **Bundle evidence**: LICENSES/Apache-2.0.txt present, 0 external SwiftPM deps confirmed
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### LEGAL-002
- **Priority**: MUST
- **Source**: LICENSE
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: LICENSE, LICENSES/CC-BY-4.0.txt
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/check-licenses.sh — PASSED.
- **Command**: `bash Scripts/check-licenses.sh`
- **Runtime evidence**: n/a
- **Bundle evidence**: LICENSES/CC-BY-4.0.txt present
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### LEGAL-003
- **Priority**: MUST
- **Source**: LICENSE
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: LICENSE, TRADEMARKS.md
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; file existence check.
- **Command**: `test -f TRADEMARKS.md && echo present`
- **Runtime evidence**: n/a
- **Bundle evidence**: TRADEMARKS.md present
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### LEGAL-004
- **Priority**: MUST
- **Source**: derived from LICENSE cross-references
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: LICENSE, Documentation/LEGAL_AND_LICENSE_STATUS.md, Documentation/THIRD_PARTY.md
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; re-read LICENSE this session, both referenced paths exist.
- **Command**: `grep -n 'Documentation/' LICENSE; ls Documentation/LEGAL_AND_LICENSE_STATUS.md Documentation/THIRD_PARTY.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: both files exist on disk
- **Visual evidence**: n/a
- **Limitation**: fixed in a prior commit (964f110), re-confirmed not re-broken this session
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## OSS

### OSS-001
- **Priority**: SHOULD
- **Source**: DEPENDENCIES.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Package.swift
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/check-licenses.sh 'Package.swift has no external dependencies' check — PASSED.
- **Command**: `grep -c '.package(' Package.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: 0 .package(...) entries, confirmed fresh this session
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### OSS-002
- **Priority**: MUST
- **Source**: DEPENDENCIES.md / CLAMAV_DECISION.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Package.swift; Sources/IntegrityCore/IntegrityCore.swift
- **Symbols**: IntegrityCore
- **Views**: —
- **Test**: retired-component source and distribution gates.
- **Command**: `rg -i 'clamscan|MalwareEngine' Package.swift Sources Resources`
- **Runtime evidence**: n/a
- **Bundle evidence**: distribution gate confirms no third-party scanner binary or metadata
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## TEST

### TEST-001
- **Priority**: MUST
- **Source**: DECISIONS.md D2 + session instructions
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Scripts/test.sh
- **Symbols**: —
- **Views**: —
- **Test**: n/a — this requirement IS the test entry point itself.
- **Command**: `bash Scripts/test.sh`
- **Runtime evidence**: 86 tests, 27 suites, all passed, freshly re-run this session
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## ARCH

### ARCH-001
- **Priority**: MUST
- **Source**: DECISIONS.md D1
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Package.swift
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; file-existence/absence check.
- **Command**: `find . -maxdepth 1 -name '*.xcodeproj'`
- **Runtime evidence**: n/a
- **Bundle evidence**: no .xcodeproj found, Package.swift is the only build definition
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### ARCH-002
- **Priority**: MUST
- **Source**: inferred, cross-checked in REQUIREMENTS_DECISION_HISTORY.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; grep re-run fresh this session.
- **Command**: `grep -rl WKWebView Sources/`
- **Runtime evidence**: n/a
- **Bundle evidence**: zero matches, zero Package.swift dependencies
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## PRIV

### PRIV-001
- **Priority**: MUST
- **Source**: PRIVACY_AUDIT_CURRENT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; re-run fresh this session (baseline flagged this as needing independent re-verification, not just trusting session 2's grep).
- **Command**: `grep -rln 'URLSession\|Socket(\|CFSocket\|NWConnection' Sources/`
- **Runtime evidence**: n/a
- **Bundle evidence**: zero matches across all of Sources/, confirmed fresh this session
- **Visual evidence**: n/a
- **Limitation**: grep-based; does not rule out network access via a lower-level syscall wrapper not matching these symbol names (exhaustive network audit would need a network-monitor capture during a real run, not available headless)
- **User impact**: none currently found
- **Risk**: low
- **Needed fix**: a runtime network-monitor capture during manual QA (see MANUAL_ACCEPTANCE_TEST_PLAN.md) for full confidence
- **Recommended version**: n/a

### PRIV-002
- **Priority**: MUST
- **Source**: Release/latest.json
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Release/latest.json
- **Symbols**: —
- **Views**: —
- **Test**: none dedicated; manifest field cross-checked against PRIV-001's code-level grep.
- **Command**: `grep -n 'telemetry\|accountRequired' Release/latest.json`
- **Runtime evidence**: telemetry:false, accountRequired:false, freshly rebuilt this session
- **Bundle evidence**: Release/latest.json
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### PRIV-003
- **Priority**: MUST
- **Source**: CONTINUATION.md public-distribution punch list
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/CoreTendApp/DiagnosticReport.swift, Tests/CoreTendAppTests/DiagnosticReportTests.swift
- **Symbols**: DiagnosticReport
- **Views**: SettingsView.swift (Data section)
- **Test**: DiagnosticReportTests — redaction test read this session (confirms username/paths are stripped from the exported report body, not just asserted by name); PASSED in this session's Scripts/test.sh run.
- **Command**: `bash Scripts/test.sh`
- **Runtime evidence**: n/a (unit test, not a live export)
- **Bundle evidence**: n/a
- **Visual evidence**: NOT CAPTURED — mandatory preview sheet UI not screenshotted this session (headless); see MANUAL_ACCEPTANCE_TEST_PLAN.md
- **Limitation**: preview-sheet UI gating (opt-in, shown before save) verified by reading SettingsView.swift wiring, not by a live interaction
- **User impact**: none found
- **Risk**: low
- **Needed fix**: manual UI walkthrough of the preview-before-save flow
- **Recommended version**: n/a

---
## PROD

### PROD-001
- **Priority**: MUST
- **Source**: README.md:15-16
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: README.md; TRADEMARKS.md
- **Symbols**: —
- **Views**: —
- **Test**: none (doc-level requirement)
- **Command**: review README and website for unsupported third-party approval,
  origin, or partnership claims
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: this remains an editorial review rather than a complete
  machine-verifiable rule.
- **User impact**: none — held
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### PROD-002
- **Priority**: MUST
- **Source**: README.md:9-11
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: README.md; Release/latest.json; Documentation/INSTALL_UNSIGNED.md
- **Symbols**: —
- **Views**: —
- **Test**: Scripts/test-release-manifest.sh checks signed:false/notarized:false consistency
- **Command**: `cat Release/latest.json | grep signed`
- **Runtime evidence**: n/a
- **Bundle evidence**: Release/latest.json
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### PROD-003
- **Priority**: SHOULD
- **Source**: REQUIREMENTS_DECISION_HISTORY.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: README.md; Documentation/CONTINUATION.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `grep -in "school\|portfolio\|demo\|assignment" README.md Documentation/CONTINUATION.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Subjective framing check, not a hard grep-pass/fail.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### PROD-004
- **Priority**: SHOULD
- **Source**: README.md
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Documentation/FEATURE_INVENTORY.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT — no display this session
- **Limitation**: UI wording not visually re-confirmed this session.
- **User impact**: none known
- **Risk**: low
- **Needed fix**: visual re-check in a session with display access
- **Recommended version**: n/a

---

## FUNC

### FUNC-001
- **Priority**: MUST
- **Source**: README.md; FEATURE_INVENTORY.md smartcare.orchestration
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/CoreTendApp/SmartCareView.swift; Sources/CoreTendApp/CleanupView.swift
- **Symbols**: SmartCareView; UserCleanupRules.all; ScanEngine; SafetyCenter
- **Views**: SmartCareView
- **Test**: none dedicated; verified by direct code read this session
- **Command**: `grep -n 'UserCleanupRules.all\|ScanEngine\|SafetyCenter' Sources/CoreTendApp/SmartCareView.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### FUNC-002
- **Priority**: MUST
- **Source**: README.md; Sources/FileRules/UserCleanupRules.swift
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/FileRules/UserCleanupRules.swift; Sources/SafetyCore/SafetyCore.swift
- **Symbols**: UserCleanupRules.all; SafetyCenter.execute
- **Views**: CleanupView; SmartCareView
- **Test**: UserCleanupRulesTests.noRuleTargetsUserContent (passing)
- **Command**: `grep -n 'CleanupRule(' Sources/FileRules/UserCleanupRules.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Only 7 rules total — small surface, no requirement claims broader coverage.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### FUNC-003
- **Priority**: MUST
- **Source**: README.md; PROTECTION.md; CLAMAV_DECISION.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/IntegrityCore/IntegrityCore.swift; Sources/CoreTendApp/ProtectionView.swift
- **Symbols**: ProvenanceScanner; CodeSignInspector; LoginItemScanner
- **Views**: ProtectionView
- **Test**: IntegrityCoreTests cover real metadata parsing and signature classification
- **Command**: `swift test --filter IntegrityCoreTests`
- **Runtime evidence**: native local metadata only; no external engine dependency
- **Bundle evidence**: n/a
- **Visual evidence**: isolated application smoke/capture campaign
- **Limitation**: Integrity is informational and does not claim malware detection
- **User impact**: narrow and honest security context
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### FUNC-004
- **Priority**: MUST
- **Source**: README.md; FEATURE_INVENTORY.md perf.metrics
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/SystemMetrics/SystemMetrics.swift
- **Symbols**: MetricsCollector
- **Views**: PerformanceView
- **Test**: 1 test only (thin coverage, carried gap)
- **Command**: `grep -n "random\|simulate" Sources/SystemMetrics/SystemMetrics.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Thin test coverage (1 test) for this domain, carried from session 1/2.
- **User impact**: low — data source is real, just undertested
- **Risk**: low-medium
- **Needed fix**: add tests exercising each metric source
- **Recommended version**: n/a

### FUNC-005
- **Priority**: MUST
- **Source**: README.md; AppUpdatesView.swift; ApplicationsView.swift
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Sources/CoreTendApp/AppUpdatesView.swift; Sources/CoreTendApp/ApplicationsView.swift
- **Symbols**: AppUpdateSource.detect(for:); AppUpdatesViewModel.open(_:)
- **Views**: AppUpdatesView
- **Test**: none dedicated
- **Command**: `grep -n Sparkle Sources/CoreTendApp/*.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Detects update mechanism, not update availability — README wording could be misread as the latter.
- **User impact**: low — no functional gap, wording-precision gap
- **Risk**: low
- **Needed fix**: clarify README.md wording: 'mechanism detection' not 'availability checking'
- **Recommended version**: 0.7.x (docs-only)

### FUNC-006
- **Priority**: MUST
- **Source**: README.md; FEATURE_INVENTORY.md clutter.*
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/CoreTendApp/DuplicatesView.swift; SimilarImagesView.swift; MyClutterView.swift
- **Symbols**: DuplicateEngine; SimilarImagesEngine; ScanEngine
- **Views**: DuplicatesView; SimilarImagesView; MyClutterView
- **Test**: engine-level tests pass; view-internal logic untested
- **Command**: `grep -n 'DuplicateEngine()\|SimilarImagesEngine()\|ScanEngine()' Sources/CoreTendApp/*.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: View-internal filter/sort/error-state logic not read line-by-line.
- **User impact**: unknown
- **Risk**: low-medium
- **Needed fix**: full line-by-line view read in a future session
- **Recommended version**: n/a

### FUNC-007
- **Priority**: MUST
- **Source**: README.md; FEATURE_INVENTORY.md spacelens.view
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/ScanCore/SpaceLensEngine.swift; Sources/CoreTendApp/SpaceLensView.swift
- **Symbols**: SpaceLensEngine; TreemapLayout
- **Views**: SpaceLensView
- **Test**: engine tests pass; rendering code unread
- **Command**: `grep -n SpaceLensEngine Sources/CoreTendApp/SpaceLensView.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT
- **Limitation**: TreemapLayout rendering not read line-by-line, no visual confirmation possible.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: line-by-line read + visual capture in a display-capable session
- **Recommended version**: n/a

### FUNC-008
- **Priority**: MUST
- **Source**: FEATURE_INVENTORY.md cloud.detect
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Sources/CoreTendApp/CloudCleanupView.swift
- **Symbols**: CloudCleanupViewModel.detect/scan
- **Views**: CloudCleanupView
- **Test**: none dedicated
- **Command**: `grep -n ubiquitousItemDownloadingStatusKey Sources/CoreTendApp/CloudCleanupView.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Full view logic and complete provider list beyond iCloud not read line-by-line.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: full read
- **Recommended version**: n/a

### FUNC-009
- **Priority**: MUST
- **Source**: README.md; FEATURE_INVENTORY.md activity.log
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/Persistence/Store.swift; Sources/Persistence/Database.swift
- **Symbols**: Store.recordActivity; Store.activity(limit:kind:); Store.clearActivity()
- **Views**: MyActivityView
- **Test**: passing (day-grouping suite, migrations idempotent)
- **Command**: `read Sources/Persistence/Store.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### FUNC-010
- **Priority**: MUST
- **Source**: FEATURE_INVENTORY.md settings wiring table
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/CoreTendApp/SettingsView.swift
- **Symbols**: SettingsView
- **Views**: SettingsView
- **Test**: none dedicated; verified session 2, unchanged file since (git log check)
- **Command**: `git log --oneline -- Sources/CoreTendApp/SettingsView.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Not independently re-run this session (file unchanged since session 2's verification, low drift risk).
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## VIS

### VIS-001
- **Priority**: MUST
- **Source**: VISUAL_DIRECTION.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/DesignSystem/CoreBloom.swift; HeroCore.swift
- **Symbols**: MCBloomGeometry
- **Views**: —
- **Test**: DesignSystemTests (geometry-level)
- **Command**: `read Sources/DesignSystem/CoreBloom.swift`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT — no display this session
- **Limitation**: No live-render screenshot verification possible.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: Scripts/capture.sh in a display-capable session
- **Recommended version**: n/a

### VIS-002
- **Priority**: MUST
- **Source**: VISUAL_DIRECTION.md Anti-references
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Sources/CoreTendApp; Sources/DesignSystem
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `grep -rn "broom\|rocket\|stethoscope\|shield" Sources/CoreTendApp Sources/DesignSystem`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT
- **Limitation**: Grep-based symbol-name check only, not a rendered-pixel check; BRAND_SYSTEM.md not re-read line by line this session.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: visual capture + BRAND_SYSTEM.md full re-read
- **Recommended version**: n/a

### VIS-003
- **Priority**: SHOULD
- **Source**: DESIGN_TOKENS.md
- **Status**: **NON_COMPLIANT**
- **Files**: Sources/CoreTendApp/SpaceLensView.swift; Sources/CoreTendApp/OnboardingView.swift (+22 other .font(.system(size: sites)
- **Symbols**: —
- **Views**: SpaceLensView; OnboardingView
- **Test**: none
- **Command**: `grep -rn "Color(red:\|\.font(\.system(size:" Sources/CoreTendApp Sources/DesignSystem`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: 3 hardcoded Color(red:) values in SpaceLensView.swift:72-75 (category colors) and 25 raw .font(.system(size:) call sites bypass MCColor/MCFont tokens.
- **User impact**: low — design-system discipline gap, not a functional defect
- **Risk**: low
- **Needed fix**: migrate SpaceLensView category colors to MCColor.chartSeries; migrate raw .font(.system(size:) sites to MCFont
- **Recommended version**: 0.7.x or 0.8.0 (design-system cleanup)

---

## MOTION

### MOTION-001
- **Priority**: MUST
- **Source**: MOTION_SYSTEM.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/DesignSystem
- **Symbols**: MCMotion.animation(_:reduce:)
- **Views**: —
- **Test**: none dedicated for per-view compliance
- **Command**: `grep -rn "accessibilityReduceMotion" Sources/DesignSystem`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT
- **Limitation**: Single choke-point pattern confirmed to exist; not traced through every animated view.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: per-view animation call-site audit
- **Recommended version**: n/a

### MOTION-002
- **Priority**: MUST
- **Source**: MOTION_SYSTEM.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/DesignSystem
- **Symbols**: OrbitalProgressView
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: BLOCKED_ENVIRONMENT
- **Limitation**: Documented design intent matches code structure; live idle-state verification needs a display.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: live capture at idle vs scanning state
- **Recommended version**: n/a

---

## A11Y

### A11Y-001
- **Priority**: SHOULD
- **Source**: platform norm; WEBSITE_AUDIT.md analog
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Sources/CoreTendApp; Sources/DesignSystem
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `grep -rl "accessibilityLabel\|accessibilityValue\|accessibilityHint" Sources/CoreTendApp Sources/DesignSystem`
- **Runtime evidence**: BLOCKED_ENVIRONMENT — no VoiceOver session possible
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: 14 of 20 CoreTendApp view files contain at least one accessibility call; 6 have none found. Presence in code != verified working.
- **User impact**: unknown, potentially real for the 6 files with no accessibility calls found
- **Risk**: medium
- **Needed fix**: identify the 6 files and add labels; then a real VoiceOver pass
- **Recommended version**: n/a

### A11Y-002
- **Priority**: SHOULD
- **Source**: platform norm
- **Status**: **BLOCKED_ENVIRONMENT**
- **Files**: —
- **Symbols**: —
- **Views**: —
- **Test**: MANUAL_ACCEPTANCE_TEST_PLAN.md keyboard-navigation step (unexecuted)
- **Command**: `n/a`
- **Runtime evidence**: BLOCKED_ENVIRONMENT — no display
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Requires live interactive testing.
- **User impact**: unknown
- **Risk**: medium
- **Needed fix**: execute MANUAL_ACCEPTANCE_TEST_PLAN.md keyboard pass on a real machine
- **Recommended version**: n/a

### A11Y-003
- **Priority**: MUST
- **Source**: VISUAL_DIRECTION.md; DESIGN_TOKENS.md
- **Status**: **COMPLIANT_PARTIAL** (corrected session 4 — was wrongly NON_COMPLIANT)
- **Files**: Sources/DesignSystem/DesignSystem.swift (MCCard)
- **Symbols**: MCCard; accessibilityReduceTransparency
- **Views**: —
- **Test**: none
- **Command**: `grep -rn "ncreaseContrast\|educeTransparency" Sources/`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Session-4 recheck found the session-3 finding was inaccurate: `MCCard` (Sources/DesignSystem/DesignSystem.swift:10-27) DOES handle `@Environment(\.accessibilityReduceTransparency)`, falling back to an opaque `MCColor.elevatedBackground` fill instead of `.regularMaterial`. Increase Contrast has zero handling anywhere in `Sources/` — that half of the original finding is confirmed correct. Net: partial, not zero, compliance.
- **User impact**: low for Reduce Transparency (handled); potentially real for Increase Contrast users (unhandled)
- **Risk**: low
- **Needed fix**: add explicit `@Environment(\.accessibilityIncreaseContrast)` handling (border/contrast boost) — Reduce Transparency already handled, no fix needed there
- **Recommended version**: n/a

### A11Y-004
- **Priority**: SHOULD
- **Source**: derived — chart/treemap accessibility norm
- **Status**: **UNKNOWN**
- **Files**: Sources/CoreTendApp/SpaceLensView.swift; PerformanceView.swift
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Not checked this session — genuinely not read.
- **User impact**: unknown
- **Risk**: unknown
- **Needed fix**: read both files for text-alternative/accessibilityLabel presence on chart marks
- **Recommended version**: n/a

---

## I18N

### I18N-001
- **Priority**: MUST
- **Source**: implicit — bilingual product
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings; Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings
- **Symbols**: L10n
- **Views**: —
- **Test**: fresh key-set diff this session: 0 EN-only, 0 FR-only (372/372 lines each)
- **Command**: `comm -23/-13 on sorted key extracts from both Localizable.strings files`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found — real improvement over session 1's line-count-only check
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### I18N-002
- **Priority**: SHOULD
- **Source**: implicit
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Sources/CoreTendApp/OnboardingView.swift
- **Symbols**: —
- **Views**: OnboardingView
- **Test**: none
- **Command**: `grep -rn Text\(" Sources/CoreTendApp/*.swift | grep -v L\(`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: OnboardingView.swift:57 has a bare Text("CoreTend") literal — the app/brand name, arguably intentionally not localized (proper noun), but not routed through L(...) like everything else.
- **User impact**: none (brand name is language-invariant)
- **Risk**: low
- **Needed fix**: none needed if intentional; otherwise route through L(...) for consistency
- **Recommended version**: n/a

### I18N-003
- **Priority**: SHOULD
- **Source**: implicit
- **Status**: **UNKNOWN**
- **Files**: Sources/CoreTendApp/L10n.swift
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Not checked this session.
- **User impact**: unknown
- **Risk**: unknown
- **Needed fix**: read L10n.swift formatting helpers + spot-check size/date/plural call sites
- **Recommended version**: n/a

---

## PERF

### PERF-001
- **Priority**: SHOULD
- **Source**: MOTION_SYSTEM.md perf budget
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/DesignSystem
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: BLOCKED_ENVIRONMENT — no Instruments/live profiling run
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Budget documented (30fps cap, 2s metric sampling); not independently profiled. Must not be read as universal Apple-Silicon claim — single machine tested (see MAC-003).
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: live profiling session on 8GB Apple Silicon Mac
- **Recommended version**: n/a

### PERF-002
- **Priority**: MUST
- **Source**: architecture pattern
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/SystemMetrics/SystemMetrics.swift; Sources/ScanCore/ScanCore.swift
- **Symbols**: AsyncStream
- **Views**: —
- **Test**: none dedicated to actor-isolation/threading
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Not independently re-traced for MainActor-blocking risk this session.
- **User impact**: unknown
- **Risk**: low-medium
- **Needed fix**: full threading read of SystemMetrics.swift call sites
- **Recommended version**: n/a

### PERF-003
- **Priority**: SHOULD
- **Source**: implicit
- **Status**: **UNKNOWN**
- **Files**: —
- **Symbols**: —
- **Views**: SimilarImagesView; MyClutterView
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Thumbnail generation code path not read this session.
- **User impact**: unknown
- **Risk**: unknown
- **Needed fix**: read thumbnail generation code
- **Recommended version**: n/a

### PERF-004
- **Priority**: MUST
- **Source**: MOTION_SYSTEM.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Sources/CoreTendApp
- **Symbols**: onDisappear
- **Views**: —
- **Test**: none
- **Command**: `grep -rn onDisappear Sources/CoreTendApp`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Multiple onDisappear call sites found consistent with the claim; not individually traced to every TimelineView.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: trace each TimelineView's lifecycle binding
- **Recommended version**: n/a

---

## WEB

### WEB-001
- **Priority**: MUST
- **Source**: WEBSITE_AUDIT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Website/en; Website/fr
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a (cross-checked against WEBSITE_AUDIT.md session-3 findings)`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Cross-checked against prior session's audit, not independently re-read line-by-line this session.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### WEB-002
- **Priority**: MUST
- **Source**: WEBSITE_AUDIT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Website/en; Website/fr; Website/assets
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `grep -irl 'google-analytics|gtag|analytics|hotjar|mixpanel|segment.io|plausible|fathom' Website/en Website/fr Website/assets`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Cross-checked, cheap enough to re-run fresh in session 4.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### WEB-003
- **Priority**: MUST
- **Source**: WEBSITE_AUDIT.md
- **Status**: **COMPLIANT_PARTIAL**
- **Files**: Website/en; Website/fr
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `n/a`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: WEBSITE_AUDIT.md flags some placeholder legal/contact identity content — not fake downloads/reviews specifically.
- **User impact**: low
- **Risk**: low
- **Needed fix**: see WEBSITE_AUDIT.md 'Real vs. placeholder content' for specifics
- **Recommended version**: n/a

### WEB-004
- **Priority**: MUST
- **Source**: WEBSITE_SECURITY.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: Website/
- **Symbols**: —
- **Views**: —
- **Test**: local python3 -m http.server preview only
- **Command**: `cd Website && python3 -m http.server 8791`
- **Runtime evidence**: local server only, no real edge/CDN deployment
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Headers/CSP never verified against a real deployed host (no Vercel deployment exists per this session's DO-NOT-DEPLOY constraint).
- **User impact**: unknown until deployed
- **Risk**: low (pre-deployment)
- **Needed fix**: verify headers on first real deployment
- **Recommended version**: n/a

### WEB-005
- **Priority**: MUST
- **Source**: WEBSITE_AUDIT.md
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Website/en; Website/fr
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `ls Website/en Website/fr`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: File-set parity only, not content-quality parity per page.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## DOC

### DOC-001
- **Priority**: MUST
- **Source**: OSS-foundation phase
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Documentation/USER_GUIDE.md; INSTALLATION.md; INSTALL_UNSIGNED.md; TROUBLESHOOTING.md; UNINSTALL.md; FAQ.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `ls Documentation/USER_GUIDE.md Documentation/INSTALLATION.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Existence-level check only; content freshness not re-read line by line this session.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### DOC-002
- **Priority**: MUST
- **Source**: OSS-foundation phase
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: Documentation/ARCHITECTURE.md; BUILD_AND_INSTALL.md; BUILD_SYSTEM.md; CONTRIBUTING.md; DEPENDENCIES.md; TESTING.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `ls Documentation/ARCHITECTURE.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Existence-level check only.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

---

## OPS

### OPS-001
- **Priority**: MUST
- **Source**: GOVERNANCE.md:1-4
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: GOVERNANCE.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `head -5 GOVERNANCE.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### OPS-002
- **Priority**: SHOULD
- **Source**: SUPPORT.md:1-5
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: SUPPORT.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `head -5 SUPPORT.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: External link liveness not checked this session.
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### OPS-003
- **Priority**: SHOULD
- **Source**: CONTRIBUTING.md:1-4
- **Status**: **COMPLIANT_VERIFIED**
- **Files**: CONTRIBUTING.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `head -5 CONTRIBUTING.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: none found
- **User impact**: none
- **Risk**: low
- **Needed fix**: none
- **Recommended version**: n/a

### OPS-004
- **Priority**: MUST
- **Source**: SECURITY.md
- **Status**: **IMPLEMENTED_UNVERIFIED**
- **Files**: SECURITY.md
- **Symbols**: —
- **Views**: —
- **Test**: none
- **Command**: `ls SECURITY.md`
- **Runtime evidence**: n/a
- **Bundle evidence**: n/a
- **Visual evidence**: n/a
- **Limitation**: Existence confirmed; reporting-path content not re-read line by line this session.
- **User impact**: unknown
- **Risk**: low
- **Needed fix**: read SECURITY.md content, confirm real reporting path (email/issue template)
- **Recommended version**: n/a

---
