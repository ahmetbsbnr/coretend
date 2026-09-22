# CoreTend

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Resources/Brand/Generated/Logo-Horizontal-dark@2x.png">
    <img src="Resources/Brand/Generated/Logo-Horizontal-light@2x.png" width="420" alt="CoreTend">
  </picture>
</p>

<p align="center"><strong>Know what your Mac is holding. Take the space back.</strong></p>

<p align="center">
  Local, transparent and reversible care for macOS. CoreTend reads what your Mac
  already records, explains every finding, and never deletes — eligible items go
  to the Trash after a reviewed selection and an explicit confirmation.
</p>

<p align="center">
  <a href="https://github.com/ahmetbsbnr/coretend/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/ahmetbsbnr/coretend?include_prereleases&sort=semver&color=0B6E6C&label=release"></a>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-14%2B%20%C2%B7%20Apple%20silicon-1B1E22">
  <img alt="Signed and notarized" src="https://img.shields.io/badge/Developer%20ID-signed%20%2B%20notarized-0B6E6C">
  <img alt="Runtime dependencies" src="https://img.shields.io/badge/runtime%20dependencies-zero-0B6E6C">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-1B1E22"></a>
</p>

<p align="center">
  <img src="Website/assets/app/smart-care.png" width="820" alt="CoreTend overview">
</p>

<p align="center">
  <a href="https://coretend.ahmetbsbnr.com">Product site</a> ·
  <a href="docs/PROJECT_METHOD.md">How this project is run</a> ·
  <a href="docs/ENGINEERING_RULES.md">Engineering rules</a> ·
  <a href="docs/README.md">Docs index</a>
</p>

---

## What it does

Eight destinations, each one a job rather than a data source.

| | |
|---|---|
| **Overview** | How the Mac is, what changed, what to do next. No score, no gauge, no invented total. |
| **Record** | Every scan, every move, every refusal — readable backwards. A refusal is a first-class entry, never a footnote. |
| **Cleanup** | Caches, logs and browser caches. Every candidate is shown, with its evidence, before anything can move. |
| **Explore** | A treemap where a folder's area *is* its bytes. Descend, search, inspect, reveal in Finder. Plus largest-and-oldest, similar images and cloud footprint. |
| **Duplicates** | Exact-content matches by staged hashing. One copy per group is always kept; the suggestion is editable. |
| **Applications** | Apps, the leftovers they abandon, and the updates they declare. |
| **Integrity** | Only what macOS already recorded: download provenance, code-signature tier, what launches at login. **Not** malware detection, and it says so. |
| **Performance** | Live CPU and memory over a real time axis, with the history of what past scans found. |

<p align="center">
  <img src="Website/assets/app/space-lens.png" width="400" alt="Explore treemap">
  <img src="Website/assets/app/cleanup.png" width="400" alt="Cleanup review">
</p>

## Install

```sh
brew install --cask coretend
```

