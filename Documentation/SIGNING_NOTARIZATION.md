# Signing and notarization

Status as of `0.9.1-rc.1`: **not signed, not notarized.** No Apple Developer
Program membership is available in any environment this project has been
built in. Everything below is fully prepared and has never been executed —
running it requires a real, paid Apple Developer ID.

## Why CoreTend is not App Sandboxed

`Configuration/CoreTend.entitlements` is intentionally close to empty.
CoreTend's core function — finding duplicate/large/leftover files anywhere
the user points it, inspecting other applications' support directories for
uninstall leftovers, and probing TCC-protected paths to detect Full Disk
Access — cannot fit inside the App Sandbox's per-app container model without
losing that function. This rules out Mac App Store distribution but not
direct (notarized, Developer ID) distribution, which has no sandbox
requirement. This is the same model used by comparable Mac cleanup utilities
distributed outside the App Store.

Hardened Runtime is still required and used — it is orthogonal to sandboxing
and is what notarization actually depends on.

## What is already in place

- `CFBundleIdentifier`: `com.ahmetbsbnr.coretend` — stable, never changed
  since the CoreTend rename (see `Documentation/RebrandHistory/`).
- `CFBundleShortVersionString` / `CFBundleVersion`: kept in lockstep by
  `Scripts/check-version-consistency.sh`, sourced from
  `Configuration/PublicIdentity.example.json`.
- `Configuration/CoreTend.entitlements`: hardened runtime baseline, zero
  `com.apple.security.cs.*` exceptions (no disabled library validation, no
  unsigned executable memory, no debugging, no DYLD env vars) — verified
  unnecessary by grepping `Sources/` for anything that would need them.
- `Scripts/sign-and-notarize.sh`: the complete, real procedure below,
  gated on an actual Developer ID being present. Fails immediately and
  loudly if it isn't, before touching anything.

## Prerequisites (one-time, human, requires a paid account)

1. Enroll in the Apple Developer Program.
2. Create a **Developer ID Application** certificate in
   [developer.apple.com](https://developer.apple.com) → Certificates, and
   let Xcode or `security` install it into the login keychain.
3. Find its exact identity string:
   ```
   security find-identity -v -p codesigning
   ```
4. Generate an app-specific password at
   [appleid.apple.com](https://appleid.apple.com) (or use an API key), and
   register it for `notarytool`:
   ```
   xcrun notarytool store-credentials "CoreTend-Notary" \
     --apple-id "you@example.com" --team-id "TEAMID1234" \
     --password "app-specific-password"
   ```
   This stores the credential in the keychain — it is never written to a
   file in this repository.

## Running it

```
export CORETEND_DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID1234)"
Scripts/sign-and-notarize.sh 1.0.0 CoreTend-Notary
```

The script, in order:

1. Verifies the identity and notarytool profile both exist — refuses to
   proceed otherwise.
2. Signs every embedded Mach-O binary/dylib depth-first, then the app
   bundle itself, with `--options runtime --timestamp` and
   `Configuration/CoreTend.entitlements`.
3. Verifies the signature (`codesign --verify --deep --strict`).
4. Packages a ZIP and a DMG (`Scripts/package-dmg.sh`).
5. Submits the ZIP to Apple's notary service and waits for a result.
6. Staples the ticket to the app, re-packages the DMG with the now-stapled
   app, submits the DMG for its own notarization, and staples that too.
7. Runs a final Gatekeeper check (`spctl --assess`) on both.

## Verifying on a clean machine

Before publishing, validate on a Mac that has never had this build's
identity trusted and ideally has no developer tools installed:

```
xcrun stapler validate CoreTend-<version>-arm64.dmg
spctl --assess --type open --context context:primary-signature --verbose CoreTend-<version>-arm64.dmg
```

Both must succeed with no `--ignore-cache` or Gatekeeper-bypass flags. If
either fails, do not publish — re-check the identity, entitlements, and that
the DMG was re-packaged *after* stapling the app (order matters: the app
inside the DMG must already carry its staple).

## What never happens here

- No self-signed or ad-hoc certificate is ever presented as a real Developer
  ID signature — `Scripts/package-local.sh`'s `codesign --sign -` (ad-hoc)
  is for local development only and is never claimed to satisfy Gatekeeper.
- No Gatekeeper-bypass command (`spctl --master-disable`,
  `xattr -d com.apple.quarantine`, System Settings toggles) is documented as
  a step for users to take. `Documentation/INSTALL_UNSIGNED.md` covers the
  per-app right-click-Open path instead, which does not weaken system-wide
  protection.
- No download of a certificate or private key from anywhere other than
  Apple's own Developer portal.
