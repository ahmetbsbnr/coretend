# Public Release Readiness

Tracks concrete verification performed toward the repo being safely
publishable, and what still blocks it. This is a running record, not a
promise — see `Documentation/HUMAN_BLOCKERS.md` for decisions only a human
can make.

## Reproducible clean-clone build verification (2026-07-20)

Performed on branch `feat/open-source-foundation`, HEAD at the time
`179bde9`. Method: `git archive HEAD` extracted into a fresh `mktemp -d`
directory outside the repo (so no git-ignored files, no absolute paths from
the working copy, nothing keyed to this checkout's location), then ran the
full local build/test/package/launch path from there.

Steps run from the clean copy, in order:

1. `Scripts/doctor.sh` — passed (macOS, Swift 6 toolchain, dev tools all OK;
   ClamAV correctly reported as optional/absent).
2. `Scripts/test.sh` — all 83 tests passed, 0 failures, 26 suites.
3. `swift build` (debug) — clean build, no errors.
4. `swift build -c release` — clean build, no errors.
5. `Scripts/package-local.sh` — assembled `MacCare Local.app`.
6. Launched the packaged app's binary directly from the clean-clone build
   output and confirmed it stayed running with no stderr/stdout errors and
   no crash report.

### Bug found and fixed: missing SwiftPM resource bundle in the packaged app

`Scripts/package-local.sh` copied the icon/menu-bar assets into
`Contents/Resources/` but never copied the SwiftPM-generated
`MacCareLocal_MacCareApp.bundle` (which contains `Localizable.xcstrings` /
`Localizable.strings` for `fr.lproj` and `Base.lproj`).

Impact: at runtime, `Bundle.module`'s generated accessor
(`resource_bundle_accessor.swift`) first looks for the bundle next to the
app's own bundle path; when that's missing, it falls back to an **absolute
`.build/<arch>/release/...bundle` path baked into the binary at compile
time**. In this test, that fallback path pointed into the throwaway
`mktemp -d` clone directory — i.e. the packaged `.app` silently depended on
the exact machine-specific directory it happened to be built in, and would
`fatalError` (the accessor's documented failure mode) on any other machine
or once that build directory was deleted.

Fix: `Scripts/package-local.sh` now copies every `.build/release/*.bundle`
into `Contents/Resources/` alongside the existing assets, so `Bundle.main`
resolution succeeds and the baked-in absolute fallback path is never
needed. Re-ran packaging and the launch check after the fix; the app
bundle's `Contents/Resources/` now contains
`MacCareLocal_MacCareApp.bundle/` with the localization files, and the
absolute build-tree fallback path is no longer reached.

### Path-independence checks

- `strings -a` over the packaged binary: no occurrence of `MACCLEAN`
  (original repo dirname) or the developer's real macOS account name
  (redacted here deliberately — see `Scripts/check-private-data.sh`, which
  greps for it across tracked files). The only absolute path found was the
  harmless SwiftPM fallback described above (unreached once the bundle fix
  is in place).
- `~/Library/Application Support/MacCareLocal/store.sqlite` (WAL mode)
  initialized correctly and was actively written to during the clean-clone
  app's run — persistence path is keyed off the app's bundle identifier,
  not the source checkout location.
- Temp clone directory was fully removed after verification.

### Outcome

Clean-clone build, test, package, and launch all succeed after the
`package-local.sh` fix. No other path/machine dependency found. This check
should be repeated whenever `Scripts/package-local.sh` or SwiftPM target
resource declarations change.
