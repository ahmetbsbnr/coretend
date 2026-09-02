# SafetyCore

`Sources/SafetyCore/SafetyCore.swift`. Every destructive engine must go
through this — it is the only place that decides a path is safe to touch.

## `PathValidator` (Sendable struct)

`validate(_:) throws(SafetyError) -> URL`:

1. Rejects empty/relative paths.
2. Rejects `/` itself and every hard-coded `protectedRoots` entry
   (`/System`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/usr/lib`,
   `/usr/libexec`, `/usr/share`, `/private/var/db`, `/Library/Apple`,
   `/Volumes/Recovery`) — prefix-matched on path-component boundaries
   (`isPath(_:under:)`, so `/a/bc` does not match root `/a/b`).
3. Rejects the user's home directory itself (never auto-select `~`
   wholesale).
4. Requires the path to be under one of the caller-supplied `allowedRoots`.
5. Resolves symlinks and re-checks the resolved target against
   `allowedRoots` — defends against a symlink swapped in after the initial
   check (`SafetyError.symlinkTraversal`).

`userContentRoots(home:)` lists Documents/Desktop/Pictures/Music/Movies —
callers use this to keep those roots out of auto-selected allowlists (not
enforced inside `validate` itself, so callers must pass the right
`allowedRoots`).

## `RiskLevel`

`low < medium < high` (`Comparable`). Every `ApprovedFileOperation` carries
one; UI surfaces it so users can judge what they're removing.

## `ApprovedFileOperation`

The only type deletion engines accept — never a raw `URL` from the UI
layer. Produced exclusively by `SafetyCenter`, so there is no code path
that deletes an unvalidated path.

## `SafetyCenter` (actor)

Central approve + execute point. Re-validates a path immediately before
acting (not just at review time — the filesystem may have changed). It emits
structured approved/executed/skipped/error events through `SafetyAuditSink`.
Only produces `.moveToTrash` operations — CoreTend's engines never call a
permanent-delete API directly; see
[RESTORE.md](RESTORE.md).

## Extending

New destructive functionality must: accept only `ApprovedFileOperation`
(or go through `SafetyCenter`/`PathValidator` directly), never take a raw
path from a view model, and add a test proving protected roots/symlink
escapes are rejected — see [TESTING.md](TESTING.md).
