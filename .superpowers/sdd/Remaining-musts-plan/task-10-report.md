# Task 10 report — read-only LaunchAgents review

## Changes

- Added `LaunchAgentInspector`, which accepts only an explicit directory URL, lazily enumerates direct children, skips symbolic links and non-regular/non-plist entries, caps retained plist candidate URLs at 501 (500 read plus one truncation sentinel), and reads at most 1 MiB plus one byte per plist to detect oversize files. It opens candidates with `O_NOFOLLOW` and verifies the opened descriptor is a regular file.
- Extracts only string `Label`, string `Program` (preferred), or the first string in `ProgramArguments`. Results retain the plist URL; malformed and read failures and candidate truncation are reported as issues.
- Added a separate folder picker and review-only configured-candidate list to Integrity. Security-scoped access remains held until the scan finishes. No standard folders are scanned implicitly and no mutation controls were added.
- Added EN/FR explanatory and issue copy, UserGuide details, and `integrity.loginitems` traceability as `PARTIEL` pending native UI and broader launch-service coverage.
- Added synthetic fixture coverage for both executable forms, malformed/oversized input, symlink and non-plist skipping, candidate cap, and fixture byte preservation.

## TDD evidence

- RED command: `swift test --filter LaunchAgentInspectionTests`
- RED result: compilation failed because `LaunchAgentInspector` did not yet exist (the expected missing production API); no scanner implementation had been written.
- GREEN command: `swift test --filter LaunchAgentInspectionTests`
- GREEN result: 4 tests passed, 0 failures.

## Verification

- `swift test --filter LaunchAgentInspectionTests` — passed; 4 tests, 0 failures.
- `swift test --filter AppShellTests` — passed; 11 tests, 0 failures, including English/French copy parity.
- `make qualify` — passed. This ran manifest generation, site checks, traceability, safety audit, temporary-HOME install smoke test, all Swift tests, and `CoreTendApp`/`CoreTendCLI` builds. DomainTests: 23 passed; AppShellTests: 11 passed; all package test suites passed.
- `git diff --check` — passed with no whitespace errors.
- No actual user HOME, system LaunchAgents directory, or login-item service was inspected. Native UI and service coverage remain unqualified.

## Scoped review fix round 1

Review found the manual qualification note in the CSV documentation column and an adversarial root-path replacement race: `O_NOFOLLOW` protects the plist leaf, but an absolute lookup could follow a replacement of the chosen folder path. The note now sits in the evidence column. `LaunchAgentInspector` opens and retains a descriptor for the user-chosen root, then uses `openat(rootFD, directChild, O_NOFOLLOW...)` and `fstat` to bind reads to that directory. Added a fixture test that renames the opened selected folder and replaces its old path with a symlink to an outside fixture; the reader still returns bytes from the original selected directory.

### Verification

- Red: `swift test --filter LaunchAgentInspectionTests` failed to compile on the expected missing `readPlistData` helper.
- Green: `swift test --filter LaunchAgentInspectionTests` passed 5 tests, 0 failures.
- `swift test --filter AppShellTests`: 11 tests, 0 failures.
- `make qualify`: exit 0; traceability, safety audit, temporary-HOME install smoke, all test groups and app/CLI builds passed.
- `git diff --check`: passed.

The reviewer noted candidate selection beyond 500 can depend on filesystem enumeration order; the scanner reports truncation and sorts the selected candidates for display. Task brief does not promise a deterministic subset when over limit.

Final re-review: both findings addressed, no new regression. `Documentation/UserGuide.md` is the only documentation-column value for the capability row; manual gates now occupy evidence. Root descriptor plus `openat` binds reads to the selected directory even if the chosen path is replaced. `integrity.loginitems` remains `PARTIEL`.
