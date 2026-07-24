# Workspace Migration Plan

Planning document only. No move has been executed. See
`WORKSPACE_TARGET_STRUCTURE.md` for the destination shape and
`workspace-migration-manifest.json` for the per-item move list this plan
walks through.

## Phased approach

**Phase A — Preflight (this phase, 0.8.1A)**
- Inventory both repos (done: `PRE_REBRAND_BASELINE.md`,
  `PORTFOLIO_REPOSITORY_INVENTORY.md`).
- Document target structure (done: `WORKSPACE_TARGET_STRUCTURE.md`).
- Build non-destructive readiness/backup tooling (this phase:
  `Scripts/preflight-workspace-migration.sh`,
  `Scripts/check-workspace-migration-readiness.sh`).
- **No files move in Phase A.**

**Phase B — Backup (future, requires explicit `--create-backups` flag)**
- Git bundle of both repos (full history, portable, restorable without a
  network remote).
- Tarball of untracked-but-needed local files (`.env.local`,
  `.vercel/`, `Configuration/PublicIdentity.local.json` if it exists by
  then) into a separate, clearly-labeled, gitignored backup location —
  never into a location that could accidentally get committed or zipped
  into an audit package.
- Checksums of both bundles recorded.

**Phase C — Dry-run validation (future)**
- Restore each backup bundle into a scratch directory (e.g. under
  `mktemp -d`) and confirm: `git log` matches, `swift build`/`npm run
  build` succeed, tests pass, from the restored copy — proving the backup
  is actually usable before anything real moves.

**Phase D — Actual move (future, requires human go-ahead)**
- Execute the manifest in `workspace-migration-manifest.json`, one item
  at a time, verifying each item's postconditions before starting the
  next.
- Old locations stay in place, untouched, until every item's
  postconditions pass.

**Phase E — Cutover confirmation (future)**
- Re-run the full test/build/deploy-dry-run suite from the new locations.
- Update any local shell aliases / editor workspace files / CI config
  that referenced the old paths (out of scope for an automated script —
  these are personal environment files, listed for the human to update).
- Only after Phase E passes: consider removing the old locations — and
  even then, per this phase's explicit constraint, no deletion happens
  automatically or without a separate, explicit confirmation step.

## What triggers moving from one phase to the next

- A → B: human decides to proceed with backups (`--create-backups` flag
  is opt-in by design, per Section 13's script constraints).
- B → C: backup checksums recorded and match.
- C → D: dry-run restore proves both repos build/test clean from a
  restored copy, **and** `<WORKSPACE_PARENT>` and (for the product repo)
  `<approved-product-slug>` are both resolved (no longer `BLOCKED_HUMAN`).
- D → E: every manifest item's postconditions pass.

## Non-negotiables carried from the phase brief

- No folder deleted, ever, in this plan's automated tooling.
- No repository renamed.
- No bundle identifier changed as part of this migration (that is a
  separate, later concern gated on brand clearance, tracked in
  `PRODUCT_RENAME_PLAN.md`).
- No domain changed.
- Rollback is possible at every phase boundary — see
  `WORKSPACE_ROLLBACK_PLAN.md`.
