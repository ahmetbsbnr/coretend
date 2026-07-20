# ScanCore

`Sources/ScanCore/` (depends on `SafetyCore`). Everything that finds
candidate files; nothing in this module deletes anything — rules only
*find*, per the doc comment on `ScanRule`.

## `ScanFinding`

One flagged file: path, logical/allocated size, modification date, which
`ruleID`/`category` matched, a human-readable `explanation` (surfaced in
the UI so users see *why* something was flagged — never a bare path),
`confidence`, `risk` (`SafetyCore.RiskLevel`), and whether it's
`preselected` in the review UI.

## `ScanEvent` (streamed via `AsyncStream`)

`started → progress(scanned:currentPath:) → finding(_:)* → finished(scanned:totalBytes:)`,
with `error(path:message:)` for per-file failures (skip, don't abort the
whole scan) and `cancelled` when the consumer stops draining the stream —
cancellation is cooperative via stream termination, not a cancel flag
polled mid-walk.

## `ScanRule`

Declarative: `roots: (home) -> [URL]` (candidate directories), an optional
per-file `matches` predicate, `minimumAgeDays`, `minimumSizeBytes`, `risk`,
`preselect`. Built-in rules live in `Sources/FileRules/` (depends on
`ScanCore` + `SafetyCore`) — each rule is tested against its matching
deletion allowlist to keep them in sync (see [TESTING.md](TESTING.md)).

## `ScanEngine`

Walks directories synchronously inside a detached utility-priority task and
emits `ScanEvent`s. Large result sets are not capped at the engine level —
everything found is streamed and totaled; only the on-screen list in
MacCareApp truncates rendering (see `Documentation/CHANGELOG.md`, the
totals-fix entry, and `engineStreamsAllFindingsUncappedAt5001` in
`MacCareAppTests`).

## Other ScanCore-adjacent engines

`SpaceLensEngine` (directory-tree sizing/bucketing), `DuplicateEngine`
(exact-duplicate detection, prefers the shallowest path as "keeper"),
`SimilarImagesEngine` (near-duplicate images) — all consume `ScanRule`/the
same finding shape and go through `SafetyCore` for anything destructive.
