# Workspace Rollback Plan

Companion to `WORKSPACE_MIGRATION_PLAN.md`. Every phase of that plan has a
corresponding rollback here — written before any migration executes, per
this phase's explicit requirement that a rollback strategy exist ahead of
any destructive future step.

## Rollback by phase

**After Phase B (backup created)**
- Nothing to roll back — backups are additive (new files in a new
  location), source repos are untouched. Delete the backup bundle/tarball
  if it's no longer wanted; this has zero effect on either repo.

**After Phase C (dry-run validation)**
- Nothing to roll back — dry-run restores happen in a scratch directory
  (`mktemp -d`), which is discarded after validation. Source repos and
  real backups are untouched.

**After Phase D (actual move), before Phase E confirms**
- **Git-tracked content**: since each repo's `.git` directory moves with
  it (never re-cloned), rolling back is `mv <destination> <source>` — the
  full commit history travels with the move in both directions, nothing
  is reconstructed from a bundle unless the live directory itself was
  somehow lost (in which case restore from the Phase B git bundle:
  `git clone <bundle-file> <source-path>`).
- **Untracked local files** (`.env.local`, `.vercel/`,
  `Configuration/PublicIdentity.local.json`): restore from the Phase B
  tarball backup into the restored source path.
- **Vercel project linkage**: if `vercel link` was re-run against the new
  path, either re-run it again pointed at the restored old path, or
  restore the pre-move `.vercel/project.json` from the Phase B backup —
  document which was actually done at rollback time, don't assume.

**After Phase E (cutover confirmed working)**
- Rollback is still possible via the same steps as Phase D, as long as
  the old location was not yet deleted (per this plan, it never is
  automatically — see `WORKSPACE_MIGRATION_PLAN.md`'s Phase E). If a
  human explicitly deleted the old location after confirming Phase E,
  rollback falls back to the Phase B git bundle + tarball restore.

## What must exist before Phase D is allowed to start

`Scripts/check-workspace-migration-readiness.sh` enforces this list
mechanically (see Section 14): both repos identified with clean trees,
remotes recorded, backups present and checksummed, sufficient disk space
at the destination, no other worktree/process holding either repo open,
target structure resolved (workspace parent + product slug both known,
not `BLOCKED_HUMAN`), a rollback plan on file (this document), and human
approval recorded.

## What this plan does NOT cover

- Recovering from a *partial* Phase D failure (e.g. the process is killed
  mid-`mv`) is not separately scripted this phase — `mv` on the same
  volume is atomic per top-level item in the manifest (one `mv` per
  manifest entry, not a recursive multi-step copy-then-delete), so a kill
  mid-flight leaves each individual item either fully moved or fully
  un-moved, never half-written. Cross-volume moves (if `<WORKSPACE_PARENT>`
  ends up on a different volume than `~/Documents`) do **not** have this
  atomicity guarantee and would need a copy-verify-then-delete-source
  sequence instead — flagged here as a design decision to make explicitly
  when `<WORKSPACE_PARENT>` is finally chosen, not decided in advance.
