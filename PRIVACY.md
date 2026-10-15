# Privacy

CoreTend 2.0 runs entirely on your Mac.

## Nothing about you leaves your Mac
- No account, no telemetry, no analytics, no crash reporting to a server, no request in the
  background.
- CoreTend asks its own site whether a new version of CoreTend exists (Sparkle). You can turn this
  off in Settings.
- **Check for updates** in Apps reads the update feed each app declares (its own HTTPS Sparkle
  address), only when you click it. The request carries no cookie and nothing about you; nothing
  is downloaded (decision 0007).
- **What is this?** in Clean is written on your Mac by Apple Intelligence; nothing is sent.
- Alerts, when you turn them on, are local notifications computed on your Mac.
- Any other link opens in your browser only when you click it.

## Only the folders you choose
- Each tool reads the folder you pick. Usual folders (Applications, LaunchAgents) are offered as
  one-click choices and are not read before you choose them.
- CoreTend never asks for Full Disk Access or for your password.
- Scans read names, sizes and dates; file contents are read only to compare copies for exact
  duplicates. Nothing is written into what is scanned.

## What is stored, and where
- A local database in `~/Library/Application Support/CoreTend-Reconstruction/`: the activity
  history (Record), performance readings (30 days, 500 at most), favorites, and — only if you turn
  it on — up to 100 recent paths from Explore.
- Preferences in `~/Library/Preferences/com.ahmetbsbnr.coretend.plist`.
- You can export or clear the history in Record, clear readings in Performance, and remove
  favorites and recent paths in Overview.

## Moving files
- Nothing moves without your selection, a review and a confirmation. CoreTend checks each file
  again just before moving it, and moves only to the macOS Trash, where you can put it back.

## Diagnostics
- The optional diagnostic export shows you its exact content first and contains no paths, file
  names or event details.
