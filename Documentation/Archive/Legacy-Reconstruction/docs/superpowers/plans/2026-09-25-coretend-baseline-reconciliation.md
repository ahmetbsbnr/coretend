# CoreTend Baseline Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Produce accepted, evidence-backed baseline of active CoreTend product and trace every cahier requirement to current evidence or an explicit gap.

**Architecture:** Documentation-only audit. Gather non-mutating Git, package, source, build, test, site and release evidence into one reconstruction folder. Keep historical reports intact and mark disagreement instead of silently changing published-release facts.

**Tech Stack:** SwiftPM and existing repository scripts for measurements; Markdown and JSON already used by repo; Git metadata. No code or data migration in this programme.

**Spec:** `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md`

**Roadmap:** `docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md`

## Global Constraints

- Do not edit product code, release configuration, published manifests, credentials, user databases or generated artifacts.
- Do not change branch, reset, stash, clean, delete, checkout another branch, push, tag, publish or deploy.
- Preserve pre-existing worktree additions including `.claude-flow/`, `Documentation/Captures/`, `Xcode/`, `graphify-out/` and this planning directory.
- Treat command output and inspected source as evidence; stale documentation is a lead, not proof.
- Do not claim build/test/gate status unless command was run in current tree and output recorded.
- Separate VERIFIED, CONTRADICTED, HISTORICAL and UNKNOWN facts in baseline.
- Never expose secret values, local identity files, private keys, API tokens, or personal filesystem contents in report.

---

## File Structure

- Create `Documentation/Reconstruction/BASELINE.md` — one timestamped current-state evidence report and source precedence.
- Create `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md` — cahier IDs mapped to current implementation and evidence.
- Create `Documentation/Reconstruction/DECISIONS.md` — open owner decisions only; each entry has impact, options, recommendation, blocking programme.
- Modify `Documentation/README.md` — link reconstruction dossier and identify it as current baseline, without demoting historical evidence until validated.
- Modify `docs/README.md` — link cahier and roadmap as decided project artifacts.
- Modify `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` only if inspection confirms it is not generated and can be safely reconciled; otherwise link new matrix and preserve generated ownership.

## Tasks

### Task 1: Capture repository and branch baseline

**Files:**
- Create: `Documentation/Reconstruction/BASELINE.md`
- Read: `.git/HEAD`, `.git/config` names only, branch refs, `Package.swift`, working tree status

**Interfaces:**
- Consumes: approved cahier and current repository metadata.
- Produces: dated baseline section with branch, short/full HEAD, remotes by name only, local branches, tracked modifications, untracked path names, package target list, platform floor.

- [x] **Step 1: Record read-only Git state**

Run from `app/`:

```sh
git status --short --branch --untracked-files=all
git rev-parse HEAD
git branch --list
git remote
git log -1 --format='%H%n%cs%n%s'
```

Copy facts into `BASELINE.md`. Record only remote names; do not copy credentials embedded in remote URLs. Record worktree paths exactly as path names, no file contents.

- [x] **Step 2: Record package and product floors**

Read `Package.swift` and `Configuration/published-release.json`. Record Swift tools version, executable/library/test targets, declared macOS floor, architecture and release identifiers. Mark release JSON values **unverified** until linked to downloaded public artifact checksum evidence in Task 5.

- [x] **Step 3: Mark scope and limitations**

Add `Observed at (UTC)`, current branch/commit, status snapshot, measurement host/OS if available, and sentence: `This report describes this worktree only; branch names do not prove published content.` Do not record home directory or machine username.

- [x] **Step 4: Review report for private values**

Search `BASELINE.md` for `/Users/`, `@`, `token`, `secret`, `.p8`, `private key`, and inspect every match. Remove sensitive values while preserving the evidence type. Record untracked paths but not their contents.

### Task 2: Measure current automated project gates

**Files:**
- Modify: `Documentation/Reconstruction/BASELINE.md`
- Read: `DEVELOPMENT.md`, `Scripts/test.sh`, `Scripts/repository-doctor.sh`, `Scripts/build.sh`, site test and visual QA instructions

**Interfaces:**
- Consumes: Task 1 report.
- Produces: gate table with exact command, UTC timestamp, exit status, concise result, environment boundary and log location if output retained.

- [x] **Step 1: Inventory gate commands without running them**

