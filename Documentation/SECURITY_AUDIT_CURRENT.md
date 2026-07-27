<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Security Audit — 0.9.0 public beta

Final pre-release security and secrets audit.

Last verified: 2026-07-27, at commit `06629dc` on
`feat/coretend-rebrand-workspace`.

Every claim below names the command that produced it. Where something could
not be verified, it says so rather than assuming.

## 1. Secrets

| Check | Command | Result |
|---|---|---|
| Repo's own private-data gate | `Scripts/check-private-data.sh` | **PASS** — no developer username in tracked files, no hardcoded secrets, no tracked `.env`, no tracked SQLite/DB files |
| Provider token patterns in tracked tree | `git grep -nIE` for `ghp_`/`gho_`/`ghu_`/`ghs_`/`github_pat_`, `AKIA[0-9A-Z]{16}`, `sk-…`, `xox[baprs]-…`, `-----BEGIN … PRIVATE KEY-----` | **No matches** |
| Credential/certificate files tracked | `git ls-files` filtered for `.env`, `.p12`, `.pem`, `.key`, `.cer`, `.mobileprovision`, `.provisionprofile`, `.pfx`, `id_rsa`, `credentials` | **None tracked** |
| Same patterns in the **published** tree | `git grep` against `public-main` | **No matches** |
| Personal account name in the published tree | `Scripts/check-private-data.sh`, which derives the name from `id -un` at runtime, plus a `git grep` for `/Users/[a-z]+` and `/Volumes/` against `public-main` | **No leak.** Every hit is a macOS system path (`/Volumes/Recovery`, `/Library/Apple`), a safety-allowlist constant, or a deliberately synthetic test home (`/Users/alice`, `/Users/testuser`) |

**No secret was found, so none had to be redacted or revoked.**

### Git history

The published history is **one commit**: `git log --oneline public-main | wc -l`
→ `1`, and `git log --oneline origin/main | wc -l` → `1`. The private
development history has never been pushed. The public commit is the output of
`Scripts/build-public-branch.sh`, which stages 389 files and excludes 79
(session logs, workspace manifests, audit packages, rebrand working files).

This is the reason the audit weights the published tree over the local one:
scanning `public-main` covers everything that is actually exposed. No history
rewrite was needed, and none was performed.

### Gitignore coverage

`Configuration/PublicIdentity.local.json`,
`Configuration/BrandRenameApproval.local.json`, `.env`, `.env.*`, `dist/`,
`Release/latest.json`, `Release/SHA256SUMS`, `build/` and `.build/` are all
ignored. The two `.local.json` files are where real identity lives, and neither
is tracked — confirmed by `git ls-files`.

## 2. GitHub settings — verified by API, not assumed

Read live with `gh api repos/ahmetbsbnr/coretend`:

| Setting | Verified value |
|---|---|
| Visibility | `"visibility": "public"`, `"private": false` |
| Default branch | `main` |
| Archived | `false` |
| Private vulnerability reporting | `{"enabled": true}` (`/private-vulnerability-reporting`) |
| Secret scanning | `enabled` |
| Secret scanning push protection | `enabled` |
| Dependabot security updates | `enabled` |

Reachability, unauthenticated: `curl` on the repository → **HTTP 200**; on
`…/security/advisories/new` → **HTTP 200**. The security contact published in
`SECURITY.md` therefore resolves to a live channel.

Two related settings are **disabled**: `secret_scanning_non_provider_patterns`
and `secret_scanning_validity_checks`. Neither was claimed as enabled. Enabling
them is optional hardening, not a release blocker.

## 3. Application security posture

### Network

`git grep` for `URLSession`, `NSURLConnection`, `CFNetwork`, `Network`,
`socket(` across `Sources/*.swift` returns **no network client code at all**.

The only outbound URLs are ones the *user* opens in their browser or in System
Settings: the repository link on the onboarding summary, `macappstore://` for
the updates page, and two `x-apple.systempreferences:` deep links. The app
opens no socket of its own.

This substantiates the "no telemetry, no analytics, no account" claim
structurally rather than by assertion — there is no code path that could send
anything.

### Subprocess execution

One `Process()` shell-out, in `Sources/MalwareEngine/MalwareEngine.swift`:
the optional, user-installed `clamscan`. Arguments are passed as a discrete
`[String]` array, never through `/bin/sh -c`, so adversarial filenames cannot
inject a shell command. The binary path is restricted to a small set of
hardcoded well-known install locations checked with `isExecutableFile`. An
attacker able to write to one of those already has local code execution, so
this is not a new attack surface. **Adequate as-is.**

### Deletion paths

