# Signing and notarization

Status as of `2026-08-31`: **capability is live.** A paid Apple Developer
Program account (Team `NSCUV5G738`) is now enrolled, a **Developer ID
Application** certificate has been issued and installed, and
`Scripts/sign-and-notarize.sh` has been run for real for the first time
against `0.9.1-rc.5` — the app and DMG were signed, **notarized (both
submissions `Accepted` by Apple's notary service)** and stapled, and
`spctl --assess` reports `accepted / source=Notarized Developer ID` for the
app inside the DMG.

CoreTend 1.0.0 was signed and published through the documented local/manual
path. No SLSA attestation exists for it because final signing occurred outside
Actions; adding one later would misidentify the builder. The next release uses
the dedicated self-hosted signing runner in `.github/workflows/release.yml`.

Earlier status (kept for history): through `0.9.1-rc.5` every published
artifact was **unsigned, not notarized**, by documented decision, because no
Developer ID was available.

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
  loudly if it isn't, before touching anything. **Fixed 2026-08-31**: the
  first real run surfaced an ordering bug — `Scripts/package-dmg.sh`
  rebuilt and ad-hoc re-signed `build/CoreTend.app` *between* notarization
  submission and stapling, so `stapler` found no ticket for the changed
  CDHash (`Error 65`). The script now ZIPs → submits → staples the *same*
  bundle → builds the DMG from it with `CORETEND_SKIP_APP_BUILD=1` (new
  guard in `package-dmg.sh`, no rebuild) → signs the DMG → submits →
  staples the DMG.
- Developer ID identity installed: `Developer ID Application: Ahmet BASBUNAR
  (NSCUV5G738)`, issued from the pre-existing
  `Configuration/DeveloperID/developerID_CSR.csr` (**not regenerated** — see
  the release-signing rule). Notarization uses an App Store Connect API key
  (`.p8` in the gitignored `Configuration/DeveloperID/`, key material never
  committed) registered as the `notarytool` keychain profile `CoreTend-Notary`.

## Prerequisites (one-time, human, requires a paid account)

**Done 2026-08-31** for Team `NSCUV5G738`. Kept here as the reproducible
procedure (e.g. after certificate expiry in 2031, or on a new machine).

1. Enroll in the Apple Developer Program.
2. Create a **Developer ID Application** certificate in
   [developer.apple.com](https://developer.apple.com) → Certificates →
   *Developer ID Application*, **G2 Sub-CA**, uploading
   `Configuration/DeveloperID/developerID_CSR.csr` (the CSR already in the
   repo — do **not** generate a new one, it is paired with the private key
   next to it). Download the `.cer`.
3. Install it as a signing identity (combines the Apple cert with the
   existing private key):
   ```
   security import Configuration/DeveloperID/developerID_private.key \
     -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
   security import ~/Downloads/developerID_application.cer \
     -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
   security find-identity -v -p codesigning     # expect: Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)
   ```
4. Register a notarytool credential. This project used an **App Store
   Connect API key** (App Store Connect → Users and Access → Integrations →
   *App Store Connect API* → generate, role *Developer*). Save the `.p8`
   into the gitignored `Configuration/DeveloperID/`, then:
   ```
   xcrun notarytool store-credentials "CoreTend-Notary" \
     --key Configuration/DeveloperID/AuthKey_XXXXXXXXXX.p8 \
     --key-id XXXXXXXXXX --issuer <issuer-uuid>
   ```
   An app-specific password works equally well
   (`--apple-id … --team-id NSCUV5G738 --password …`). Either way the
   credential lives in the keychain — never in a file in this repository.

## Running it

```
export CORETEND_DEVELOPER_ID_APPLICATION="Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)"
Scripts/package-local.sh
Scripts/sign-and-notarize.sh <version> CoreTend-Notary
```

The script, in order:

1. Verifies the identity and notarytool profile both exist — refuses to
   proceed otherwise.
2. Signs every embedded Mach-O binary/dylib depth-first, then the app
   bundle itself, with `--options runtime --timestamp` and
   `Configuration/CoreTend.entitlements`.
3. Verifies the signature (`codesign --verify --deep --strict`).
4. ZIPs the signed app and submits it to Apple's notary service; waits.
5. Staples the ticket to that same app bundle and validates the staple.
6. Builds the DMG from the signed, stapled app
   (`CORETEND_SKIP_APP_BUILD=1 Scripts/package-dmg.sh` — no rebuild), copies
   it to the release name, signs the DMG (`--timestamp`), submits it for its
   own notarization, staples and validates.
7. Runs a final Gatekeeper check (`spctl --assess`) on both and prints the
   SHA-256 of the ZIP and DMG.

## Publishing the next signed release

The protected tag workflow runs on labels `self-hosted`, `macOS`, `ARM64`, and
`coretend-signing`. This keeps non-exported signing material on the maintainer's
Mac while placing build, signing, notarization and SLSA attestation in one
GitHub Actions job. It never downloads previously built release bytes and then
claims to have built them.

1. Bump `marketingVersion` + `buildNumber` in
   `Configuration/PublicIdentity.example.json`; mirror into
   `Resources/Info.plist` (`CoreTendMarketingVersion`, `CFBundleVersion`)
   and `Documentation/PROJECT_STATE.json`
   (`Scripts/check-version-consistency.sh` gates this).
2. Write `Release/Notes/<version>.en.md` and `.fr.md`.
3. Confirm signing runner is online and its protected environment requires
   maintainer approval. Required secrets: `CORETEND_DEVELOPER_ID_APPLICATION`,
   `CORETEND_NOTARY_PROFILE`, `MINISIGN_SECRET_KEY`, `MINISIGN_PASSWORD`.
4. Tag `v<version>` and push. Workflow builds, signs, notarizes and staples;
   generates manifest, SHA-256 and SBOM; attests final ZIP/DMG; signs
   verification files with Minisign; then publishes. Any missing credential or
   failed Apple verification stops publication.
5. Download and verify release on second Mac using next section.
6. Release-sync gate then updates
   `Configuration/published-release.json`; the portfolio's
   `sync-coretend.yml` picks up the published version.
7. Confirm download page and in-app `UpdateChecker` resolve new stable release
   tag/asset URLs (they follow the published release, never a local build).

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