Read `DEVELOPMENT.md`, `docs/PROJECT_METHOD.md`, `Documentation/TESTING.md`, `Documentation/VISUAL_QA.md`, and each script's usage. List only gates documented for this branch. Mark status `NOT RUN`.

- [x] **Step 2: Run required baseline build and test commands**

Run the exact project-mandated command sequence documented in `DEVELOPMENT.md` for release build and full Swift suite. Use `Scripts/test.sh` if repository instruction still identifies it as sole valid full-suite command. Record exit status and output counts exactly; do not repair failures in this programme.

- [x] **Step 3: Run non-mutating repository, localization and website checks**

Run documented repository doctor, localization check, and site test/build checks only if their documentation confirms they write to generated/gitignored output. Before a command that writes into tracked paths, inspect its output path and stop if it would overwrite reviewed assets. Record skipped gates and reason.

- [x] **Step 4: Record evidence without extrapolation**

For each run add UTC time, full command, exit code, exact summary, and whether result covers code, UI runtime, or packaging. Label old numbers in historical docs `HISTORICAL—NOT RE-MEASURED` in the new report only; do not edit historical source docs.

### Task 3: Reconcile app, package, feature and release claims

**Files:**
- Modify: `Documentation/Reconstruction/BASELINE.md`
- Read: `README.md`, `Package.swift`, `Documentation/FEATURE_MATRIX.md`, `Documentation/FEATURE_INVENTORY.md`, `Documentation/PROJECT_STATE.md`, `Documentation/CURRENT_PROJECT_STATE.json`, `Configuration/published-release.json`, `Documentation/GOLD_MASTER_STATUS.md`

**Interfaces:**
- Consumes: Tasks 1–2 evidence.
- Produces: claims table with claim, source, current direct evidence, status (`VERIFIED`, `CONTRADICTED`, `HISTORICAL`, `UNKNOWN`), and owner/action.

- [x] **Step 1: Build claims list**

Include minimum: release version/build, signature/notarization, OS/architecture, destination count, runtime dependencies, network behavior, safety behavior, locale count, test count, App Store status and site deployment status.

- [x] **Step 2: Check each claim against appropriate authority**

Use code and package for implementation facts, generated feature inventory for generated feature declarations, release artifact/checksum/signature evidence for public release facts, and maintainer-approved cahier for direction. Do not use a historical state JSON to override current code or release artifacts.

- [x] **Step 3: Write only evidence-backed rows**

For a claim without direct proof, write `UNKNOWN` and specify exact missing evidence. For two conflicting records, cite both and mark `CONTRADICTED` until authority is established. Do not edit either underlying version record in this task.

### Task 4: Map cahier requirements to implementation and proof

**Files:**
- Create: `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md`
- Read: approved cahier, `Package.swift`, `Sources/`, `Tests/`, `Scripts/`, `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md`, `Documentation/FEATURE_INVENTORY.md`

**Interfaces:**
- Consumes: cahier requirement IDs FR-01…FR-18 and NFR-01…NFR-14.
- Produces: one row per ID with current status, concrete source paths/symbols, test/gate or missing proof, risk and next programme.

- [x] **Step 1: Create the matrix header and controlled status vocabulary**

Use exactly these statuses: `VERIFIED`, `PARTIAL`, `IMPLEMENTED_UNVERIFIED`, `GAP`, `BLOCKED_DECISION`, `NOT_IN_SCOPE`. Each row carries `ID | Priority | Status | Current implementation | Evidence | Gap/next action | Programme`.

- [x] **Step 2: Map FR-01…FR-18**

For every FR ID, search current source and tests by module and feature symbols; include exact repository-relative paths and named test/gate only when found. A feature inventory status alone is supporting evidence, not runtime proof. Use `GAP` when no implementation exists and `IMPLEMENTED_UNVERIFIED` when code exists but no proof was found.

- [x] **Step 3: Map NFR-01…NFR-14**

Search SafetyCore, Persistence, network APIs, accessibility suites, localization gates, build scripts, manifests, website CSP and performance tests. Record evidence class (`static`, `unit`, `integration`, `runtime`, `visual`, `artifact`) for each cited proof.

- [x] **Step 4: Cross-check coverage**

Count listed IDs against cahier: 18 functional and 14 non-functional. Check duplicate/missing IDs with `rg -n '^\| (FR|NFR)-'`. Fix omissions before finishing. Do not claim requirement satisfied merely because prose says so.

### Task 5: Establish release evidence without publishing

