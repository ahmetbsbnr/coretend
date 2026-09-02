# Smart Care — retired

Smart Care was a one-click orchestrator that ran the care modules back to back
and reported one combined result. It has been **superseded by the Dashboard**.

The `ModuleID.smartCare` case is kept (its `"Smart Care"` raw value is a stable
identity matched by `sidebar.<rawValue>` accessibility ids and activity-summary
prefixes), but it renders `DashboardView` and its label is `module.dashboard`.
The standalone `SmartCareView` and its view model were removed.

The one piece worth keeping — the safety filter that decided which findings an
automated flow may act on without a per-item review (reversible, low-risk,
preselected only) — now lives as `UserCleanupRules.autoExecutable(_:)` in
`Sources/FileRules/UserCleanupRules.swift`, guarded by
`Tests/CoreTendAppTests/CleanupAutoExecuteTests.swift`.

Cleanup remains the reviewed, explicit-confirmation cleanup flow — see
[CLEANUP_GUIDE.md](CLEANUP_GUIDE.md).
