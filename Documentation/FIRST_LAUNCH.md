# First Launch

CoreTend's onboarding (`Sources/CoreTendApp/OnboardingView.swift`) is
short, skippable, and resumable — four steps, no permission is forced.

1. **Welcome** — what the app is and isn't (see the positioning statement
   in the root [README.md](../README.md)).
2. **How it works** — review, explicit confirmation and Trash recovery explained.
3. **Full Disk Access (optional)** — a button opens System Settings
   directly to the right pane. The app probes real access (it does not
   just trust that you clicked through) — see
   [FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md). You can skip this and grant
   it later from Settings.
4. **Done** — straight into the app.

Your progress through onboarding is remembered (`@AppStorage
"onboardingStep"`), so quitting mid-onboarding resumes where you left off
rather than restarting.

## What to do first

1. Run a **Smart Care** or **Cleanup** scan to see what CoreTend finds on
   your Mac. Scanning does not move anything.
2. Review the findings, add any [exclusions](EXCLUSIONS.md) you want.
3. Use “Move to Trash,” review the confirmation, then approve only when you
   are ready (see [RESTORE.md](RESTORE.md)).
4. Check [Integrity](PROTECTION.md) — download provenance, code-signature
   tier and login items, read directly from macOS, no setup required.
