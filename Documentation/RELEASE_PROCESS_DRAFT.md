# Release Process (Draft)

Draft only — no signed public release has shipped yet. See
`Documentation/PUBLIC_RELEASE_READINESS.md` for what's still missing
(notably an Apple Developer ID for signing/notarization, out of scope for
the Open Source Foundation phase).

## Local pre-release checklist (what already exists)

1. `Scripts/doctor.sh` clean.
2. `Scripts/test.sh` — all tests passing, 0 failing.
3. `swift build -c release` — 0 warnings.
4. `Scripts/repository-doctor.sh`, `Scripts/check-licenses.sh`,
   `Scripts/check-private-data.sh`, `Scripts/check-placeholders.sh` —
   clean.
5. `Scripts/package-local.sh` — produces `build/MacCare Local.app`,
   ad-hoc signed only.
6. Update `CHANGELOG.md` and bump version per
   `Documentation/PROJECT_STATE.json` conventions.

## What a real signed release additionally needs (not yet done)

- Apple Developer ID certificate for code signing.
- Notarization (`notarytool`) and stapling.
- A tagged, versioned build artifact attached to a GitHub Release.
- Verified reproducible build from a clean clone (tracked separately —
  explicitly out of scope for this phase, see the session brief in
  `CONTINUATION.md`).

## What this process will never include

Auto-publish/auto-release from CI without a human trigger, telemetry
opt-in bundled into the installer, or any step that requires disabling
Gatekeeper/SIP for the *builder* or the *end user*.

## Who can cut a release

Until `GOVERNANCE.md`'s maintainer model is populated with a real handle
(`[MAINTAINER_HANDLE_TO_DEFINE]`), no one should cut a public release from
this repository.
