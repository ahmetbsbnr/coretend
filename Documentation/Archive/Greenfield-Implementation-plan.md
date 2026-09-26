# CoreTend Greenfield Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild CoreTend from a clean repository with eight native macOS destinations, auditable local engines, a Trash-only action boundary, read-only CLI, static site, and complete verification evidence.

**Architecture:** Create standalone git repository at `../rebuild/`; never import source files/assets from `app/`. Swift 6 + SwiftUI + SwiftPM with zero runtime dependencies; UI calls use cases, engines remain read-only, and every file mutation flows through SafetyCore. SQLite stores local records behind an actor; static site and CLI consume shared product contracts.

**Tech Stack:** macOS 14+, arm64 initial target; Swift 6, SwiftUI, SwiftPM, SQLite3 system library, XCTest, static HTML/CSS/JS site, shell-based local gates.

**Spec:** `../app/docs/superpowers/specs/2026-09-26-coretend-greenfield-cahier.md`; baseline: `../app/Documentation/Reconstruction/BASELINE.md`.

## Global Constraints

- Work only in `rebuild/` after creating it empty; keep `app/` and its pre-existing untracked paths untouched.
- Do not copy/import Swift, assets, generated artifacts, or git history from `app/`; use documents and observable contracts as reference.
- No test may enumerate, read, write, move, or remove real user home, CoreTend store, or macOS Trash; every mutation uses a unique temporary fixture root and fake Trash adapter.
- Production file operation is `FileManager.trashItem` only; no permanent deletion fallback, shell deletion, privileged helper, schedule, or cleanup-on-deinit.
- Scans and CLI are read-only. UI cannot call filesystem mutation APIs directly.
- SQLite migrations are tested only against synthetic versioned fixtures. Legacy migration is allowlisted, copy-only, idempotent, and source-preserving.
- No network except a user-initiated metadata-only update check if retained; no download/install, telemetry, account, cloud sync, or analytics.
- No signing identity, notarization, release, publish, push, or tag. Build local artifacts only.
- Track all FR-01…FR-26, NFR-01…NFR-14 and all 51 feature IDs in `Documentation/Traceability.csv`; documentary assertion alone never earns `VERIFIED`.
- Make a focused commit after each independently verified task; never include user data or generated machine-specific files.

---

## Repository map and shared interfaces

Create focused Swift packages/targets under `Packages/` and app/site/docs at root:

- `Packages/ProductContract/Sources/ProductContract/{Capability.swift,Requirement.swift,ProductManifest.swift,LocalizedMessage.swift}`: stable IDs, capability metadata, severity and unknown-value representation; no filesystem access.
- `Packages/SafetyCore/Sources/SafetyCore/{PathScope.swift,PathValidator.swift,ApprovedFileOperation.swift,TrashClient.swift,ActionExecutor.swift,ActionEvent.swift}`: sole mutation gateway and typed outcomes.
- `Packages/ScanCore/Sources/ScanCore/{ScanRequest.swift,ScanEvent.swift,ScanEngine.swift,FileRule.swift,DuplicateEngine.swift,StorageMeasurement.swift}`: cancellable read-only async streams.
- `Packages/Persistence/Sources/Persistence/{Store.swift,SQLiteStore.swift,Schema.swift,Migration.swift,ActivityRepository.swift,PreferencesRepository.swift}`: actor-isolated local storage.
- `Packages/Domain/Sources/Domain/{ExploreService.swift,IntegrityService.swift,MetricsService.swift,ApplicationService.swift,UseCase.swift}`: read-only domain use cases.
- `Sources/CoreTendApp/`: app lifecycle, view model, reusable UI, eight destination views, settings/onboarding.
- `Sources/CoreTendCLI/`: argument parser and read-only commands; no dependency on SafetyCore mutation executor.
- `Website/`: static EN/FR pages, shared product manifest generated from ProductContract export, accessibility/security gates.
- `Documentation/`: user guide, developer guide, threat model, data/migration contracts, FR/NFR/feature traceability, decision log, evidence ledger.
- `Tests/Fixtures/`: generated synthetic trees, database versions, expected outputs. Never store personal paths or copied source artifacts.

Required contracts (define in Task 1 and preserve):

