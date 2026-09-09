# Security Policy

CoreTend's published releases are Developer ID signed and Apple-notarized.
There is no formal security-response infrastructure beyond what's described
here.

## Supported versions

Only the latest commit on the default branch is supported. There are no
tagged security-maintenance branches yet at this stage.

## Reporting a vulnerability

**Do not open a public GitHub issue for a security vulnerability.**
Public issues are for non-sensitive bugs and feature requests only —
critical vulnerabilities must not be disclosed publicly before a fix
exists.

Report vulnerabilities through **GitHub private vulnerability reporting**:

<https://github.com/ahmetbsbnr/coretend/security/advisories/new>

This is a private channel: the report is visible only to you and the
maintainer until an advisory is published. It requires a GitHub account —
that is a deliberate trade-off, chosen so that no personal email address
has to be published. No other reporting channel exists; there is no
security mailing address.

When reporting, please include:
- CoreTend version / commit hash
- macOS version and Apple Silicon model
- Steps to reproduce
- Impact assessment (what data/access is at risk)
- Whether the issue is exploitable remotely or requires local access

## Scope

In scope: CoreTend's Swift source, its build/packaging scripts, and
its public website's own code.

Out of scope: vulnerabilities in macOS itself or in Apple frameworks. Report
issues in third-party hosting or release infrastructure with the affected URL
and evidence so they can be routed to the appropriate provider.

## Expected process

1. We acknowledge reports as soon as a maintainer is available to do so.
2. We investigate and, if confirmed, work on a fix privately.
3. We coordinate disclosure timing with the reporter — no fixed SLA
   exists yet at this pre-1.0 stage, but we aim not to sit on a confirmed
   critical issue.
4. Credit is given to reporters who want it, once a fix ships.

## A note on the deletion feature

CoreTend's cleanup/uninstall features delete files. By default,
deletions go through the system Trash and are reversible until emptied.
If you find a way to make CoreTend delete files outside its stated
scope, bypass the Trash-by-default behavior unexpectedly, or delete files
without the explanation step, treat that as a security-relevant bug and
report it via the channel above rather than a public issue.

## Release signing

Published releases are Developer ID signed and Apple-notarized (Team
`NSCUV5G738`), so Gatekeeper opens them with no override step. Each release
also ships a `SHA256SUMS` file signed with a
[Minisign](https://jedisct1.github.io/minisign/) key for independent
provenance verification.

**Minisign key history:**

| Key ID | Used for | Status |
|---|---|---|
| `A399E8FD75C1719E` | releases before `v1.2.0-beta.1` (through `v1.0.0`) | Historical verification key — still correct for `v1.0.0` and earlier. Not used for new releases. No evidence of compromise. |
| `F8473FB09E1DB730` | releases from `v1.2.0-beta.1` onward | Current release-signing key. |

The Minisign key was rotated effective `v1.2.0-beta.1` because the previous
key's private-key password could no longer be unlocked — a custody problem,
not a compromise. Apple Developer ID signing and notarization are unchanged.
If you pinned `A399E8FD75C1719E`, fetch the new `minisign.pub` from the
`v1.2.0-beta.1` release and confirm its key ID is `F8473FB09E1DB730` before
trusting it. Full detail: `Documentation/SIGNING_NOTARIZATION.md` and
`Documentation/MINISIGN_KEY_ROTATION.md`.

Always verify published checksums, and follow the per-app first-open guidance
without disabling system protections globally.
