# Privacy

CoreTend 2.0 runs entirely on your Mac.

## Nothing leaves your Mac
- No network requests as part of any feature, no account, no telemetry, no analytics, no crash
  reporting to a server.
- The only link that can open the network is one you click yourself (for example an app's
  declared update page), which opens in your browser.

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