```swift
public struct FileIdentity: Hashable, Codable { public let standardizedPath: String; public let device: UInt64?; public let inode: UInt64? }
public struct ApprovedFileOperation: Sendable { public let id: UUID; public let target: FileIdentity; public let ruleID: String; public let approvedAt: Date; public let expiresAt: Date }
public enum ActionOutcome: Sendable, Equatable { case movedToTrash(original: String, trashURL: String); case refused(RefusalReason); case failed(ActionFailure); case cancelled }
public protocol TrashClient: Sendable { func moveToTrash(_ url: URL) async throws -> URL }
public protocol FileOperationExecutor: Sendable { func execute(_ operation: ApprovedFileOperation) async -> ActionOutcome }
public struct ScanRequest: Sendable { public let roots: [URL]; public let ruleIDs: Set<String>; public let exclusions: [URL] }
public enum ScanEvent: Sendable { case progress(completed: Int, estimatedTotal: Int?); case result(ScanResult); case finished; case failed(ScanFailure) }
public protocol ScanEngine: Sendable { func scan(_ request: ScanRequest) -> AsyncThrowingStream<ScanEvent, Error> }
public protocol CoreTendStore: Sendable { func append(_ event: ActivityEvent) async throws; func events(query: ActivityQuery) async throws -> [ActivityEvent]; func migrate() async throws }
```

Interfaces may be refined only when tests and traceability are updated in the same task. Expiring approval and execution revalidation must compare canonical path, root scope, volume, symlink status, existence, identity when available, and rule allowlist immediately before Trash call.

## Task 1: Empty repository, contracts, and evidence skeleton

**Files:** new repo root; `Package.swift`; `Sources/ProductContract/**`; `Tests/ProductContractTests/**`; `Documentation/Traceability.csv`; `Documentation/Decisions/0001-greenfield.md`; `.gitignore`; `Makefile`.

- [ ] Verify `../rebuild` does not exist and create empty directory; initialize git there, with no template or copied files.
- [ ] Add SwiftPM package with ProductContract library and XCTest target; compile with `swift test`.
- [ ] Add tests for stable unique capability IDs, all 51 IDs listed in approved cahier, FR/NFR ID parsing, and unknown measurement formatting.
- [ ] Implement `CapabilityID`, `RequirementID`, `Measurement<Value>` (`known`, `unknown(reason:)`), and product manifest types.
- [ ] Create `Documentation/Traceability.csv` with every FR/NFR/feature ID, priority, code/test/docs/evidence/status columns; initial status `À_CONSTRUIRE`.
- [ ] Add `make test`, `make build`, `make audit`; audit checks forbidden destructive APIs and prohibited path literals in test sources.
- [ ] Run `swift test`; expected all contract tests pass; commit `chore: establish greenfield CoreTend contracts`.

## Task 2: SafetyCore Trash-only boundary

**Files:** `Packages/SafetyCore/Package.swift`; source files listed above; `Tests/SafetyCoreTests/{PathValidatorTests,ActionExecutorTests,FakeTrashClient}.swift`; root package dependency.

- [ ] Write failing fixture tests for path traversal, root escape, symlink escape, expired approval, changed inode, disallowed rule, nonexistent target, and unsupported volume.
- [ ] Write failing test: fake Trash throws; original fixture remains byte-identical and action result is `.failed`, never `.movedToTrash`.
- [ ] Define `TrashClient`, `ApprovedFileOperation`, typed refusal/failure, immutable `ActionEvent`; only executor accepts approved operations.
- [ ] Implement canonical path/root/device/inode/symlink revalidation at approval and execution; default deny on unavailable evidence where scope cannot be proven.
- [ ] Implement production adapter calling only `FileManager.trashItem`; implement fake adapter that moves only within fixture `trashRoot` and can inject failure.
- [ ] Verify scan targets and app source have no direct mutation call; static audit fails on `removeItem`, `remove`, `unlink`, shell `rm`, or equivalent outside explicit fixture adapter. Verify fake Trash receives every executor action.
- [ ] Run `swift test --filter SafetyCoreTests`; expected source-preservation, typed-error, replay/expiry and race tests pass; commit `feat: enforce Trash-only file actions`.

## Task 3: Persistence, event history, and synthetic migrations

**Files:** `Packages/Persistence/**`; `Tests/PersistenceTests/**`; `Tests/Fixtures/Database/**`; `Documentation/DataModel.md`; `Documentation/Migration.md`.

