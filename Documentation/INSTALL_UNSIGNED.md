# Installing an Unsigned Build

Pre-1.0 builds of MacCare Local are distributed without a Developer ID
signature and without Apple notarization (see `Release/latest.json`:
`signed: false`, `notarized: false`). macOS Gatekeeper will refuse to
open the app on first launch unless you explicitly allow it. This is
expected, not a bug.

## 1. Download from the official release only

Download the ZIP or DMG from the official repository release page (see
`Documentation/HUMAN_BLOCKERS.md` for current publication status — no
public release exists yet). Do not download MacCare Local from any
third-party mirror, forum link, or unofficial source.

## 2. Verify the SHA-256 checksum before opening anything

```
shasum -a 256 "MacCare-Local-<version>-arm64-unsigned.zip"
```

or

```
Scripts/verify-download.sh "MacCare-Local-<version>-arm64-unsigned.zip" <expected-sha256-from-SHA256SUMS>
```

Compare the result against the matching line in the release's
`SHA256SUMS` file (published alongside the download). If it doesn't
match exactly, delete the file and download again — do not open it.

## 3. Open the DMG or extract the ZIP

- DMG: double-click to mount, then drag `MacCare Local.app` to the
  `Applications` shortcut inside the same window.
- ZIP: double-click to extract, then move `MacCare Local.app` to
  `/Applications`.

## 4. Try opening it

Double-click `MacCare Local.app` in `/Applications`. macOS will likely
block it with a message like "MacCare Local can't be opened because it
is from an unidentified developer" or "Apple could not verify...".

## 5. Explicitly allow it, after verifying provenance

Only after you've confirmed the checksum in step 2 matches the official
release:

1. Open **System Settings > Privacy & Security**.
2. Scroll to the Security section — you'll see a note about MacCare
   Local being blocked.
3. Click **Open Anyway**.
4. Confirm again in the dialog that appears.

## 6. Relaunch

Open `MacCare Local.app` again from `/Applications`. It should now
launch normally.

## 7. Grant only the permissions the app actually needs

macOS will prompt for permissions as needed:
- **Full Disk Access** — required for most scan features to see files
  outside the app's sandbox. Grant only to MacCare Local, only when
  prompted.
- Do not grant permissions "just in case" beyond what's requested when
  you use a specific feature.

## What NOT to do

Do not work around Gatekeeper by disabling platform security instead of
verifying the download. Specifically, never:

- run `sudo spctl --master-disable` (turns off Gatekeeper system-wide);
- disable System Integrity Protection (SIP);
- run `xattr -cr` on the app as a routine step (strips the quarantine
  attribute blindly, without verifying what you're stripping it from);
- download MacCare Local from an unknown/unofficial source because the
  official one seemed inconvenient.

Verifying the checksum, then explicitly allowing that one specific,
verified app in System Settings, is the safe path — it doesn't weaken
Gatekeeper for anything else on your Mac.
