# Third-Party Notices

MacCare Local's SwiftPM manifest (`Package.swift`) declares **zero external
package dependencies** — every target (`ScanCore`, `SafetyCore`,
`FileRules`, `DesignSystem`, `Persistence`, `SystemMetrics`,
`AppDiscovery`, `MalwareEngine`, `MacCareApp`) is first-party code in this
repository, built only against Apple system frameworks (SwiftUI,
Foundation, SQLite3 via the system libsqlite3, Vision, IOKit, etc.), which
ship with macOS/Swift and are not redistributed by this project.

## ClamAV (optional, external, not bundled)
MacCare Local's Protection module can shell out to a `clamscan` binary if
the user has separately installed ClamAV (e.g. via Homebrew). MacCare
Local:
- does not link `libclamav`,
- does not embed the ClamAV binary or its virus-signature database in
  this repository or any built application bundle,
- does not claim to develop, maintain, or be affiliated with the ClamAV
  project.

If installed by the user, ClamAV is licensed separately (GPL-2.0) by the
Cisco Talos / ClamAV project, entirely outside this repository. See
Documentation/CLAMAV.md.

## See also
- Documentation/DEPENDENCIES.md — full dependency audit matrix
- Documentation/THIRD_PARTY_AUDIT.md — audit methodology and findings
- Documentation/ASSET_PROVENANCE.md — provenance of icons/images/fonts
