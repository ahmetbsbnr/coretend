# Exclusions

Exclusions let you tell every scan engine "never flag this path" — useful
for a folder a scanner would otherwise treat as clutter (e.g. a large but
intentional cache, a project directory that looks like leftovers).

## Managing exclusions

Settings → Exclusions:
- **Add**: pick a file or folder via the standard macOS open panel.
- **Remove**: swipe/delete an entry from the list.

Exclusions are stored in the `exclusions` table of the local SQLite
database (`~/Library/Application Support/CoreTend/store.sqlite`,
managed by the `Store` actor in `Sources/Persistence/Store.swift`) — plain
paths, nothing else. See [DATA_LOCATIONS.md](DATA_LOCATIONS.md).

## Scope

An exclusion applies to the exact path added. Excluding a parent folder
excludes everything under it for scan purposes; excluding a single file
only excludes that file.

## What exclusions do not do

Exclusions only affect what CoreTend's own scan engines flag. They are
not a macOS-level permission, they don't affect Spotlight, Time Machine, or
any other system feature, and they never override the hard-coded protected
system roots enforced by `PathValidator` in
`Sources/SafetyCore/SafetyCore.swift` — those roots (`/System`, `/bin`,
`/usr/*`, etc.) can never be selected for deletion regardless of
exclusion/inclusion settings.
