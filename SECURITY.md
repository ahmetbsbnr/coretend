# Security Policy

CoreTend is pre-1.0 software. There is no signed/notarized release
yet, and no formal security-response infrastructure beyond what's
described here.

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
(once it exists) its public website's own code.

Out of scope: vulnerabilities in macOS itself, in Apple frameworks, or in
the externally-installed ClamAV binary (report those upstream to Apple or
the ClamAV project respectively).

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

## Pre-1.0 status

Because this project has not had a public release, audit, or notarized
build yet, treat any binary you build yourself as unsigned, unaudited,
development software.
