# FAQ

**Is CoreTend affiliated with CleanMyMac or MacPaw?**
No. Not affiliated with CleanMyMac, MacPaw, or Apple in any way.

**Does it require an account or subscription?**
No. It runs entirely locally, no account, no subscription, no telemetry.

**Is it a full antivirus?**
No. Protection is a local, on-demand ClamAV-backed scan and reversible
quarantine — not real-time protection, not a security guarantee, not a
replacement for macOS's built-in protections. See
[PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md).

**Will it delete my files permanently?**
Cleanup and Smart Care move files to the macOS Trash by default (see
[RESTORE.md](RESTORE.md)) — recoverable until you empty the Trash.
Permanent deletion only happens as an explicit, separate action (e.g.
"Delete Permanently" on a quarantined item).

**Does it need Full Disk Access?**
Not strictly — the app works without it, but some folders (Mail, Safari
data) can only be scanned with it. See
[FULL_DISK_ACCESS.md](FULL_DISK_ACCESS.md).

**Does it send any data anywhere?**
No network calls for app data. Everything stays in
`~/Library/Application Support/CoreTend/`. See
[DATA_LOCATIONS.md](DATA_LOCATIONS.md).

**Is it AI-generated or a school project?**
No — it's a maintained open source utility with a real test suite, an
explicit safety model, and ongoing development.

**How do I report a bug or a vulnerability?**
Bugs: `.github/ISSUE_TEMPLATE/`. Vulnerabilities: [SECURITY.md](../SECURITY.md)
(do not file a public issue for security reports).

**How do I completely remove it and its data?**
[UNINSTALL.md](UNINSTALL.md), `Scripts/uninstall-local.sh`.

**Will disabling SIP/Gatekeeper/FileVault help it work better?**
No — never do this. CoreTend never asks for that, and doing so
weakens your Mac's security for no benefit to the app.
