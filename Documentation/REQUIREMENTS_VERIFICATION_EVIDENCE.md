# Requirements Verification Evidence

AUDITED_SOURCE_COMMIT: `b33c06b8d68b9b03316821c3f6cfb17252f35011`. Structured evidence blocks for
the most load-bearing MUST requirements — safety, security, privacy, and distribution-honesty —
keyed to requirement IDs from `MASTER_REQUIREMENTS_BASELINE.md` (mirrors the format of the prior
feature audit's `AUDIT_EVIDENCE.md`, but keyed to requirement IDs, not feature IDs). 18 entries.

---

### EVIDENCE-SAFE-001
- **Claim**: Scans never delete; deletion only happens through a separate explicit step.
- **Files**: `Sources/ScanCore/ScanCore.swift`, `Sources/SafetyCore/SafetyCore.swift`
- **Symbols**: `ScanEngine`, `SafetyCenter.execute(_:)`
- **Tests**: none dedicated to this exact architectural boundary
- **Command**: `grep -rn "trashItem\|removeItem" Sources/ScanCore Sources/SafetyCore`
- **Result**: only `SafetyCenter.execute` (in `SafetyCore.swift`) calls `fileManager.trashItem`;
  zero matches in `ScanCore.swift`. HOLDS.

### EVIDENCE-SAFE-002
- **Claim**: Deletion engines only accept a validated candidate type (`ApprovedFileOperation`),
  never a raw `URL`.
- **Files**: `Sources/SafetyCore/SafetyCore.swift`
- **Symbols**: `SafetyCenter.execute(_ operations: [ApprovedFileOperation])`,
  `SafetyCenter.approve(url:logicalSize:ruleID:risk:) -> ApprovedFileOperation`
- **Tests**: none dedicated
- **Command**: `read Sources/SafetyCore/SafetyCore.swift:94-165`
- **Result**: `execute`'s only parameter type is `[ApprovedFileOperation]`; the only way to obtain
  one is `approve(url:...)`, which runs `validator.validate(url)` before constructing it, and the
  initializer is `fileprivate`. No public path bypasses validation. HOLDS. (Previously flagged in
  the baseline as "not independently re-verified" — now directly re-verified.)

### EVIDENCE-SAFE-003
- **Claim**: The user's home directory is never an auto-selectable deletion target.
- **Files**: `Sources/SafetyCore/SafetyCore.swift`
- **Symbols**: `PathValidator.validate(_:)`
- **Tests**: none dedicated
- **Command**: `read Sources/SafetyCore/SafetyCore.swift:56-81`
- **Result**: line 68-69: `let home = FileManager.default.homeDirectoryForCurrentUser...; guard
  standardized.path != home.path else { throw .protectedRoot(home.path) }`. HOLDS.

### EVIDENCE-SAFE-004
- **Claim**: User content roots (Documents, Desktop, Pictures, Music, Movies) are never
  auto-included in scan scope.
- **Files**: `Sources/ScanCore/ScanCore.swift`, `Tests/ScanCoreTests`
- **Symbols**: `ScanEngine`, `ScanConfiguration`
- **Tests**: `downloadsOnlyScanNeverTouchesSiblingDirectories` (Scan root isolation suite) — read
  the test body this session: it scans a fixture Downloads-only root and asserts zero findings
  from sibling Documents/Desktop/Pictures/Music/Movies fixtures.
- **Command**: `bash Scripts/test.sh`
- **Result**: 86/86 tests passed, including this suite. HOLDS.

### EVIDENCE-SAFE-005
- **Claim**: Dry-run is the default state; the user must explicitly opt into real deletion.
- **Files**: `Sources/SafetyCore/SafetyCore.swift`
- **Symbols**: `SafetyCenter.init(validator:dryRun: Bool = true)`
- **Tests**: none dedicated
- **Command**: `read Sources/SafetyCore/SafetyCore.swift:126`
- **Result**: default parameter `dryRun: Bool = true`. HOLDS at the SafetyCore layer. Not
  exhaustively re-checked this session that every one of the 5 UI call sites
  (`CleanupView.swift`, `DuplicatesView.swift`, `ApplicationsView.swift`, `LeftoversView.swift`,
  `PrivacyCleanerView.swift`) also initializes its own `@State` dryRun flag to `true` — flagged
  for session 3.

### EVIDENCE-SAFE-006
- **Claim**: Symlinks are never followed during scans.
- **Files**: `Sources/ScanCore/ScanCore.swift`, `Tests/ScanCoreTests`
- **Tests**: `symlinkedDirectoryNotDescended()`
- **Command**: `bash Scripts/test.sh`
- **Result**: test passed this session. HOLDS.

### EVIDENCE-PROTECTION-001
- **Claim**: Protection never fabricates scan capability when ClamAV is absent — it shows an
  honest "unavailable" state.
- **Files**: `Sources/CoreTendApp/ProtectionView.swift`, `Sources/MalwareEngine/MalwareEngine.swift`
- **Symbols**: `ClamAVScanner.isAvailable`, `ProtectionView` (guards at lines 27, 97)
- **Tests**: none (no headless GUI test harness)
- **Command**: `grep -n isAvailable Sources/CoreTendApp/ProtectionView.swift`; `bash
  Scripts/doctor.sh` (confirms `clamscan not found` in this environment)
- **Result**: `ClamAVScanner.isAvailable` is computed purely from whether a real binary exists at
  one of three known paths (`ClamAVScanner.knownPaths`) — there is no simulated/fake-success
  branch in `MalwareEngine.swift`. `ProtectionView.swift` gates its real-scan UI behind this flag
  at two call sites. HOLDS structurally. Not visually screenshotted this session (headless) — see
  `MANUAL_ACCEPTANCE_TEST_PLAN.md`.

### EVIDENCE-SEC-001
- **Claim**: No shell-injectable subprocess invocation.
- **Files**: `Sources/MalwareEngine/MalwareEngine.swift`
- **Symbols**: `ClamAVScanner.scan(paths:)`
- **Command**: `read Sources/MalwareEngine/MalwareEngine.swift:50-58`
- **Result**: `process.arguments = ["--no-summary", "--infected", "--recursive"] +
  paths.map(\.path)` — an argument array, no shell string interpolation. This is the only
  `Process()` call in `Sources/` (confirmed by `grep -rn "Process()" Sources/`). HOLDS
  (re-verified independently this session; baseline had it as trusted-not-rechecked).

### EVIDENCE-SEC-002
- **Claim**: No sudo invocations from the app.
- **Files**: `Sources/`
- **Command**: `grep -rn '"sudo\|sudo ' Sources/`
- **Result**: zero literal `sudo` strings anywhere in `Sources/`. HOLDS (re-verified independently
  this session).

### EVIDENCE-SEC-003
- **Claim**: No Gatekeeper/SIP-bypass instructions presented without a clear warning in shipped
  docs.
- **Files**: `Documentation/INSTALL_UNSIGNED.md`, `Documentation/REQUIREMENTS_DECISION_HISTORY.md`
- **Command**: `bash Scripts/test-release-manifest.sh`
- **Result**: **FAILED at session start** — `REQUIREMENTS_DECISION_HISTORY.md` (a session-1
  artifact) mentioned `sudo spctl --master-disable` with its "Do not..." warning on the line
  *after* the mention; the script's look-behind-only heuristic (checks 5 lines *before* a
  dangerous-command match for a warning word) didn't credit it. Fixed this session by reordering
  the sentence so the warning precedes the command mention (see `git log`, `fix(audit)` commit).
  Re-ran: `Scripts/test-release-manifest.sh` now reports "OK: no unwarned dangerous Gatekeeper/
  SIP-bypass commands in Documentation/ or Release/Notes/". HOLDS after the fix.

