# Test Inventory — Audit Session 1

Evidence: `bash Scripts/test.sh` run on 2026-07-20 at commit `b33c06b8d68b9b03316821c3f6cfb17252f35011`.
Result: **86 tests in 27 suites, all passed, 0.938s** (test-run time; ~2.1s wall including toolchain
startup). Full raw output captured in `Documentation/AUDIT_COMMANDS.log`.

Suite/test names and "what it verifies" below were read directly from the `@Test`/`@Suite` declarations
and surrounding assertions in each file (file:line references given), not guessed from names alone.

## Domain breakdown

| Domain (module) | Tests | Passed | Failed | Not-runnable | Gaps observed |
|---|---|---|---|---|---|
| SafetyCore (PathValidator) | 13 | 13 | 0 | 0 | none obvious |
| ScanCore (ScanEngine, DuplicateEngine, SpaceLens, SimilarImages, root isolation, display cap) | 21 | 21 | 0 | 0 | none obvious |
| FileRules (UserCleanupRules) | 3 | 3 | 0 | 0 | none obvious |
| DesignSystem (tokens, geometry, colors, brand resources) | ~9 | 9 | 0 | 0 | none obvious |
| Persistence (Store) | 5 | 5 | 0 | 0 | none obvious |
| AppDiscovery | 3 | 3 | 0 | 0 | none obvious |
| SystemMetrics | 1 | 1 | 0 | 0 | thin — 1 test for a whole snapshot collector |
| MalwareEngine (ClamAV parsing, Quarantine) | 4 | 4 | 0 | 0 | no test found for the actual `Process()` clamscan invocation path (Sources/MalwareEngine/MalwareEngine.swift:56) — only output parsing and quarantine round-trip are covered |
| MacCareApp (AppGrouping, DiagnosticReport redaction, Leftovers ambiguity, MyActivity grouping, Cloud sync state, menu-bar attention, permission formatting) | ~27 | 27 | 0 | 0 | none obvious |
| **Total (Swift Testing)** | **86** | **86** | **0** | **0** | — |

## Shell-level test scripts (outside `swift test`)

| Script | Destructive? | Result this session | Notes |
|---|---|---|---|
| `Scripts/test-uninstall.sh` | No — uses a fake `$HOME` via `mktemp -d` | **PASS** 4/4 assertions | Verifies dry-run deletes nothing, `--remove-all` removes only allowlisted paths, `--keep-quarantine` keeps the DB, symlink-escape is refused. |
| `Scripts/test-distribution.sh` | No — builds into local `Release/` and `/var/folders` tmp, non-destructive | **FAIL** 9/10 checks OK, 1 FAIL | Fails on "binary contains the literal repo checkout path" — the script's own comment calls this a known SwiftPM `Bundle.module` fallback-string limitation documented in `Documentation/KNOWN_LIMITATIONS.md`, said not to affect runtime behavior. Pre-existing, not introduced this session. |
| `Scripts/test-release-manifest.sh` | No — reads `Release/` artifacts and `SHA256SUMS`/`latest.json` | **FAIL** 2 checks fail | (1) `SHA256SUMS` does not verify against the zip/dmg that `test-distribution.sh` just rebuilt in the same session — the checked-in manifest was generated for an earlier build of the same version number. (2) `dmgSize` in `latest.json` (2950742) mismatches the actual on-disk DMG size (2950739), a 3-byte drift. Both are real, reproducible defects in the release-artifact pipeline as of this HEAD. Not fixed this session (release pipeline is out of the "fix only if it blocks the audit" scope). |
| `Scripts/check-private-data.sh` | No — read-only grep over tracked files | **PASS** | No developer username, no hardcoded secrets, no tracked `.env`/DB files found in tracked content. Does not check full `git log -p` history for old personal paths/secrets — see "Gaps" below. |

## Gaps / not yet audited this session

- Did not spot-check `git log -p` full history for old personal paths or secrets beyond what
  `check-private-data.sh` covers (its check is against the current working tree, not every historical
  commit). Flagged for session 2 (security/privacy audit).
- Did not run `swift test --list` to compare a "declared" test count against the "actually ran" count;
  the 86/27 figures are the actually-executed count from a real run, which is the authoritative number
  per this audit's own principle (trust execution, not filenames).
- No test found that actually exercises the ClamAV `Process()` invocation itself (only its output
  parser and the quarantine data path are covered) — a real coverage gap, not a documentation gap.
- Coverage percentages / line coverage were not computed this session (would require `swift test
  --enable-code-coverage`, not run — deferred to session 2 if in scope).