**Files:**
- Modify: `Documentation/Reconstruction/BASELINE.md`
- Read: `Configuration/published-release.json`, `Documentation/RELEASE_STATE.md`, `Documentation/RELEASE_PROVENANCE.md`, existing local `Release/` manifest only if present, public GitHub release metadata only through configured read-only tooling already available

**Interfaces:**
- Consumes: Task 3 release claims.
- Produces: release facts table separating configured, locally built, remotely published, downloaded, hash-verified, signature-verified and notarization-verified states.

- [x] **Step 1: Inspect local release evidence presence**

Use `test -f` and read manifest metadata; do not mount/install anything. Do not output secrets, notarization credential names, private keys or local identity data. Mark absent artifact evidence as absent, not failed.

- [x] **Step 2: Inspect public release only if authenticated-safe read-only method exists**

If existing `gh` read-only access is configured, inspect release/tag metadata and asset names/checksums; do not download or execute assets in this phase. If unavailable, write `UNKNOWN—public asset not independently checked`; do not make a network workaround.

- [x] **Step 3: Separate channel decisions**

Mark direct distribution, Homebrew, App Store and site deployment with current evidence and decision owner. A branch or config file does not prove channel is live.

### Task 6: Create decisions register and link approved planning artifacts

**Files:**
- Create: `Documentation/Reconstruction/DECISIONS.md`
- Modify: `Documentation/README.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: open questions in cahier and contradictions found in Tasks 1–5.
- Produces: owner decision register and repository documentation navigation to cahier, roadmap and baseline evidence.

- [x] **Step 1: Create decision records**

For each open decision use fields `ID`, `Question`, `Why it matters`, `Options`, `Recommended default`, `Owner`, `Blocking programme`, `Status`. Include only decisions from cahier sections 5, 15 or evidence conflicts. Keep recommendation clearly marked as proposal; no decision is recorded approved without maintainer answer.

- [x] **Step 2: Add reconstruction links to documentation indexes**

Add one entry under `Documentation/README.md` for current measured baseline/traceability and one entry under `docs/README.md` for cahier and roadmap. Preserve existing historical audit links.

- [x] **Step 3: Validate links and source ownership**

Use a small Python standard-library script to check each new relative Markdown link resolves. Inspect `FEATURE_INVENTORY.md` generation header and existing traceability generation metadata; do not hand-edit generated files. If current traceability file is derived, leave it untouched and state relationship in the new index.

### Task 7: Programme 0 review and handoff

**Files:**
- Review: `Documentation/Reconstruction/BASELINE.md`
- Review: `Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md`
- Review: `Documentation/Reconstruction/DECISIONS.md`
- Review: both documentation indexes

**Interfaces:**
- Consumes: complete outputs from Tasks 1–6.
- Produces: maintainer-reviewable evidence pack; no product behavior change.

- [x] **Step 1: Check completeness and contradiction handling**

Confirm every non-unknown claim has direct evidence; every unknown has a next evidence action; all 32 cahier requirements appear once; all observed conflicts link both sources; every unresolved decision has owner and blocking programme.

- [x] **Step 2: Run documentation checks**

Run `git diff --check` and the documented documentation/link checker if it is read-only. Do not run broad tests again if Task 2 already recorded them and no code changed.

- [x] **Step 3: Present Programme 0 review**

Summarize contradictions, measurement results, blocking decisions and baseline confidence to maintainer. Do not start Programme 1 until baseline is accepted and safety/persistence decisions are resolved.

## Completion Criteria

- All six evidence artifacts/updates exist and pass link/format checks.
- Baseline measurements include exact current outputs or explicit skipped/unknown status.
- Requirement matrix includes all 32 requirement IDs and cites evidence without copying stale claims.
- Public release state remains unasserted unless independently evidenced.
- No product behavior, user data, release metadata, remote branch, tag or publication changed.

## Self-review

- **Spec coverage:** establishes truth source, full current feature map, engineering constraints, user data/release handling, decisions and review gate. Code reconstruction remains separated into next programme plans per roadmap.
- **Placeholder scan:** no TBD/TODO placeholders. Unknowns are explicit evidence states with concrete follow-up actions.
- **Type/interface consistency:** uses spec IDs `FR-01…FR-18`, `NFR-01…NFR-14`; 32 total. The same status vocabulary and four evidence-state labels are used consistently.
- **Scope:** programme 0 is documentation/evidence only; no independent engine or UI implementation mixed into this plan.
