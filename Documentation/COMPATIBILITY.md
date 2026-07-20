# Compatibility

Single entry point for platform-support questions. See also
`API_AVAILABILITY_AUDIT.md` (method), `SUPPORTED_MACS.md` (hardware),
`MACOS_VERSION_POLICY.md` (OS versions and how the floor is chosen).

- Architecture: Apple Silicon (arm64) only. No Intel build is produced.
- Deployment target: `Package.swift` declares `.macOS(.v14)` — macOS 14
  Sonoma. This is the SwiftPM/Xcode enum value; Apple's later
  year-based naming (macOS 15 Sequoia, macOS 26 Tahoe) doesn't change
  what `.v14` means at the toolchain level.
- Built and tested only on the single development machine available to
  this project: macOS 26.5.1 (build 25F80), arm64, Swift 6.3.2 via
  CommandLineTools (no Xcode installed). There is no second physical or
  virtual Mac and no Xcode "run on older SDK" simulation available in
  this environment, so behavior on macOS 14/15 is verified by static
  API-availability audit (below), not by running the app there. This
  gap is honestly tracked, not glossed over.
