# Threat model — local reconstruction

## Assets

Files selected for inspection; local CoreTend events/preferences; paths and filenames; approved actions; user trust in size and integrity claims.

## Boundaries

The user explicitly supplies scan roots. ScanCore reads metadata and content only for exact duplicate hashes. ScanCore cannot call SafetyCore. UI cannot invoke filesystem mutation APIs. SafetyCore alone accepts opaque short-lived approvals and revalidates target path, root scope, volume and inode immediately before invoking macOS Trash. Production has no permanent-delete fallback. The CLI is read-only and requires explicit root/store paths. SQLite tests use temporary database URLs.

## Threats and controls

- Symlink/path traversal: reject symlink targets, canonicalize root and candidate, compare device identity; skip symlinks during scans.
- Target substitution or expiry: short-lived approval and identity revalidation; changed/missing/expired target fails closed.
- Trash API failure: preserve source, return typed failure; never report successful removal.
- Scan races/permission failures: report item-level issue; unknown measurement remains unknown.
- Accidental private-data exposure: no telemetry/network by default; diagnostic export not enabled until preview/redaction review exists; CLI warns paths may be sensitive.
- Test damage to user data: fixtures under per-test temporary directories; fake Trash exists only in test target; static audit bans mutation APIs in production except `trashItem`.
- Misleading product claims: unreleased status on site; evidence-gated traceability; no antivirus or reclaimed-space claims.

## Residual work

The current native action UI is not connected to SafetyCore; legacy migration UI and exports are incomplete; no independent security review or hostile race stress test has run; macOS 14 was declared as minimum but this host reports a newer SDK and no older host was tested. These gaps block qualification claims.
