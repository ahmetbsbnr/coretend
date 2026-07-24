# Installation

CoreTend is a native macOS app for Apple Silicon (macOS 14+). No
account, no installer package with a background daemon, no subscription.

## From source (current state — no signed releases yet)

Requirements: macOS 14+, Apple Silicon, Swift command-line tools (Xcode not
required; see `Scripts/doctor.sh` to check your setup).

```sh
git clone <repo>
cd MACCLEAN
Scripts/doctor.sh            # checks prerequisites
Scripts/bootstrap.sh         # one-time setup
Scripts/build.sh release     # release build
Scripts/package-local.sh     # produces build/CoreTend.app (ad-hoc signed)
```

Copy `build/CoreTend.app` to `/Applications` (or run it in place).

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the full developer workflow.

## Signed releases

There is no notarized, signed public release yet — see
`Documentation/PUBLIC_RELEASE_READINESS.md`. Until one exists, running an
ad-hoc-signed local build may trigger Gatekeeper's "unidentified developer"
prompt; approve it via **System Settings → Privacy & Security** as you
would for any locally built app. Do not disable Gatekeeper or remove the
quarantine attribute as a routine workaround — see
[FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md) for what permissions the app
actually needs and why.

## Uninstalling

See [UNINSTALL.md](UNINSTALL.md) and `Scripts/uninstall-local.sh`.
