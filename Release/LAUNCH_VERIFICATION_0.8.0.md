# Launch Verification — MacCare Local 0.8.0 (outside repo checkout)

Manual verification performed this build session, in addition to the
automated `test-distribution.sh`/`test-uninstall.sh` gates (which also
launch/quit and are covered separately in `Documentation/AUDIT_COMMANDS.log`).

## DMG mount → copy → launch → quit → unmount

1. `hdiutil attach Release/MacCare-Local-0.8.0-arm64-unsigned.dmg -nobrowse`
   → mounted at `/Volumes/MacCare Local`. Contents matched
   `BUNDLE_INVENTORY_0.8.0.md` exactly: `MacCare Local.app`, `Applications`
   symlink, `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`.
2. Copied `MacCare Local.app` to `/private/tmp/mc-launch-test.app` —
   outside both the repo checkout and the mounted DMG.
3. `hdiutil detach` — unmounted cleanly (DMG no longer needed once the
   copy exists, proving the app doesn't depend on staying mounted).
4. `open /private/tmp/mc-launch-test.app` — launched successfully; `ps`
   confirmed the process running from `/private/tmp/mc-launch-test.app/
   Contents/MacOS/MacCareLocal`, not from the repo or the DMG.
5. Process terminated cleanly (`kill`, no crash log, no hang), temp copy
   removed.

**Result: PASS.** The app runs correctly when copied to an arbitrary
location with no repo checkout or mounted volume present, consistent with
the "no repo-path dependency" claim in `Documentation/KNOWN_LIMITATIONS.md`.

## Separate real-app UI verification (this build session)

Rebuilt via `Scripts/package-local.sh`, launched from `build/MacCare
Local.app`, and used to take one real, window-only screenshot (Smart Care
idle screen) confirming the built 0.8.0 UI renders correctly and matches
`Documentation/FEATURE_MATRIX.md`'s claims (honest "not yet available"
labels where ancien scanner externe/performance/app-analysis aren't wired to this specific
screen state). See `Documentation/KNOWN_LIMITATIONS.md` and
`Documentation/VISUAL_QA.md` for the full display-availability note and
what remains for a full visual-QA campaign.

## What this does NOT cover

- Code signing / notarization — not applicable, this is an unsigned build
  by design for the pre-1.0 phase (`Documentation/HUMAN_BLOCKERS.md`).
- Multi-machine / multi-OS-version verification — single physical Mac
  only (`Documentation/COMPATIBILITY.md`).
- Interactive VoiceOver — `BLOCKED_ENVIRONMENT` per
  `Documentation/KNOWN_LIMITATIONS.md`.
