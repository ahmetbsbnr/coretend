# Direct-distribution release process

CoreTend publishes releases through the tag-triggered GitHub Actions workflow.
`v1.0.0` was signed and published manually; it intentionally has no SLSA
attestation. The next release uses a maintainer-controlled self-hosted signing
Mac so final Developer ID signed and Apple-notarized bytes are also attested.

## Pre-release checklist

1. `Scripts/doctor.sh` clean.
2. `Scripts/test.sh` — all tests passing, 0 failing.
3. `swift build -c release` — 0 warnings.
4. `Scripts/repository-doctor.sh`, `Scripts/check-licenses.sh`,
   `Scripts/check-private-data.sh`, `Scripts/check-placeholders.sh` —
   clean.
5. Dedicated signing runner executes `Scripts/package-local.sh`, then
   `Scripts/sign-and-notarize.sh`; absence of signing/notary credentials fails
   the release.
6. Update `Documentation/CHANGELOG.md` and bump version per
   `Documentation/PROJECT_STATE.json` conventions.
7. Merge the reviewed release branch, then create the immutable version tag on
   that exact merge commit.
8. Let `.github/workflows/release.yml` build from the clean tag, sign,
   notarize, staple and publish DMG, ZIP, `latest.json`, `SHA256SUMS`, Minisign
   signatures, SBOM and SLSA provenance for those exact final artifacts.
9. Download the public assets again; compare names, sizes and SHA-256 values,
   mount the exact DMG and launch its extracted app in isolated test mode.
10. Run `Scripts/sync-published-release.sh` only after that verification, then
    merge the site/portfolio synchronization after their CI and deployment
    gates pass.

## Signing-runner requirements

- Labels: `self-hosted`, `macOS`, `ARM64`, `coretend-signing`.
- Developer ID identity installed in runner keychain.
- Notarytool keychain profile named by `CORETEND_NOTARY_PROFILE` secret.
- Secrets `CORETEND_DEVELOPER_ID_APPLICATION`, `CORETEND_NOTARY_PROFILE`,
  `MINISIGN_SECRET_KEY`, and `MINISIGN_PASSWORD`.
- Protected release environment and tag rules requiring maintainer approval.

## What this process will never include

Telemetry opt-in bundled into the installer, automatic quarantine removal, or
any step that requires disabling Gatekeeper/SIP for the builder or end user.

## Who can cut a release

The repository maintainer `ahmetbsbnr` cuts public releases after the protected
CI, Security, artifact and production gates above pass.
