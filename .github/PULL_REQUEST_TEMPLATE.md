## Summary

<!-- What does this PR change, in one or two sentences? -->

## Motivation

<!-- Why is this change needed? Link an issue if there is one. -->

## Screenshots (if UI-facing)

<!-- Before/after, or n/a -->

## Tests

- [ ] `Scripts/test.sh` passes locally (still 0 failing)
- [ ] `swift build -c release` — 0 warnings
- [ ] Added/updated tests for the behavior changed (see `Documentation/TESTING.md`)

## Security / safety

- [ ] This PR does not add a new destructive file operation outside
      `SafetyCore.SafetyCenter` / `PathValidator` (see `Documentation/SAFETYCORE.md`)
- [ ] This PR does not weaken protected-root or symlink-escape checks
- [ ] N/A — no file-operation code touched

## Persistence / migrations

- [ ] This PR adds a new migration, appended (never edited) per
      `Documentation/MIGRATIONS.md`
- [ ] N/A — no schema change

## Performance

- [ ] No obvious regression for large scans (thousands of files)
- [ ] N/A

## Accessibility

- [ ] VoiceOver labels / keyboard navigation checked for any new UI
- [ ] N/A — no UI changed

## Localization

- [ ] New user-facing strings added to both `Base.lproj` and `fr.lproj`
      `Localizable.strings` (see `Documentation/LOCALIZATION.md`)
- [ ] N/A — no new strings

## Licensing

- [ ] New files carry appropriate license headers / no incompatible
      third-party code introduced (see `Documentation/DEPENDENCIES.md`,
      `THIRD_PARTY_NOTICES.md`)
- [ ] I have signed off my commits (`git commit -s`) per the DCO — see
      `GOVERNANCE.md`

## Docs

- [ ] Updated relevant docs under `Documentation/` (or root `README.md`)
- [ ] N/A

## Checklist

- [ ] I've read `CONTRIBUTING.md`
- [ ] This PR is scoped to one change (no unrelated refactors bundled in)
