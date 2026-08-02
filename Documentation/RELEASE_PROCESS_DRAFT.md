# Direct-distribution release process

CoreTend publishes release candidates through the tag-triggered GitHub Actions
workflow. `v0.9.1-rc.5` is the current public example. Direct-distribution
builds are ad-hoc signed and not notarized; Developer ID signing and Apple
notarization remain a later distribution phase.

## Pre-release checklist

1. `Scripts/doctor.sh` clean.
2. `Scripts/test.sh` — all tests passing, 0 failing.
3. `swift build -c release` — 0 warnings.
4. `Scripts/repository-doctor.sh`, `Scripts/check-licenses.sh`,
   `Scripts/check-private-data.sh`, `Scripts/check-placeholders.sh` —
   clean.
5. `Scripts/package-local.sh` — produces `build/CoreTend.app`,
   ad-hoc signed only.
6. Update `Documentation/CHANGELOG.md` and bump version per
   `Documentation/PROJECT_STATE.json` conventions.
7. Merge the reviewed release branch, then create the immutable version tag on
   that exact merge commit.
8. Let `.github/workflows/release.yml` build from the clean tag and publish the
   DMG, ZIP, `latest.json`, `SHA256SUMS`, Minisign signatures, SBOM and
   provenance.
9. Download the public assets again; compare names, sizes and SHA-256 values,
   mount the exact DMG and launch its extracted app in isolated test mode.
10. Run `Scripts/sync-published-release.sh` only after that verification, then
    merge the site/portfolio synchronization after their CI and deployment
    gates pass.

## What a future signed release additionally needs

- Apple Developer ID certificate for code signing.
- Notarization (`notarytool`) and stapling.
- A Developer ID signature verified on the final artifact.
- Apple notarization and stapling verified on the final artifact.

## What this process will never include

Telemetry opt-in bundled into the installer, automatic quarantine removal, or
any step that requires disabling Gatekeeper/SIP for the builder or end user.

## Who can cut a release

The repository maintainer `ahmetbsbnr` cuts public releases after the protected
CI, Security, artifact and production gates above pass.
