# Supported Macs

- Apple Silicon (arm64) only — M1 and later. No Intel (x86_64) build is
  produced or tested; the app is not universal.
- Requires macOS 14.0 (Sonoma) or later — see `MACOS_VERSION_POLICY.md`
  for why that floor was chosen.
- Only ever built, run, and tested on one physical machine (see
  `Documentation/COMPATIBILITY.md`). No claim is made about behavior on
  other Apple Silicon models (M1 vs M2 vs M3 vs M4) beyond "same
  architecture, same public APIs" — there is no per-chip code path in
  this app.
