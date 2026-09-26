# CoreTend — Analysis capabilities design

> Status: approved direction; maintainer review required before implementation planning.
> Date: 2026-09-26. Scope: Programme 2 of the reconstruction roadmap.

## Goal

Make scan, duplicate, space, application, integrity, and system-metrics capabilities predictable to call, honest about incomplete evidence, cancellable, and bounded in resource use. Preserve existing product behavior where it meets the accepted reconstruction requirements; replace contracts incrementally.

## Current state

- `ScanCore` exposes `ScanEngine.run` as an unbounded `AsyncStream<ScanEvent>`. It has bounded concurrent rule tasks, but filesystem metadata failures are streamed as strings and root enumeration failures can look like empty results. The comment claiming stream backpressure is inaccurate for the default unbounded buffer.
- `DuplicateEngine` independently inventories files before hashing. It skips symlinks and remote-only iCloud placeholders, collapses hard links, but suppresses inventory and hash read errors. Its size buckets and inode set grow with the scanned tree. Hash reads use a fixed chunk, but cancellation is only checked between files, not inside a large-file hash.
- `SimilarImagesEngine` has a separate image inventory and image decoding path. Its inputs and costs differ from duplicate detection; share traversal only where exact semantics match.
- `SpaceLensEngine` builds a recursive result tree, silently skips metadata failures, and treats a failed directory listing as an empty directory with `isAccessDenied`. Its tree and traversal work have no explicit budget. It distinguishes cloud placeholders only on leaf nodes.
- `AppDiscovery` and `IntegrityCore` expose mostly synchronous arrays and suppress many filesystem errors. `AppDiscovery` computes directory sizes with separate walks. Integrity uses native metadata/signature signals and has fixture-injected paths in tests.
- `SystemMetrics` provides local live snapshots. Keep it independent from file traversal and label timestamps/source with each measurement.
- Current consumers are mostly in `CoreTendApp`; preserve them through adapters during migration. Existing fixture tests use temporary roots and should remain isolated from real user paths.

## Requirements and invariants

1. Every analysis API is read-only. It must not call file move, delete, or mutation APIs.
2. A caller can distinguish complete, partial, cancelled, and failed work. Cancellation cannot be reported as success.
3. A skipped or unreadable item is represented by a typed issue with a stable category and safe user-facing context; errors must not silently become an empty successful result.
4. Measurements carry provenance and units. Logical size, allocated local bytes, unavailable size, and remote-only placeholder remain distinguishable. Never count a remote logical size as local bytes.
5. Traversal and hashing never follow symlinks. Remote-only cloud files are never hydrated for analysis.
6. Resource limits are explicit and testable: concurrent work, retained findings/nodes, traversal depth or item budget where applicable, and hash chunk size. Reaching a limit produces an incomplete/limited outcome.
7. Integrity remains read-only and uses only native, directly observed macOS signals. No malware verdict or guessed security state.
8. Do not consolidate scans merely because they traverse files. Shared traversal is allowed only when root handling, exclusions, symlink policy, package policy, cloud policy, error semantics, and cancellation semantics are equivalent.
9. No runtime dependency is added. Keep macOS 14+ arm64 as initial target.

## Proposed architecture

### Contracts

Define shared value types in `ScanCore` for analysis status, typed issue category, measurement provenance, and bounded-run policy. Keep capability-specific events and result models where their semantics differ. Progress is advisory and may be coalesced; findings and terminal state must never be silently dropped. A result records its scan time, scope, measurements, issues, and terminal status so later UI and persistence do not have to infer provenance.

The first implementation plan must settle concrete Swift signatures after tracing all consumers. Prefer a small typed result/report plus a cancellable producer over one universal stream abstraction. Keep compatibility adapters until each caller migrates; do not make a broad source-breaking rename.

### File inventory and duplicate semantics

Add a reusable read-only inventory primitive only for policies that are demonstrably identical. It must accept injected roots, exclusions, and bounded traversal policy; expose typed enumeration/read issues; skip symlinks and remote-only placeholders; and honor cancellation during traversal. Duplicate detection consumes inventory candidates and hashes them in bounded chunks, checking cancellation between chunks. Hash/open/read failures become per-item issues and cannot create a duplicate group.

