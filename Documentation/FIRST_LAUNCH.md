# First Launch

MacCare Local's onboarding (`Sources/MacCareApp/OnboardingView.swift`) is
short, skippable, and resumable — four steps, no permission is forced.

1. **Welcome** — what the app is and isn't (see the positioning statement
   in the root [README.md](../README.md)).
2. **How it works** — dry-run/review-before-action explained.
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

1. Run a **Smart Care** or **Cleanup** scan in dry-run mode (the default)
   to see what MacCare Local would find on your Mac, with nothing removed.
2. Review the findings, add any [exclusions](EXCLUSIONS.md) you want.
3. Turn off dry-run when you're ready to actually free space (removals go
   to the Trash — see [RESTORE.md](RESTORE.md)).
4. Optionally set up [Protection](PROTECTION.md) if you have ClamAV
   installed.
