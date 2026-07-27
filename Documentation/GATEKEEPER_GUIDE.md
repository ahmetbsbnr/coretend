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
3. In Finder, open Applications.
4. Control-click CoreTend, choose **Open**, and read the confirmation.
5. If macOS instead offers the option under **System Settings → Privacy &
   Security**, use the option naming CoreTend specifically, then confirm.
6. Launch CoreTend again from Applications.

This authorizes that copy of CoreTend only. It is not an approval,
certification or malware validation. Never disable Gatekeeper or SIP globally.

If no per-app option appears, stop. Confirm macOS 14+, Apple silicon, the
official checksum and that the app was copied to Applications. Then consult
`TROUBLESHOOTING.md` or report an issue; do not run a broad quarantine-removal
command.
