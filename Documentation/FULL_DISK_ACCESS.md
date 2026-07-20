# Full Disk Access

MacCare Local works without Full Disk Access (FDA), but some scans (Mail,
Safari data, and other TCC-protected folders) need it to see everything
there is to see.

## What MacCare Local actually checks

The app never assumes you granted access just because you clicked a button.
It probes real TCC-protected folders (`~/Library/Safari`,
`~/Library/Mail`) by trying to list their contents; if that fails, it
honestly reports FDA as not granted (see `PermissionProbe` in
`Sources/MacCareApp/OnboardingView.swift`).

## Granting it

Onboarding (and Settings) offer a button that opens System Settings directly
to **Privacy & Security → Full Disk Access**
(`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`).
From there:

1. Click the `+` button (you may need to unlock with your password).
2. Add **MacCare Local**.
3. Toggle it on.
4. Quit and relaunch MacCare Local — macOS only applies TCC grants to a
   fresh process.

## What happens without it

Scans still run. Folders that require FDA and aren't accessible are simply
skipped (fewer findings, not a crash or a silent lie about what was
checked) — the app reports what it could and could not scan.

## What MacCare Local will never ask you to do

It will never ask you to disable SIP, disable Gatekeeper, disable
FileVault, remove a quarantine attribute as a routine step, or run it with
`sudo`. If a scan needs a permission, macOS's own permission system is the
only way to grant it.
