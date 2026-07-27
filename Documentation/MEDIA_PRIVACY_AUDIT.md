<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Media Privacy Audit

- Environment used so far: normal macOS account, administrator, with CoreTend
  store redirected to a new temporary directory.
- Dedicated demo account or VM: not yet available.
- Apple account state: not inspected because the normal session is not an
  acceptable final-media environment.
- Demo dataset: generator prepared; final dataset not yet captured.
- Final captures produced: none.
- Final videos produced: none.
- Cleaning tools prepared: `xattr`, `cwebp`, `ffmpeg`, `ffprobe`, `sips`,
  `mdls`, and repository privacy scripts.
- Automated control: prepared; final media absent.
- Human inspection: the app-only draft frames appeared clean, but were rejected
  because the account was not dedicated.
- Anomaly: a real Gatekeeper dialog was observed, but the full-screen capture
  exposed private background content.
- Media redone: required.
- Rejected files: all draft screenshots, the draft product-tour video and the
  full-screen Gatekeeper capture. None was committed or retained under tracked
  repository paths.
- Published personal data: none from this media phase.
- Remaining limit: create/use the dedicated `CoreTend Demo` account or an
  isolated VM, then perform the single ordered capture session.

Decision: **HUMAN_REVIEW_REQUIRED**. In case of doubt, do not publish and
re-capture.
