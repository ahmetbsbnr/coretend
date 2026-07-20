# Localization

Standard `.strings`-based localization, no third-party i18n library.

- `defaultLocalization: "en"` in `Package.swift`.
- Two locales today: `Sources/MacCareApp/Resources/Base.lproj/Localizable.strings`
  (English, the fallback) and `Sources/MacCareApp/Resources/fr.lproj/Localizable.strings`
  (French) — 367 keys each, kept in sync (same key count).
- Lookup goes through one helper, `L(_:_:)` in `Sources/MacCareApp/L10n.swift`:

  ```swift
  func L(_ key: String, _ args: CVarArg...) -> String {
      let format = Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
      if args.isEmpty { return format }
      return String(format: format, arguments: args)
  }
  ```

  Passing the key itself as the fallback `value` means a missing
  translation renders as its raw key (visibly wrong, not a crash) rather
  than silently falling back to English — easy to spot in review.

## Adding a new UI string

1. Add the key to **both** `Base.lproj/Localizable.strings` and
   `fr.lproj/Localizable.strings` in the same commit — never add a key to
   only one locale.
2. Call it via `L("your.key")` (or `L("your.key", arg1, arg2)` for
   `String(format:)`-style interpolation) — never hardcode user-facing text
   in a SwiftUI `Text(...)`.
3. Keep key names dotted/namespaced by screen (`cleanup.title`,
   `protection.delete_permanently`, etc.) — matches the existing
   convention.

## Adding a new locale

Add a new `<lang>.lproj/Localizable.strings` with every key from
`Base.lproj`, add it to the app's supported locales (Package resources are
already `.process("Resources")`, so a new `.lproj` directory is picked up
automatically). No build-script changes needed.

## Checking for drift

There's no automated key-parity check yet; when adding this to CI (see
remaining work in `Documentation/CONTINUATION.md`), a simple key-count/diff
between the two `.strings` files is enough — this is a plain-text diff, no
tooling dependency required.
