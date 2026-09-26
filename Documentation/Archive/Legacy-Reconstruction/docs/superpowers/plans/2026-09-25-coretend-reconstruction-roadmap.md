# CoreTend Reconstruction Roadmap

> **For agentic workers:** This roadmap sequences independent programmes. Before implementing each programme, create and review its own executable plan from the approved spec and latest baseline. Follow the repository's evidence and safety rules.

**Goal:** Rebuild CoreTend as one coherent, local-first macOS product while preserving user data, release provenance, and approved safety invariants.

**Architecture:** Replace existing capabilities incrementally behind explicit contracts. Keep UI, domain engines, persistence, macOS adapters, safety gate, website, and release evidence in separately verifiable boundaries. Do not remove an old path until its replacement passes contract and migration evidence.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, SQLite through existing native API, HTML/CSS/JavaScript static website, existing repository gates; no new runtime dependency without maintainer decision.

**Spec:** `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md`

## Global Constraints

- macOS 14+ arm64 remains initial target until evidence-backed decision changes it.
- Scans remain read-only; file operations go to macOS Trash after review, confirmation, and execution-time revalidation.
- Never claim freed storage, malware detection, or health score without measurable evidence; current product excludes these claims.
- No telemetry, analytics, account, cloud sync, privileged helper, or scheduled file operation.
- No release, tag, push, site deploy, public announcement, or credentials use without separate explicit maintainer authorization.
- Preserve all pre-existing untracked files and all Git history; no global reset or cleanup.
- Every behavioural change has requirement traceability, targeted checks, and rollback notes.
- Update derived documents from their generators; never hand-edit generated artifacts.

---

## Programme sequence

| Order | Programme | Independent deliverable | Entry gate | Exit gate |
|---:|---|---|---|---|
| 0 | Baseline and requirements reconciliation | Current-state evidence pack, resolved source hierarchy, complete requirement-to-evidence matrix | Approved reconstruction cahier | Maintainer accepts baseline and sees all contradictions/open decisions |
| 1 | Safety and persistence contracts | Typed file-operation contract, durable event contract, versioned data migration policy | Programme 0 exit | Safety invariants have failing-then-passing regression evidence; supported DB history migrates and rolls back safely |
| 2 | Analysis engines and domain capabilities | Stable scan, duplicate, space, application, integrity, and metrics APIs | Programme 1 contracts accepted | Each capability meets FR contracts with fixtures, cancellation/error semantics, bounded resource use |
| 3 | Application shell and destination experiences | Native navigation, onboarding, eleven destinations, settings, empty/error/loading/permission states | Programmes 1–2 APIs stable | Functional, keyboard, VoiceOver, visual and reduced-motion acceptance passes |
| 4 | Website, documentation, localization and distribution integration | Matching public explanations, generated release facts, site installation flow, support docs | Core product content and release facts accepted | Site/content gates agree with verified app build and supported channel |
| 5 | Hardening and candidate evidence | Compatibility, performance, privacy/security, packaging, install and recovery report | Programmes 1–4 complete | Every MUST has evidence; maintainer accepts candidate; release still requires separate authorization |

### Programme 0 — Baseline and requirements reconciliation

Executable plan: `2026-09-25-coretend-baseline-reconciliation.md`.

1. Record exact Git branch/commit, worktree status, branch ancestry, package targets, generated assets, and non-tracked work without changing them.
2. Re-measure build, tests, repository gates, localization, site, accessibility and release-artifact facts. Record command, timestamp, result and machine limitations. Do not repeat stale counts as facts.
3. Compare README, current app, package, generated feature inventory, persistence schema, public release manifest and remote release artifact evidence. Mark each claim verified, contradicted, historical, or unknown.
4. Reconcile existing requirement register with cahier FR/NFR IDs. Preserve useful evidence and link sources; reclassify unverified claims rather than duplicating stale matrices.
5. Publish baseline and decision register. Ask maintainer to decide only decisions the cahier leaves open and that block programme 1–5.

### Programme 1 — Safety and persistence contracts

Executable plan: `2026-09-25-coretend-safety-persistence-contracts.md`. Audit all write paths, approved operation types, path normalization and protected roots. Define one durable audit event lifecycle for approved/refused/moved/failed/cancelled work; resolve logging failure semantics. Reconcile current copy claiming activity totals with no-freed-space rule. Inspect deployed schema history and build migration fixtures. Add regression proof before altering behavior. Keep Trash as sole file-removal destination.

### Programme 2 — Analysis engines and domain capabilities

Create separate plan after contract approval. Audit engine boundaries and UI coupling. Define typed inputs/outputs, cancellation, partial failures, measurement provenance and resource limits. Consolidate only duplicate scans with equivalent semantics. Preserve cloud placeholder vs local-byte distinction. Integrity remains read-only and native-signal-only. Use fixture trees; avoid real user paths in tests and captures.

### Programme 3 — Application shell and destination experiences

Create separate plan after engine API approval. Agree information architecture from current eleven destinations and approved cahier; then rebuild shell and module views in task-sized slices. Avoid moving source folders until path-dependent tests/scripts have been decoupled. Give every destination loading, empty, populated, failed, cancelled and permission-limited states. Verify keyboard/focus/VoiceOver/reduced-motion behavior alongside interaction and captures.

### Programme 4 — Website, documentation, localization and distribution

Create separate plan after product language and capabilities settle. Keep site static and dependency-free. Make verified release manifest the source for version, architecture, checksum, signature and download links. Rebuild all claims from tested product behavior, preserve EN/FR parity, replace screenshots only with reviewed current-build captures. Keep Homebrew and App Store as explicit channel decisions; do not publish.

### Programme 5 — Hardening and candidate evidence

Create separate plan after integration. Establish performance budgets from baseline data; expand hardware/macOS validation; run security and privacy review; exercise database backup/restore and install/upgrade/uninstall from clean state. Run full quality/release gates and assemble evidence. Do not create tag or publish candidate without separate authorization.

## Cross-programme review gates

- **Before a programme:** its design decisions, exact files, interfaces, rollback, and acceptance proofs appear in an approved executable plan.
- **Before a code slice:** add regression test or reproducible proof that fails for missing behavior, then implement smallest change.
- **Before a safety-sensitive change:** trace every reachable write API, source of path, symlink/volume assumptions, audit event and refusal state.
- **Before a visual claim:** capture correct build/state, open and inspect it; record language, appearance and display size.
- **Before a release claim:** compare built bytes to verified signed/notarized artifact and public checksums; never infer status from old JSON alone.

## Definition of reconstruction complete

Reconstruction is complete only when all Must requirements in approved spec map to current implementation and reviewable evidence; supported data upgrade preserves user state; app/site/docs/release facts agree; required accessibility, compatibility, privacy/security, performance and quality gates pass; known limits are disclosed; maintainer accepts candidate. It does not imply permission to publish.