`SafetyCore` routes deletion through `trashItem` — recoverable by design, and
validated against a per-operation path allowlist before acting. The single
`removeItem` hard delete in `MalwareEngine.delete(_:)` operates only on files
already inside the app's own quarantine directory and only on explicit user
action. Large & Old, Similar Images and Space Lens have no deletion path at
all.

### Entitlements, sandbox, hardened runtime

**The app is not sandboxed, has no entitlements file, and does not use the
hardened runtime.** `codesign -d --entitlements -` returns no entitlements, and
`codesign -d -vvv` reports `flags=0x2(adhoc)` — the ad-hoc flag only, with no
runtime flag.

This is stated plainly rather than glossed:

- **App Sandbox** is incompatible with the product's purpose. A maintenance
  tool that scans arbitrary user directories cannot operate meaningfully inside
  a container. It relies on user-granted Full Disk Access instead, which is an
  explicit, revocable, per-app grant the user makes in System Settings.
- **Hardened runtime** is only meaningful alongside a Developer ID signature
  and notarization, neither of which is available here (see §5). Enabling it on
  an ad-hoc-signed build would add no protection.

`Resources/Info.plist` declares no `NS…UsageDescription` strings. For the
TCC-protected folders this app reaches, macOS supplies its own prompt, so this
is not a functional defect; adding purpose strings would improve the wording
the user sees and is worth doing before 1.0.

### Scripts

No `sudo` anywhere outside comments. No `curl … | sh` or `wget … |` pattern. No
`eval`. Every `rm -rf` in `Scripts/` targets a script-controlled temporary
variable, and the long-lived ones are guarded by `trap … EXIT`. A CI job
(`.github/workflows/security.yml`) enforces the dangerous-command rules.

## 4. Dependencies

Zero external SwiftPM packages (`Package.swift` has no `.package(url:…)`
entry), so the dependency-vulnerability surface is empty. There is no lockfile
to audit and nothing to update. Dependabot is enabled and currently covers the
`github-actions` ecosystem only, which matches the fact that GitHub Actions are
the only third-party components in the build.

## 5. Signing and notarization — stated, not masked

| Property | Verified value | Command |
|---|---|---|
| Signing identities available | **0 valid identities** | `security find-identity -v -p codesigning` |
| Signature on the built app | `Signature=adhoc`, `TeamIdentifier=not set` | `codesign -dv build/CoreTend.app` |
| Signature integrity | `valid on disk`, `satisfies its Designated Requirement` | `codesign --verify --deep --strict --verbose=2` |
| Gatekeeper assessment | **`rejected`** | `spctl --assess --type execute --verbose=4` |

The `spctl` rejection is the **expected and correct** result for an unsigned
build. It is recorded here as a failure, not reframed as a pass. An ad-hoc
signature is not a Developer ID: it asserts no identity and Gatekeeper does not
accept it.

Notarization has not been performed and cannot be without a paid Apple
Developer Program membership. This is the reason the release is 0.9.0 unsigned
public beta rather than 1.0.0 signed.

## 6. Findings

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | The onboarding summary's "Read the documentation" link pointed at `https://github.com` — GitHub's homepage, not the project. A user following it landed nowhere useful. | Low | **Fixed** — now points at the repository. |
| 2 | GitHub reports the repository licence as `NOASSERTION`, so the public UI shows no licence badge. `LICENSE` opens with a multi-licence preamble before the Apache-2.0 text, which GitHub's detector does not recognise. | Low; cosmetic but affects how the project reads to visitors | **Open.** Fixing it means restructuring `LICENSE` so the Apache text is verbatim, which touches licence presentation — deliberately not done unilaterally. The terms themselves are unambiguous and are stated in `README.md` and on the site's Licenses page. |
| 3 | No `NS…UsageDescription` purpose strings in `Info.plist`. | Low | **Open, accepted for 0.9.0.** macOS supplies default prompts; custom strings would read better. |
| 4 | `secret_scanning_non_provider_patterns` and `secret_scanning_validity_checks` are disabled. | Informational | **Open, optional hardening.** Never claimed as enabled. |
| 5 | App is unsandboxed with no hardened runtime. | By design | **Accepted and documented** — see §3. |
| 6 | App is unsigned and un-notarized; Gatekeeper rejects it. | Blocking for 1.0, accepted for 0.9.0 | **Accepted and disclosed** in README, release notes, download page and `INSTALL_UNSIGNED.md`. |

## 7. Not verifiable in this environment

- **Runtime TCC behaviour** (what macOS actually prompts on a clean machine)
  requires a fresh system and a display session; neither is available here.
- **Multi-machine / multi-OS behaviour** — one Apple Silicon Mac, one macOS
  version. No claim is made beyond it.
- **Third-party review.** This is a self-audit. It has not been reviewed by an
  independent security auditor, and nothing here should be read as such.
