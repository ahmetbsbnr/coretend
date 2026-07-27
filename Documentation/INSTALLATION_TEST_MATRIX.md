<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Installation Test Matrix

Minimum supported OS is macOS 14 from `Package.swift` and `Info.plist`.
The published executable is thin arm64. Only macOS 26.5.1 arm64 was locally
available. The active account is an administrator; no standard test account or
VM was available, so those rows remain explicit human work.

| macOS | Arch | Account | Source | Download | Checksum | Install | First launch | Warning | Opening method | Permissions | Main feature | Close / relaunch | Update | Uninstall | Result | Anomalies |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 26.5.1 | arm64 | administrator | DMG public | HTTP 200, 5,192,666 bytes | exact | mounted read-only; copied to temporary Applications | blocked under controlled quarantine | real French dialog: “Élément « CoreTend » non ouvert”; macOS could not confirm absence of malware | direct open blocked; contextual/System Settings approval still needs isolated human capture | none requested before block | not reached through quarantined route | N/A | same version copy structurally valid | simple removal from temporary Applications | partial, honest | available screenshot rejected because private background was visible |
| 26.5.1 | arm64 | administrator | ZIP public | HTTP 200, 2,833,085 bytes | exact | extracted; bundle byte-equivalent to DMG app | executable without browser quarantine; isolated launch already validated separately | `spctl` rejects unsigned app | controlled quarantine reproduces block | none required to extract/copy | Smart Care idle verified from release bundle | close/relaunch verified in isolated app-capture run | same bundle | delete temporary copy | pass except clean-profile approval path | curl does not add browser quarantine |
| 14.x minimum | arm64 | standard | DMG + ZIP | pending | pending | pending | pending | wording version-dependent | per-app visible macOS route | pending | pending | pending | pending | pending | HUMAN_ACTION_REQUIRED | no machine/VM available |
| intermediate supported OS | arm64 | standard | DMG | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | HUMAN_ACTION_REQUIRED | no machine/VM available |
| 26.5.1 | Intel | any | any | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | NOT_APPLICABLE | no Intel binary is published |

Public ZIP, DMG, `latest.json` and `SHA256SUMS` were downloaded from the GitHub
v0.9.0 release. `SHA256SUMS`, `unzip -t`, `hdiutil verify`, manifest fields and
bundle architecture/version all passed. DMG and ZIP contained the same app.
