# Contributing to CoreTend

Thanks for considering a contribution. This is a pre-1.0 open-source
project — expect some rough edges in the process itself.

## Before you start

- Read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- Read [Documentation/SAFETY_MODEL.md](Documentation/SAFETY_MODEL.md) —
  any change touching deletion, scanning, or permissions must respect
  the review, explicit-confirmation and Trash-only rules.
- For anything security-sensitive, see [SECURITY.md](SECURITY.md)
  instead of opening a public issue.

## Setup

```sh
Scripts/doctor.sh   # verify your toolchain
Scripts/test.sh     # run the test suite
Scripts/build.sh    # debug build
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full local setup.

## Branch & commit conventions

- Branch names: `feat/...`, `fix/...`, `docs/...`, `chore/...`.
- Commits: atomic, imperative subject line, Conventional-Commits-style
  prefix (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`).
- Sign off your commits with `git commit -s` (Developer Certificate of
  Origin — `Signed-off-by: Name <email>`). This project does not use a
  separate CLA.

## Required before a PR is merged

- `Scripts/test.sh` passes with 0 failures.
- A debug build succeeds with no new warnings.
- New logic touching SafetyCore/ScanCore/deletion paths includes tests.
- Localizable strings use the existing localization mechanism (see
  Documentation/LOCALIZATION.md) rather than hardcoded English/French text.
- No secrets, absolute personal paths, or private data in the diff
  (`Scripts/check-private-data.sh`).

## Swift style

- Favor the existing patterns in the module you're touching over
  introducing a new style.
- Prefer value types and explicit ownership; concurrency should follow
  the actor patterns already used in Persistence/ScanCore.
- No force-unwraps in code paths that can run against real user data.

## Areas needing extra care

- **SafetyCore / deletion rules**: every destructive UI must review the
  selection, request explicit confirmation, and route the action through the
  existing validated Trash path.
- **Migrations**: schema changes need a new migration, not an edit to an
  existing one (see Documentation/MIGRATIONS.md).
- **Localization**: add both `en` and `fr` strings together.
- **Design system**: use existing `MC*` tokens (Documentation/DESIGN_SYSTEM.md)
  rather than hardcoded colors/spacing.
- **Accessibility & performance**: don't regress VoiceOver labels or
  introduce blocking work on the main actor for scan-heavy code.
- **Licensing**: only add third-party code/assets you can verify the
  license for, and record it in Documentation/DEPENDENCIES.md or
  Documentation/ASSET_PROVENANCE.md.
- **Docs**: update the relevant Documentation/*.md alongside behavior
  changes — stale docs are treated as a bug.

## Opening an issue

Use the templates under `.github/ISSUE_TEMPLATE/`. Include your CoreTend
Local version, macOS version, and Apple Silicon model. Never attach real
personal data, scan logs, or screenshots containing private information —
the templates ask you to confirm this.

## Review process

A maintainer reviews for: correctness, safety-model compliance, test
coverage, licensing cleanliness, and doc updates. Expect iteration —
this is normal for a young project.