### EVIDENCE-DIST-001
- **Claim**: SHA256SUMS must verify against the actually-built artifacts.
- **Files**: `Release/latest.json`, `Release/SHA256SUMS`, `Scripts/build-release.sh`
- **Command**: `bash Scripts/build-release.sh && bash Scripts/test-release-manifest.sh`
- **Result**: fresh end-to-end run this session — after the SEC-003 fix above, **ALL CHECKS
  PASSED** (SHA256SUMS verifies against files on disk, zipSHA256/dmgSHA256/zipSize/dmgSize all
  match, unsigned/notarized declared consistently, no unwarned dangerous commands, manifest
  auto-resynced after rebuild). HOLDS.

### EVIDENCE-DIST-002
- **Claim**: Manifest declares signed/notarized status truthfully.
- **Files**: `Release/latest.json`, `Documentation/INSTALL_UNSIGNED.md`
- **Command**: `bash Scripts/test-release-manifest.sh`
- **Result**: `signed:false, notarized:false` in the freshly rebuilt manifest, matches
  `INSTALL_UNSIGNED.md`'s stated status. HOLDS.

### EVIDENCE-MAC-001
- **Claim**: Apple Silicon (arm64) only.
- **Files**: `Release/latest.json`, distribution artifacts
- **Command**: `bash Scripts/test-distribution.sh` ("Checking arm64 architecture" section)
- **Result**: "OK: binary is arm64". HOLDS.