Or take the DMG from the [latest release](https://github.com/ahmetbsbnr/coretend/releases/latest)
and check it against the `SHA256SUMS` published beside it:

```sh
shasum -a 256 ~/Downloads/CoreTend-*-arm64.dmg
```

Every release is Developer ID signed, notarized by Apple and stapled, so it
opens without a Gatekeeper prompt, and the checksums are themselves signed with
[Minisign](https://jedisct1.github.io/minisign/). macOS 14+, Apple silicon.

No version number is written on this page, deliberately. The cask in
[`homebrew/coretend.rb`](homebrew/coretend.rb) is generated from the published
release by `Scripts/generate-homebrew-cask.py`, and a gate fails if its checksum
ever stops matching the DMG — which is a stronger guarantee than a number
somebody remembered to update.

## What it will not do

The constraints are the product, so they are stated before the features.

- **It never deletes.** Everything goes to the macOS Trash and stays
  recoverable. It therefore never claims to have "freed" anything — it is not
  told when the Trash is emptied, and a test fails if such a total reappears.
- **Nothing leaves the Mac.** No account, no analytics, no telemetry. The one
  network request is a user-initiated update check for a public manifest, and
  it downloads nothing.
- **Zero runtime dependencies.** The only packages in `Package.resolved` are
  the test framework and its own dependency.
- **Every destructive path goes through `SafetyCore.PathValidator`** — never a
  raw `FileManager` call on a user-supplied path.

## How it compares

Only claims that can be checked, with the check named. A blank is not a "no" —
it means we did not verify it, and we would rather leave a gap than fill it
with a guess about somebody else's software.

| | **CoreTend** | CleanMyMac | Pearcleaner | PureMac | OnyX |
|---|:-:|:-:|:-:|:-:|:-:|
| Licence | **Apache-2.0** | proprietary | Apache-2.0 + Commons Clause¹ | MIT | proprietary |
| Source published | **yes** | no | yes | yes | no |
| Price | **free** | paid | free | free | free |
| Removal | **Trash only, always** | | | Trash in some paths, permanent in others² | |
| Unattended deletion | **never offered** | | | scheduled auto-clean² | |
| Runtime dependencies | **zero**³ | | | | |
| Network calls | **one, user-initiated**⁴ | | | | |

¹ Source-available, not OSI-approved — [its own README](https://github.com/alienator88/Pearcleaner)
calls it "fair-code". ² [PureMac's README](https://github.com/momenbasel/PureMac)
states this itself, which is more than most of this category does.
³ `Package.resolved` holds `swift-testing` and `swift-syntax`, both test-only.
⁴ `grep -rn URLSession Sources/` returns exactly one file: the update check.

The row that matters is the fourth. CoreTend has no code path that deletes —
not for caches, not for duplicates, not under an administrator prompt, not from
a schedule, not from the CLI. Everything eligible goes to the macOS Trash and
stays recoverable, which is also why the app never reports a "freed" total: it
is never told when the Trash is emptied, so it cannot honestly claim the space
came back.

These are not promises in a README. Each one fails the build when it stops
being true:

| Claim | What fails if it stops holding |
|---|---|
| Everything is recoverable | `Reversible means the Trash can give it back` |
| No invented quantities | `Copy does not claim what the app cannot know` |
| Every destructive path is validated | `PathValidator`, `SafetyCenter` |
| A refusal is recorded as a refusal | `Refusals and failures stay distinct` |
| The record cannot go silently short | `Audit log durability` |

Run them with `bash Scripts/test.sh`.

## Build and test

Pure SwiftPM: the package is the build system. There is no Xcode project for
the app, by decision.

```sh
swift build -c release              # must build with 0 warnings
bash Scripts/test.sh                # the whole suite — never raw `swift test`
bash Scripts/package-local.sh       # → build/CoreTend.app
bash Scripts/repository-doctor.sh   # private data, licences, drift, safety gates
```

`Scripts/` holds one job per script, and the ones a release goes through —
`release-preflight.sh`, `sign-and-notarize.sh`, `verify-release-staple.sh`,
`test-app-launch.sh` — are the same ones CI runs, not a simplified copy.

## How this project is run

Most of what describes this repository is **generated from the code**, and a
gate fails when it stops being true. A hand-drawn architecture diagram was
checked against the source and five of its edges were wrong — so the diagram is
derived now, not drawn.

| | |
|---|---|
| [**Project method**](docs/PROJECT_METHOD.md) | How a task moves from noticed to proven: where work comes from, plan before iterating, the commit as the unit, which command runs when. |
| [**Engineering rules**](docs/ENGINEERING_RULES.md) | How a decision is made: what evidence each claim costs, why a check is made to fail before it is trusted, what is never decided alone. |
| [**The 2.0 programme**](docs/CORETEND_V2_PROGRAM.md) | Where the product stands, the field it ships into, the MoSCoW breakdown, the visual programme, the App Store track, and the order it happens in. |
| [**The audit behind it**](docs/CORETEND_V2_AUDIT_AND_PLAN.md) | The security and quality audit, including the findings it reversed after measuring them. |
| [**Product vocabulary**](docs/PRODUCT_VOCABULARY.md) | One name per thing, in both languages. |

The rule underneath all of it: every artifact here is either **decided** or
**derived**, and the two are never edited the same way. A decided document
stops being what we want; a derived one stops describing what is. So they get
opposite guards — review, or a `--check` that fails on drift.

Development happens on two lines. `main` is the shipping 1.x product; the 2.0
rebuild lives on `develop/v2` and is **PRE-ALPHA** — not a release candidate,
not a preview, not ready, and it will not be called any of those until it is.

## Repository layout

```
Sources/          the app and its engines — SafetyCore, ScanCore, FileRules,
                  Persistence, AppDiscovery, IntegrityCore, SystemMetrics,
                  DesignSystem, CoreTendApp, and the CoreTendCLI front end
Tests/            fourteen suites
Scripts/          one job per script: build, capture, audit, release
docs/             the decision documents
Documentation/    research, audits, capture galleries, release evidence
Website/          the product site, built from reviewed repository inputs
homebrew/         the cask, generated from the published release
```

## Security

Vulnerability reports go through the
[security policy](https://github.com/ahmetbsbnr/coretend/security/policy) —
please do not open a public issue. The policy is
[`.github/SECURITY.md`](.github/SECURITY.md).

Two safety defects were found and fixed in 1.0.2, both present since the first
public source commit, both found by auditing the 2.0 rebuild rather than by a
report. The [changelog](Documentation/CHANGELOG.md) describes them, including
how much they actually mattered — which was less than the words "protected root
bypass" suggest, and saying so is part of the same discipline as fixing them.

## Contributing and support

[Contributing](.github/CONTRIBUTING.md) ·
[Code of conduct](.github/CODE_OF_CONDUCT.md) ·
[Support](.github/SUPPORT.md) ·
[Governance](.github/GOVERNANCE.md) ·
[Privacy](PRIVACY.md)

## Licence

Source code under [Apache-2.0](LICENSE). Documentation and original media keep
the terms in [`NOTICE`](NOTICE) and
[`docs/THIRD_PARTY_NOTICES.md`](docs/THIRD_PARTY_NOTICES.md); full licence
texts live in [`LICENSES/`](LICENSES) so each file's SPDX header resolves.

## Credits

CoreTend is directed, reviewed and validated by Ahmet Basbunar. Claude
(Anthropic) assists development under that supervision. Product decisions,
acceptance, release credentials and publication stay under human control.
