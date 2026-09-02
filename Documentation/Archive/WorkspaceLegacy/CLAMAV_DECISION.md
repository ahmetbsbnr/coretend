# ClamAV decision: retired

Status: **ClamAV integration has been fully removed** from the app, the
onboarding flow, Settings, the menu bar, the website, and all product
communication. `Documentation/CLAMAV.md` described the old design and is
superseded by this document. This decision applies to every distribution
channel equally — there is one CoreTend, not a version that kept it.

## Why

CoreTend's own bar for this feature (stated explicitly by the product owner)
was: the user must never open Terminal, install Homebrew, copy a shell
command, locate a binary, or start a service by hand. Under Option A
(conservation) that bar required CoreTend itself to bundle, sign, install,
version-check and atomically update the scanning engine — a fully graphical
experience with zero manual steps.

The prior implementation did not meet that bar, and could not have without a
substantial new subsystem:

- **The engine was never bundled.** `Package.swift` declared no ClamAV
  dependency; the app shelled out to a `clamscan` binary the user had to
  install themselves via Homebrew or MacPorts. That is precisely the
  Terminal/Homebrew step the bar rules out.
- **No in-app installer or updater ever existed** for the engine or its
  signature database. Building one means downloading, verifying, and
  managing the lifecycle of a third-party GPL-licensed binary from inside a
  signed macOS app — a real distribution and licensing undertaking, not an
  afternoon's work.
- **Licensing was never reviewed by counsel.** This repository's own
  practice (see `Documentation/DECISIONS.md`) is to never claim legal
  clearance without one. Bundling a GPL-2.0 engine inside this project's
  distribution raises real questions this project has not had reviewed, so
  claiming Option A's "licence verified" criterion would have been
  dishonest.

Given the current architecture fails Option A's first, hardest requirement
today, and building the missing pieces means solving license and
distribution problems with no legal review available, the correct call is
Option B: retire the feature rather than ship a partial, Terminal-dependent
version of it under a name ("Protection") that implies more than it does.

## What replaced it

The "Protect" sidebar destination keeps its second tab (Privacy Cleaner,
unchanged) and gains a new first tab, **Integrity** — native macOS signals,
no scanning engine, no third-party binary, no signature database:

- **Download provenance.** Reads `NSURLQuarantinePropertiesKey` — the same
  metadata Finder and Safari already attach to a download — to show where a
  file in Downloads actually came from and whether it still carries the
  quarantine flag.
- **Code-signature inspector.** Lets you pick any app and see, via the
  Security framework's `SecStaticCode` APIs directly (no `codesign`/`spctl`
  subprocess), whether it's Apple-signed, signed by an identified team, or
  ad-hoc/unsigned — and whether that signature actually validates.
- **Login items.** Lists launch agents and daemons found in the standard
  `LaunchAgents`/`LaunchDaemons` locations.

None of this is presented as antivirus, malware detection, or a security
guarantee. It is exactly what it is: information macOS already has, made
visible. See `Sources/IntegrityCore/IntegrityCore.swift`.

## Impact on existing users

No migration is needed. The prior feature never bundled or downloaded
anything CoreTend controlled — it only detected and shelled out to a binary
the user installed independently. Removing the integration removes CoreTend's
UI for it; it does not touch, uninstall, or otherwise affect any ClamAV
installation a user already has on their Mac. The internal `Quarantine`
mechanism (an app-local isolation folder for scan findings) is removed along
with it, since nothing produces findings for it anymore; no user data
existed in that folder unless a prior version's user had ClamAV installed and
had manually quarantined a finding; that folder, if present, is untouched by
this change.

## Reversibility

This is not permanently foreclosed. If a future version bundles a properly
signed, licensed, in-app-managed engine that meets every Option A criterion —
including actual legal review of the licensing — this decision can be
revisited. Until then, do not reintroduce a Terminal- or Homebrew-dependent
security feature under any name.
