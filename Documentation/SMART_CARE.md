# Smart Care

Smart Care is the one-click orchestrator: it runs a curated set of care
modules (defined in `SmartCareViewModel.initialModules()`,
`Sources/MacCareApp/SmartCareView.swift`) back-to-back and reports one
combined result, instead of you running each scan separately.

## Phases

`idle → running → review → executing → finished(freed:dryRun:)`

1. **Running** — each module scans in turn; the view shows per-module state
   (`ModuleState`) so you can see progress module by module.
2. **Review** — combined findings across modules, same review/select model
   as [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md).
3. **Executing** — applies the selected actions.
4. **Finished** — total bytes freed, and whether it was a dry run.

You can cancel a Smart Care run in progress (`cancel()`); already-scanned
modules keep their results.

## Dry-run

Smart Care respects the same dry-run setting as Cleanup — reviewed first,
nothing deleted until you confirm, and even then removal is Trash-based
(recoverable, see [RESTORE.md](RESTORE.md)).

## Relationship to Cleanup / Protection

Smart Care composes the same underlying engines as the standalone Cleanup
view; it does not duplicate logic. Protection (malware scanning) is a
separate, explicit flow — Smart Care does not run malware scans
automatically. See [PROTECTION.md](PROTECTION.md).
