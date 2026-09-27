# Threat model — local reconstruction

## Diagnostic export

The opt-in diagnostic contains only product/version, schema version, event counts by kind, and creation time. It omits event details, file names, paths, database contents, and secrets. Settings displays the exact generated JSON before presenting a user-chosen export destination. The current redaction test uses a synthetic path fixture; native export/cancel interaction and external privacy review remain outstanding.

## Network and telemetry

The runtime has no account, sync, or telemetry feature. The static safety audit rejects common Swift network-client APIs/framework imports and known analytics SDK references under `Sources/`. Application update URLs are displayed as declarations and opened by an explicit user action through a system link; CoreTend does not fetch a feed. The installed Release app was also observed with `lsof` at 14 points over an eight-second isolated idle run; no IPv4/IPv6 Internet socket was open. This samples open sockets rather than packets, does not exercise the explicit user-clicked update link, and can miss short-lived activity between samples or obfuscated/indirect networking.

## Assets

Files selected for inspection; local CoreTend events/preferences; paths and filenames; approved actions; user trust in size and integrity claims.

## Boundaries

The user explicitly supplies scan roots. ScanCore reads metadata and content only for exact duplicate hashes. ScanCore cannot call SafetyCore. UI cannot invoke filesystem mutation APIs. SafetyCore alone accepts opaque short-lived approvals and revalidates target path, root scope, volume and inode immediately before invoking macOS Trash. Production has no permanent-delete fallback. The CLI is read-only and requires explicit root/store paths. SQLite tests use temporary database URLs. A process-level test store override is accepted only when `CORETEND_TEST_MODE=1`, `CORETEND_TEST_STORE_DIR` points to an existing non-symlink directory below the real temporary root, and `HOME` equals `CFFIXED_USER_HOME` under that same root. Home and database directories cannot contain each other. Partial or invalid setup fails closed instead of falling back to a user store.

## Threats and controls

- Symlink/path traversal: reject symlink targets and an allowed root whose final component is a symlink; canonicalize root and candidate, compare device identity; skip symlinks during scans.
- Target substitution or expiry: inventory captures the app directory identity, review compares it and captures a fresh identity, approval and executor compare it again; changed/missing/expired target fails closed. Identity uses device and inode and does not detect in-place edits to bundle contents. Explore also captures the selected root identity and checks it before review and immediately before Trash. Exact-duplicate reviews capture each group's suggested keeper identity and revalidate it before every selected copy moves; if a keeper disappears during a batch, remaining moves fail closed. These path checks are not atomic with `FileManager.trashItem`; a narrow concurrent path-replacement race remains and hostile race stress testing is outstanding.
- Trash API failure: preserve source, return typed failure; never report successful removal.
- Scan races/permission failures: report item-level issue; unknown measurement remains unknown.
- Accidental private-data exposure: no telemetry/network by default; an app-declared HTTPS feed can open in the browser only after a user clicks its link. The feed belongs to the inspected app and is not verified as trustworthy. CLI warns paths may be sensitive.
- Test damage to user data: fixtures under per-test temporary directories; fake Trash exists only in test target; static audit bans mutation APIs in production except `trashItem`.
- Runtime fixture isolation: when either `CORETEND_TEST_MODE` or `CORETEND_TEST_STORE_DIR` is present, app preferences bypass `UserDefaults.standard`; tests can supply only explicit `CORETEND_TEST_*` values. Fixture preference writes are no-ops.
- Misleading product claims: unreleased status on site; evidence-gated traceability; no antivirus or reclaimed-space claims.

## Residual work

Cleanup, Duplicates and app-bundle actions use SafetyCore, but their native UI flows remain unqualified. App associated data and legacy data are not moved; provenance attribution and update source coverage remain incomplete. No independent security review or hostile race stress test has run; macOS 14 was declared as minimum but this host reports a newer SDK and no older host was tested. These gaps block qualification claims.
