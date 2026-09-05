<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Launch Items Manager readiness — analysis only

No Launch Items Manager implementation or live launch-state mutation was performed.
Repository and installed Apple SDK/manual evidence support the following scope.

## Existing foundation

`LoginItemScanner` in `Sources/IntegrityCore/IntegrityCore.swift` reads
`~/Library/LaunchAgents`, `/Library/LaunchAgents`, and `/Library/LaunchDaemons`.
It reports label, executable, plist path, and user/global-agent/global-daemon scope.
It does not report loaded/running/disabled state, effective overrides, consent,
ownership, executable identity, or rollback. A plist on disk does not prove enabled.
Malformed/inaccessible inputs become omissions; a manager must distinguish
inaccessible inventory from an empty inventory. Symlinked plists are accepted for
inspection, which must not become mutation authorization.

`PerformanceView.swift` has a separate user-agent missing-executable inspector.
`ApplicationInspection.swift` provides `LaunchItemAssociator`; executable-prefix
and label associations provide context/confidence, never permission to mutate.
Consolidate these read-only inventories first. Modern System Settings background
items are not exhaustively enumerated by this legacy-plist scanner.

## Native APIs and authority

No `ServiceManagement`/`SMAppService` implementation currently exists in Sources.
The installed `ServiceManagement.framework/Headers/SMAppService.h` establishes:

- `SMAppService.mainApp` manages CoreTend's own launch-at-login setting.
- Login-item, agent, and daemon constructors refer to helpers/plists in the
  calling app's bundle. They are not universal third-party service switches.
- Signing is required; daemon approval and distribution prerequisites must be
  satisfied before claiming operational support. No privileged helper is present.

The installed `launchctl(1)` distinguishes persistent loading eligibility
(`enable`/`disable`) from loaded service definitions (`bootstrap`/`bootout`).
Own-user GUI/user-domain changes are candidates only after checking identity,
permissions, domain, and supported-macOS behavior. A first mutation vertical should
prevent future launch, not stop running processes. System-domain operations require
root; other users, managed/protected services, and system daemons stay read-only.
Global LaunchAgents can load into a GUI domain, but global installation scope still
stays read-only in v1. No automatic privilege escalation or shell command strings.

## Mutation and rollback model

Do not reuse `SafetyCenter.execute`: it approves Trash operations and records
Trash restore manifests. Launch eligibility needs a dedicated typed validator and
executor. Reuse explicit review/confirmation, execution-time revalidation, audit
correlation, and truthful risk vocabulary.

Before mutation, durably record domain/label, canonical plist identity and owner,
content hash, prior effective override, requested state, operation ID, and time.
Use a bounded injected process runner with fixed argument arrays, not a shell.
Revalidate before execution; inspect postconditions afterward. Nonzero exit,
permission denial, timeout, and unknown/partial outcomes need distinct records.

Undo requires unchanged identity and matching recorded postcondition. Do not
silently overwrite intervening vendor/user changes. Prior “no override” differs
from explicit enabled state: establish exact supported restoration before promising
full rollback. Otherwise offer truthful “re-enable” with that limitation. Existing
Trash `RestoreManifest` cannot express this state change.

## Provenance and journal

Reuse `CodeSignInspector` on the selected executable/app, lazily. Signed does not
mean safe; unsigned does not mean malicious. A shell/interpreter signature does not
establish script payload trust. `ProvenanceScanner` currently scans a folder's
quarantine metadata; extract a narrow per-item reader if needed instead of scanning
an unrelated directory for one launch item.

`Persistence.Store` activity kinds currently cover scan, cleanup, restore, error.
Add a dedicated launch-state kind with result/correlation semantics; update filters,
localization, migrations/tests as needed. Disabling a service frees no proven bytes
and must not be reported as cleanup. Keep sensitive paths out of generic exports.

## Test strategy and safe first vertical

Use synthetic plists for ownership, scope, duplicate/malformed labels, relative
executables, symlink swaps, stale identities, and inaccessible locations. Inject
state reader and runner; assert exact argument arrays/domain, no escalation, and no
mutation of global/system items. Cover timeouts, nonzero exit, permission denial,
postcondition mismatch, crash recovery, rollback conflicts, missing/invalid
signatures, interpreter payloads, and journal/localization parity. Real launchd
smoke tests require an opt-in disposable synthetic agent, never personal services.

Safe first vertical: unified read-only launch inventory with truthful state and
coverage, executable signing/provenance, app association, and System Settings
instructions. An optional CoreTend-only launch-at-login switch via
`SMAppService.mainApp` can be scoped separately. The next mutation vertical may
manage explicitly selected, owned per-user legacy agents' future-launch eligibility
with a dedicated validator and durable journal. No universal third-party toggle.
