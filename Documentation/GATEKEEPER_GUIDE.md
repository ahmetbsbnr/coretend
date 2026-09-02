<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Opening CoreTend 0.9.0 Safely

CoreTend 0.9.0 is unsigned and not notarized. macOS therefore blocks a normal
first double-click. On macOS 26.5.1 the observed French dialog said
“Élément « CoreTend » non ouvert” and explained that macOS could not confirm
that it contained no malware. Labels vary by macOS version.

## Graphical per-app route

1. Confirm the file name is `CoreTend-0.9.0-arm64-unsigned.dmg` and that it came
   from the official CoreTend release.
2. Open the DMG and drag CoreTend to Applications.
3. In Finder, open Applications and double-click CoreTend once. macOS refuses
   to open it and reports that the developer cannot be verified. This is
   expected, and it is what makes the app appear in the next step.
4. Open **System Settings → Privacy & Security**, scroll to **Security**, and
   choose **Open Anyway** next to the CoreTend message. Confirm with Touch ID
   or your admin password.
5. Launch CoreTend again from Applications.

On **macOS 14 and earlier** you can instead Control-click CoreTend in Finder
and choose **Open**. Apple removed that override in macOS 15 Sequoia — on
macOS 15 and later it silently does nothing, so use System Settings there.

This authorizes that copy of CoreTend only. It is not an approval,
certification or malware validation. Never disable Gatekeeper or SIP globally.

If no per-app option appears, stop. Confirm macOS 14+, Apple silicon, the
official checksum and that the app was copied to Applications. Then consult
`TROUBLESHOOTING.md` or report an issue; do not run a broad quarantine-removal
command.