Similar-image analysis remains separate unless a later comparison proves identical inventory semantics. Its image decoding and Vision work remain capability-specific. Do not merge duplicate and image result models.

### Space analysis

Space results retain separate logical and allocated byte facts where available. Cloud placeholders carry explicit remote-only/local-bytes-unknown state. A failed subtree is marked incomplete and contributes no invented zero-valued certainty. Traversal depth, item count, and retained tree size are capped by policy; truncation is visible in the report. Directory aggregation states whether total is complete or a lower bound.

### Applications and integrity

Application discovery and associated-item sizing gain typed per-bundle/per-root issues, cancellation checks, and bounded traversal. Existing exact bundle-ID matching and native provenance rules stay intact. Update mechanism detection remains local-only and does not imply an update exists.

Integrity scanners return structured completion and issue information around existing observations. Keep code-sign inspection native through Security APIs; preserve unknown/unreadable as unknown, never as a clean verdict. Login item and download provenance scans remain read-only and use injected fixture roots in tests.

### System metrics

Keep metrics snapshot collection independent from disk engines. Each sample includes timestamp and measurement source; unavailable fields stay unavailable rather than receiving defaults that imply healthy/zero state. No new sampling loop or persistence behavior is introduced in Programme 2.

## Error and cancellation behavior

- Cancellation is cooperative during enumeration, between files, and inside chunked file reads. Each capability emits one terminal cancelled state and no later success terminal state.
- A root that cannot be opened is a root-level issue. A child metadata/read failure is an item-level issue. Other roots/items continue when safe.
- Reports with any issue or resource-limit truncation are partial, unless caller cancellation determines cancelled status. An unrecoverable setup failure is failed.
- Error descriptions shown to users are localized at the UI boundary. Core modules expose stable issue codes and path references only to local callers; diagnostic exports must apply existing redaction rules.
- Permission denial, missing path, unsupported item, and transient I/O failure remain separate issue categories where the platform exposes that distinction.

## Resource policy

Use explicit policy values with conservative defaults, test injection, and documented units. Preserve current bounded rule concurrency and hash chunking while making them observable and cancellation-aware. Establish default item/result caps from fixture/stress measurements on supported hardware; do not invent performance budgets in this design. A policy limit must stop or truncate work predictably and appear in the terminal report. UI consumers must not accumulate an unbounded event backlog; progress can be coalesced, while findings are bounded by the report policy and cannot be dropped invisibly.

## Migration and consumers

Migrate in capability slices: shared types/inventory; scan and duplicate; space; application discovery; integrity; metrics provenance; then UI adapters. Keep existing public entry points as thin adapters until all call sites use typed contracts. Compare fixture outputs before switching each consumer. Do not migrate persistence schema or UI navigation in this programme.

## Verification

- Fixture trees cover readable/unreadable roots, partial child failure, symlink loops/out-of-root links, hard links, changing files, duplicate content, cloud placeholders without hydration, package traversal, exclusions, empty roots, and limit truncation.
- Deterministic cancellation tests cover traversal and a large file hash; terminal status must be cancelled and no success terminal event may follow.
- Resource tests assert configured bounds on concurrency, retained results, node/depth limits, and fixed-size hash reads.
- Measurement tests verify logical vs allocated values and unknown/placeholder provenance without asserting filesystem-specific byte allocation beyond controlled fixtures.
- Integrity tests verify native-signal classification and preserve unknown/error state without security verdict inflation.
- Application tests use injected temporary roots only; no real home Library or `/Applications` access in tests.
- Run targeted tests per slice, release build, full available Swift suite, repository doctor, localization parity, and copy-honesty gate. Record toolchain limitations honestly.

## Non-goals

- New UI design, destination navigation, or persistence-schema migration.
- Network lookup, telemetry, analytics, cloud hydration, malware detection, or destructive file operation.
- One universal engine or forced consolidation of semantically different traversals.
- Fixed performance targets before reproducible baseline measurements.
- New runtime dependency.

## Exit criteria

Every capability has a typed completion/error/cancellation contract, fixture evidence for partial failure and bounded behavior, explicit measurement provenance, and no hidden conversion of an error into a complete empty result. All migrated UI consumers preserve user-visible scope and distinguish partial/unknown results. Read-only, symlink, cloud, and Integrity invariants remain covered by tests.
