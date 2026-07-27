<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Media Capture Guide

## Mandatory environment

Final media must be recorded in an isolated macOS VM or a dedicated local
account named `CoreTend Demo`, with no personal cloud account, email, browser
profile, files, credentials, notifications or developer tools. The machine
name must be neutral, the wallpaper plain, Focus enabled, Dock hidden and
unneeded applications closed. A normal personal account is not an acceptable
final-media source.

## Deterministic application session

Build the release bundle, create a temporary store, and launch the process in
test isolation:

```sh
bash Scripts/package-local.sh
DEMO_STORE="$(mktemp -d /tmp/coretend-media-store.XXXXXX)"
CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$DEMO_STORE" \
  build/CoreTend.app/Contents/MacOS/CoreTend -onboardingDone YES
```

The two-variable guard prevents the capture run from reading or writing the
normal CoreTend database and suppresses legacy-data migration. Do not run scans
against the operator's home directory for public media. Use neutral temporary
fixtures for any future scan demonstration.

Capture a window with `Scripts/capture.sh output.png "Module name"`. Use a
900×632-point window, hide notifications, close other applications and inspect
the complete frame before retaining it. Light appearance may be selected with
the app-scoped `NSRequiresAquaSystemAppearance` preference; delete that key
immediately after capture.

## Privacy review

Reject a frame containing a user or machine name, home path, Finder sidebar,
browser history, private URL, email, notification, profile image, serial,
UUID, token, key, other application or personal menu-bar item. Re-record
instead of blurring sensitive material. Strip extended attributes with
`xattr -c` and validate media with `Scripts/check-media.sh`.

## Encoding

The repository uses tools already available through Homebrew:

```sh
cwebp -q 82 -metadata none input.png -o output.webp
ffmpeg -i capture.mov -an -vf 'fps=24,scale=1440:-2:flags=lanczos' \
  -c:v libx264 -crf 25 -movflags +faststart -pix_fmt yuv420p output.mp4
ffmpeg -i capture.mov -an -vf 'fps=24,scale=1440:-2:flags=lanczos' \
  -c:v libvpx-vp9 -crf 35 -b:v 0 -row-mt 1 output.webm
```

Keep lossless PNG sources under `Documentation/Images/Screenshots/`; keep only
optimized web derivatives under `Website/assets/app/`.
