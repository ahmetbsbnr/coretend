# Contributing to CoreTend

Thank you for helping. CoreTend moves people's files, so every change keeps the same promises:
scans only read, and a move goes to the macOS Trash after the person has reviewed and confirmed it.

## Before you start

Open an issue first for anything larger than a fix, so we can agree on the change. Then send a
pull request against `main` that says what changes for the person using the app, what could go
wrong, and how you checked it.

## Working locally

You need macOS 14 or later and Swift 6. From the repository root:

```sh
make check   # builds, runs the tests, the safety audit and the site checks
make app     # builds an unsigned CoreTend.app in Artifacts/
```

Tests that touch files must use temporary folders they create themselves: never your real home
folder, the real Trash or CoreTend's real store. Any code that moves a file goes through
`SafetyCore`.

New dependencies, images or fonts need their source and licence stated in the pull request.

For a security problem, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