- [ ] Write failing tests against temporary SQLite URLs for schema creation, transaction rollback, event ordering, query filters/grouping, retention and export.
- [ ] Define event enum for proposal/approval/refusal/cancel/success/failure; store measurements and paths with documented redaction policy; separate scan facts from action outcomes.
- [ ] Implement actor-backed SQLite schema migrations with `PRAGMA user_version`, transaction and explicit backup of the fixture DB before each migration.
- [ ] Add synthetic v0/v1 DB fixtures generated by test helpers; migration must be idempotent, preserve rows, and recover from injected interruption without partial-success marker.
- [ ] Implement allowlisted legacy import as a separately invoked copy-only service taking explicit fixture URL; never search HOME for legacy DB. Verify source bytes and metadata unchanged after success/failure/retry.
- [ ] Add exclusions/preferences repository, clear-history and CSV/JSON export; diagnostic export uses explicit destination, preview model, and redaction tests.
- [ ] Run `swift test --filter PersistenceTests`; inspect fixture roots in output; commit `feat: add local event store and safe migrations`.

## Task 4: Read-only scan and domain engines

**Files:** `Packages/ScanCore/**`; `Packages/Domain/**`; `Tests/ScanCoreTests/**`; `Tests/DomainTests/**`; `Documentation/Rules.md`.

- [ ] Write fixture tests proving each scan rule reports candidates and performs no writes, with cancellation and permission-denied results distinct.
- [ ] Implement async cancellable traversal that yields typed results/progress, observes exclusions, avoids following symlinks, handles races as per-item errors, and never invokes SafetyCore.
- [ ] Implement seven cleanup rules with explicit root allowlists, risk labels, metadata-only result records, and no implicit inclusion of user folders.
- [ ] Implement exact duplicates via chunked hashing with hash cache keyed by identity/mtime/size; retain one copy invariant and treat concurrent changes as stale/error.
- [ ] Implement Explore size model (allocated/local/logical/unknown), sparse/hard-link/cloud-placeholder policies; treemap aggregates only known allocated bytes and labels exclusions/unknowns.
- [ ] Implement similar-image candidate pipeline with metadata/thumbnail decoding bounded to selected image fixtures; no upload and no write to scanned trees.
- [ ] Implement app discovery/leftover attribution conservatively, update-source metadata only, Integrity native signals, and timestamped system metrics; no malware verdict or unmeasured unit.
- [ ] Run scan/domain tests and static mutation audit; commit `feat: add read-only scan and domain engines`.

## Task 5: Native app shell and eight destinations

**Files:** `Sources/CoreTendApp/**`; `Tests/CoreTendAppTests/**`; `Documentation/UX/**`.

- [ ] Define route enum for Overview, Record, Cleanup, Explore, Duplicates, Applications, Integrity, Performance plus Settings/Onboarding as supporting surfaces; add navigation state restoration test.
- [ ] Implement dependency container injecting scan/store/action protocols; compile-time boundary keeps views from importing raw filesystem mutation APIs.
- [ ] Build shared design tokens, localized EN/FR messages, loading/empty/error/restricted/cancelled states, keyboard focus order, VoiceOver labels and reduced-motion behavior.
- [ ] Build each destination from domain view models; bind all mutation affordances to candidate review → explicit confirmation → SafetyCore executor; no row swipe directly mutates.
- [ ] Implement Overview, Record filters/grouping/export, Cleanup risk/exclusion/review, Explore search/treemap/Quick Look, Duplicates keep-one review, Applications review/uninstall/update source, Integrity evidence/limits, Performance real measurements.
- [ ] Implement onboarding, permission explanations and settings for exclusions, language, optional menu bar, history retention and explicit clear; permissions never gate unrelated read-only destinations.
- [ ] Add UI tests with injected fakes and synthetic fixtures; exercise all eight routes, failure/restricted/empty states, EN/FR key parity and no direct mutation.
- [ ] Run app unit/UI tests and `swift build`; commit `feat: build native CoreTend experience`.

## Task 6: Read-only CLI and migration user flow

**Files:** `Sources/CoreTendCLI/**`; `Tests/CoreTendCLITests/**`; `Documentation/CLI.md`.

- [ ] Specify commands `coretend scan --rule <id> --root <path> --format json|text`, `coretend record list`, `coretend version`, `coretend help`; reject unknown flags and mutation verbs with stable exit codes.
- [ ] Implement parser and output through shared read-only services; inject all roots/store paths; do not create store implicitly outside explicit `--store` test path.
- [ ] Test JSON schema, localization, permission errors, path-scoped behavior and that CLI target has no dependency on `FileOperationExecutor` or mutating system APIs.
- [ ] Document legacy-data detection as user-triggered selection only, fixture-driven preview, copy-only import, retry, and how user can retain/clear old data themselves.
- [ ] Run CLI tests and dependency graph audit; commit `feat: add read-only CoreTend CLI`.

