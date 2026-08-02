<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Security audit — current rc.5 candidate

Revalidated on 2026-08-02 for `release/v0.9.1-rc.5`. The immutable public
release remains rc.4 until the rc.5 artifact has passed every release gate.
The exact final source commit is recorded in the release manifest and release
notes after the candidate tree is clean.

## Application boundary

- The production Swift sources contain no `Process(` invocation and do not
  execute a shell or third-party scanner.
- Integrity is read-only. `IntegrityCore` reads download provenance through
  Foundation, code signatures through Security.framework and launch-item
  property lists from documented local locations. It makes no malware,
  quarantine or threat-count claim.
- The only application network client is the explicit update check. It uses an
  ephemeral `URLSession` to request the public release manifest. CoreTend has
  no account, analytics, advertising or telemetry transport.
- Scans are read-only. Cleanup-capable views require a reviewed selection and
  explicit confirmation before handing typed operations to `SafetyCenter`.
- `SafetyCenter` revalidates every path immediately before moving it to the
  macOS Trash. Its direct `removeItem` fallback is restricted to validated
  temporary test roots and never applies to a normal user path.
- Legacy-data migration writes through temporary files and bounded legacy
  locations; it does not create a general deletion API.

## Secrets and personal data

The blocking checks are `Scripts/check-private-data.sh`, the repository
security workflow and the public-release gate. They reject credentials,
private keys, tracked local identity files, personal `/Users/...` paths and
unexpected private data. Test fixtures use synthetic identities only.

## Dependencies

All shipping targets are first-party and depend only on Apple system
frameworks. `swift-testing` and its transitive packages are test-only SwiftPM
dependencies and are not linked into the application bundle. See
[`DEPENDENCIES.md`](DEPENDENCIES.md).

## Signing and platform controls

The current release strategy is ad-hoc signing, unsigned identity and no
notarization. `codesign --verify` must pass for bundle integrity; `spctl` is
expected to reject the app because it has no Developer ID ticket. The public
installation guide documents Finder’s Open/Open Anyway flow and never disables
Gatekeeper, SIP or quarantine metadata.

CoreTend is intentionally not App Sandbox constrained because its purpose
requires user-authorized filesystem access. It has no privileged helper and
never invokes `sudo`.

## Required release evidence

Before publication, CI and the local release run must confirm:

1. secret/private-data, retired-component and absolute-path gates pass;
2. Debug and Release builds plus the full test suite pass;
3. the extracted DMG app contains IntegrityCore and no retired scanner code,
   executable, resource, string or metadata;
4. ad-hoc signature integrity passes and Gatekeeper rejection is recorded as
   expected;
5. local and downloaded asset size/SHA-256 are identical.

The only accepted future limitations are Developer ID signing, notarization
and a later Mac App Store feasibility study.
