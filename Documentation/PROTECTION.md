# Integrity

The "Protect" sidebar destination's first tab is **Integrity**: three
read-only checks against signals macOS already records — no scanning
engine, no signature database, no third-party binary, nothing downloaded.
See [CLAMAV_DECISION.md](CLAMAV_DECISION.md) for why this replaced an
earlier ClamAV-based design, and
[PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md) for exactly what it
does and does not tell you.

## What it reads (`Sources/IntegrityCore/IntegrityCore.swift`)

- **Download provenance** — `NSURLQuarantinePropertiesKey`, the same
  metadata Finder's Info panel and Safari's download list already read.
  Shows where a file in Downloads actually came from and whether it still
  carries the quarantine flag.
- **Code-signature tier** — via the Security framework's `SecStaticCode`
  APIs directly (no `codesign`/`spctl` subprocess): Apple-signed, signed by
  an identified team, or ad-hoc/unsigned, plus whether the signature
  actually validates.
- **Login items** — launch agents and daemons found in the standard
  `LaunchAgents`/`LaunchDaemons` locations.

## Phases (`Sources/CoreTendApp/ProtectionView.swift`)

Each of the three checks runs on demand when its tab is opened — there is
no scan phase, no background watcher, and nothing to wait for.

## What Integrity does not do

It is not an antivirus, not malware detection, and not a security
guarantee — it is exactly what it reads: information macOS already has,
made visible. It does not scan file contents, does not maintain a
signature database, does not phone home, and does not replace macOS's
built-in XProtect/Gatekeeper.

The second tab, **Privacy Cleaner**, is unrelated to Integrity — see its
own section in the app for what it covers.
