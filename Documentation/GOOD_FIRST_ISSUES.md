# Good First Issues

Starting points for a first contribution. None of these require touching
`SafetyCore` deletion logic — good for getting familiar with the codebase
first. See [DEVELOPMENT.md](../DEVELOPMENT.md) to get building.

## Docs
- Improve any page under `Documentation/` with a concrete example or
  screenshot reference.
- Add a missing French translation key if `fr.lproj/Localizable.strings`
  ever drifts from `Base.lproj` (see [LOCALIZATION.md](LOCALIZATION.md)).

## Tests
- Add a `PersistenceTests` case for an edge case in `Store` (e.g. empty
  exclusion list, duplicate exclusion insert — `INSERT OR IGNORE` behavior).
- Add a `SafetyCoreTests` case for a protected-root edge case (trailing
  slash, symlink chain) — see [SAFETYCORE.md](SAFETYCORE.md).

## Small UI
- Accessibility labels/localization coverage gaps in any `CoreTendApp`
  view — check for hardcoded `Text("...")` instead of `L("...")`.
- Empty-state or failed-state polish in a module view (each module follows
  the idle/scanning/review/executing/done/failed pattern — see
  [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)).

## Tooling
- Improve `Scripts/doctor.sh` diagnostics (clearer error message for a
  missing prerequisite).
- Add a key-parity check between the two `.strings` files (see
  [LOCALIZATION.md](LOCALIZATION.md), "Checking for drift").

## Before you start
Open or comment on the relevant issue first to avoid duplicate work. For
anything bigger than the above, read
[Documentation/RFC_TEMPLATE.md](RFC_TEMPLATE.md) — larger changes should be
proposed before they're built.
