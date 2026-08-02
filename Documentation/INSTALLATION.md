# Installation

CoreTend is a native macOS app for Apple Silicon (macOS 14+). No
account, no installer package with a background daemon, no subscription.

## Public release candidate

CoreTend `v0.9.1-rc.4` is published as an unsigned, non-notarized DMG and ZIP:

- stable download route: `https://coretend.ahmetbsbnr.com/download`;
- release and checksums:
  `https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.1-rc.4`;
- required system: macOS 14 or later, Apple silicon (`arm64`).

Verify the downloaded file against `SHA256SUMS`, then follow
[INSTALL_UNSIGNED.md](INSTALL_UNSIGNED.md). The expected first-launch
Gatekeeper rejection is not an application crash.

## From source

Requirements: macOS 14+, Apple Silicon, Swift command-line tools (Xcode not
required; see `Scripts/doctor.sh` to check your setup).

```sh
git clone https://github.com/ahmetbsbnr/coretend.git
cd coretend
Scripts/doctor.sh            # checks prerequisites
Scripts/bootstrap.sh         # one-time setup
Scripts/build.sh release     # release build
Scripts/package-local.sh     # produces build/CoreTend.app (ad-hoc signed)
```

Copy `build/CoreTend.app` to `/Applications` (or run it in place).

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the full developer workflow.

## Signing status

There is no Developer ID-signed or notarized release yet. The public rc.4 and
local packages are ad-hoc signed, so Gatekeeper may show its unidentified
developer warning. After verifying the checksum, approve only this copy via
**System Settings → Privacy & Security → Open Anyway**. Do not disable
Gatekeeper or remove the quarantine attribute as a routine workaround — see
[FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md) for what permissions the app
actually needs and why.

## Uninstalling

See [UNINSTALL.md](UNINSTALL.md) and `Scripts/uninstall-local.sh`.