## Task 7: Static website, docs, and traceability generator

**Files:** `Website/**`; `Scripts/{generate-manifest,check-localization,check-traceability,audit-safety}.swift`; `Documentation/{UserGuide,DeveloperGuide,ThreatModel,Accessibility,ReleaseEvidence}.md`; `Makefile`.

- [ ] Create static EN/FR product, feature, privacy, support and developer pages using a checked-in manifest exported from ProductContract; no tracking scripts or runtime account calls.
- [ ] Add CSP, keyboard navigation, semantic headings, visible focus, 200% zoom and reduced-motion checks; build HTML with zero external runtime dependencies.
- [ ] Add generators/checkers: manifest output deterministic; localization key parity exact; all requirement/capability IDs accounted for; every `VÉRIFIÉ` row names code, test and evidence path.
- [ ] Write threat model, permissions, data lifecycle, migration and recovery, accessibility manual checklist, build/install/uninstall instructions and claim boundaries.
- [ ] Include release page wording that clearly labels project as local/unpublished and contains no fabricated version/download/checksum/signature claims.
- [ ] Run `make audit`, website validation and documentation link checks; commit `docs: add bilingual site and reconstruction evidence`.

## Task 8: Hardening, installation package, and qualification

**Files:** `Scripts/{qualify,package-local,verify-package}.sh`; `Tests/Acceptance/**`; `Documentation/Evidence/**`; app/package settings.

- [ ] Record baseline startup/scan/idle CPU/RSS on available host with corpus generator; propose budgets from measured values and document host/OS/date; no guessed performance pass threshold.
- [ ] Run full unit, integration, UI, static safety, localization, accessibility automation, website, package and dependency audits. Verify tests use only per-run temporary fixture roots.
- [ ] Generate local unsigned app/package into ignored `Artifacts/`; install and launch under a dedicated temporary HOME; verify no install script touches user folders and uninstall instructions remove only package-owned files.
- [ ] Manually inspect all eight routes at standard and 200% zoom, keyboard-only and VoiceOver; document observations and unresolved accessibility issues.
- [ ] Generate evidence ledger linking each Must FR/NFR and all 51 IDs to implementation, tests/gates, artifact/evidence, and status; unresolved Must remains `PARTIEL` and blocks qualification claim.
- [ ] Verify release metadata contains no fabricated public release claim; verify git remotes unchanged and no push/tag/sign/notarize/deploy occurred.
- [ ] Run `make qualify`; report exact command/output and any host-dependent gates not executable; commit `chore: qualify local greenfield build` only when evidence passes.

## Rollback and stop conditions

- Every task is isolated to `rebuild/`; rollback is `git revert <task-commit>` inside that repository. Never use `clean`, broad reset, or scripts that traverse outside the repo.
- Stop an action task if canonical path, volume, identity, root, allowlist, Trash result, or audit write is uncertain; preserve source and return typed failure.
- Stop migration if fixture backup or transaction boundary fails; leave input untouched and report failure.
- Stop qualification if any test resolves path outside its temporary fixture root, if static gate detects direct mutation, if FR/NFR evidence is absent, or if a public release claim lacks matching artifact evidence.
- No test is run against user's real CoreTend store or Trash, even for read-only inspection.

## Self-review against cahier

- QQOQCCP, objectives/non-objectives, architecture, all 26 FR, all 14 NFR, MoSCoW, RACI, eight destinations and 51 feature IDs are traced across Tasks 1–8 and `Traceability.csv`.
- High-risk FR-05/06/20/26 and NFR-01/02/03/05 are isolated in Tasks 2–3, then consumed by UI in Task 5; errors preserve originals.
- All seven Cleanup rules are assigned Task 4; every public route and secondary UX surface is assigned Task 5; read-only CLI Task 6; site/docs Task 7; end-to-end package evidence Task 8.
- No unresolved TODO/TBD/“implement later” placeholders; acceptance commands, fixture boundaries, rollback and stop rules are explicit.
- Contract names in Task 2–6 match shared interface section. Any implementation adjustment requires paired contract/test/traceability edits.