### EVIDENCE-MAC-002
- **Claim**: macOS 14.0 (Sonoma) minimum, justified by `@Observable`.
- **Files**: `Package.swift`
- **Command**: `grep -n macOS Package.swift`
- **Result**: platform floor set to `.macOS(.v14)`. HOLDS (the 16-usage `@Observable` count itself
  was not independently re-tallied this session — trusted from `API_AVAILABILITY_AUDIT.md`).

### EVIDENCE-LEGAL-001
- **Claim**: Source code under Apache-2.0; zero conflicting dependencies.
- **Files**: `LICENSE`, `LICENSES/Apache-2.0.txt`, `Package.swift`
- **Command**: `bash Scripts/check-licenses.sh`
- **Result**: all checks OK, including `0 .package(...) entries in Package.swift`. HOLDS.

### EVIDENCE-LEGAL-004
- **Claim**: LICENSE cross-references point at files that exist.
- **Files**: `LICENSE`, `Documentation/LEGAL_AND_LICENSE_STATUS.md`, `Documentation/THIRD_PARTY.md`
- **Command**: `grep -n Documentation/ LICENSE`; `ls` on the two referenced files
- **Result**: both files exist on disk. HOLDS (fixed in prior commit `964f110`, not re-broken).

### EVIDENCE-OSS-002
- **Claim**: ClamAV is a runtime-only, never-linked, never-bundled dependency.
- **Files**: `Sources/MalwareEngine/MalwareEngine.swift`, `Package.swift`
- **Command**: `grep -rn "libclamav\|clamav" Package.swift Sources/`
- **Result**: `ClamAVScanner` only probes known filesystem paths for a pre-installed `clamscan`
  binary at runtime; no linkage in `Package.swift`; `Scripts/test-distribution.sh` confirms no
  third-party binaries are embedded in the shipped app bundle. HOLDS.

### EVIDENCE-TEST-001
- **Claim**: `bash Scripts/test.sh` is the only sanctioned test entry point (bare `swift test`
  lacks the linker flags Swift Testing needs under CommandLineTools-only toolchains).
- **Files**: `Scripts/test.sh`
- **Command**: `bash Scripts/test.sh`
- **Result**: 86 tests, 27 suites, all passed, freshly re-run this session. HOLDS.

### EVIDENCE-PRIV-001
- **Claim**: No network access from the app.
- **Files**: `Sources/`
- **Command**: `grep -rln "URLSession\|Socket(\|CFSocket\|NWConnection" Sources/`
- **Result**: zero matches, re-run fresh this session (baseline flagged this as needing
  independent re-verification, not just trusting the prior grep). HOLDS at the
  symbol-name-grep level; full confidence would need a live network-monitor capture during a real
  run (not possible headless — see `MANUAL_ACCEPTANCE_TEST_PLAN.md`).
