<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Permission handling

Everything permission-related in CoreTend derives from one object:
`Sources/CoreTendApp/PermissionCoordinator.swift`. Settings, Deep Scan,
Onboarding and the diagnostic report all read it, so they cannot disagree.

## The bug this replaced (v1.2.0-beta.1 blocker)

Symptom: grant Full Disk Access → it works → quit → reopen → Settings shows
the permission as not granted → pressing "Re-check" doesn't fix it.

Root cause:

- **Fragile single-signal probe.** `PermissionProbe.hasFullDiskAccess()` tried
  to list only `~/Library/Safari` and `~/Library/Mail`. On a Mac without Apple
  Mail that is effectively one signal, and a single transient `nil` from
  `contentsOfDirectory` (Safari holding the directory, or `tccd` not having
  associated a just-launched process yet) made the whole check return `false`.
- **Probed once, never automatically re-probed.** The value was computed at
  view-model `init` — the earliest, worst moment in a cold launch — and only
  re-run when the user pressed "Re-check", which ran the *same* fragile probe.
- **Two divergent probes.** Deep Scan had its own `DeepScanPermissionProbe`
  with a different path list, so Settings and Deep Scan could show different
  states.
- **"missing" read as "denied".** A genuinely-granted Mac whose probe paths
  didn't exist was reported as denied.

No persisted "unverified" flag was involved — the state was purely in memory
and re-derived each time.

## The fix

### `FullDiskAccessProbe` — multi-signal, read-only

Tries to *list* (never read the contents of) **eight** independent TCC-gated
directories, including `/Library/Application Support/com.apple.TCC`, which
exists on every Mac and is gated by Full Disk Access. Aggregation:

| Observation | Result |
|---|---|
| ≥1 readable, 0 permission-denied | `granted` |
| ≥1 readable **and** ≥1 permission-denied | `partial` |
| 0 readable, ≥1 permission-denied | `denied` |
| no probe target present at all | `unavailable` (never `denied`) |
| only non-EPERM errors | `error` |

A permission-denied result is `EPERM`/`EACCES` specifically; any other error is
a probe error, not a denial. One 150 ms retry absorbs the cold-process `tccd`
race.

### `PermissionCoordinator`

- `@MainActor @Observable` singleton.
- Explicit 8-state `PermissionState`:
  `checking / granted / partial / denied / notRequested / needsReauthorization
  / unavailable / error`.
- **Automatic refresh** (debounced, 400 ms, coalesced) on: app launch,
  `NSApplication.didBecomeActive` (covers relaunch **and** return from System
  Settings), Settings appearing, and before every Deep Scan. The healthy
  relaunch flow is `Checking… → Granted` with no button press.
- **Persists diagnostics only** — `lastCheckedAt`, `lastSuccessfulCheckAt`,
  `lastKnownState`, `lastFailureReason`. A fresh probe always wins; the
  persisted values are shown only in the diagnostics text.
- **Legacy keys retired.** Any old `fdaVerified` / `hasFullDiskAccess` /
  `permissionsUnverified` / `folderAccessVerified` / `permissionChecked`
  UserDefaults keys are deleted on launch and never read.
- A **transient probe error** after a known-good state keeps the good state on
  screen and surfaces the reason — it does not flip to `Error`. A genuine
  **denial** always flips the state (a stale `Granted` never survives a real
  `denied` probe).

### Settings — Permissions Center

`PermissionsSection` in `SettingsView.swift`: a health summary line, the Full
Disk Access state (all eight, never a generic "Unverified"), "Last checked" /
"Last successfully verified" relative timestamps, **Check Again** /
**Open System Settings** / **Relaunch CoreTend**, a separate Notifications row,
and **Copy Diagnostics**. English + French (`perm.*` keys, parity-tested).

## Bookmarks

CoreTend does **not** currently persist any security-scoped bookmark. Deep
Scan scans `~` by default; the "Scan a specific folder…" override is held in
memory for the session only; Settings exclusions store plain paths. The
coordinator carries a `needsReauthorization` state for when a persisted
bookmark subsystem is added, but there is nothing to reauthorize today.

## Verification

- `Tests/CoreTendAppTests/PermissionCoordinatorTests.swift` — probe state
  machine, fresh-probe-wins-over-persisted, 5× relaunch stays `Granted`,
  transient error doesn't clobber, legacy-key retirement, revoke-while-open,
  debounce coalescing, Settings/DeepScan consistency, `perm.*` localization
  parity.
- `Scripts/test-permission-relaunch.sh` — runs the real probe in **five fresh
  processes** plus a rebuild; requires identical state each time. PASSED
  (5/5 identical, rebuild-stable).
- **HUMAN VERIFICATION REQUIRED**: the interactive Settings screen on the
  packaged app across a real grant → quit → reopen cycle, and the
  return-from-System-Settings refresh.
