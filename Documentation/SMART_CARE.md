# Smart Care

Smart Care is the one-click orchestrator: it runs a curated set of care
modules (defined in `SmartCareViewModel.initialModules()`,
`Sources/CoreTendApp/SmartCareView.swift`) back-to-back and reports one
combined result, instead of you running each scan separately.

## Phases

`idle → running → review → executing → finished(freed:)`

1. **Running** — each module scans in turn; the view shows per-module state
   (`ModuleState`) so you can see progress module by module.
2. **Review** — combined findings across modules, same review/select model
   as [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md).
3. **Executing** — after explicit confirmation, moves the selected eligible
   items to the Trash.
4. **Finished** — total bytes actually moved by the completed action.

You can cancel a Smart Care run in progress (`cancel()`); already-scanned
modules keep their results.

Smart Care uses the same safety path as Cleanup: review first, explicit
confirmation, and Trash-based removal (recoverable; see
[RESTORE.md](RESTORE.md)).

## Relationship to Cleanup / Protection

Smart Care composes the same underlying engines as the standalone Cleanup
view; it does not duplicate logic. Protection (malware scanning) is a
separate, explicit flow — Smart Care does not run malware scans
automatically. See [PROTECTION.md](PROTECTION.md).
