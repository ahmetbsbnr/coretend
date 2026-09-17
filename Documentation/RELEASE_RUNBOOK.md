<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Release runbook

How to cut a CoreTend release, what to do when a step fails, and how to recover
without leaving a half-published version behind.

This is the operational document. `SIGNING_NOTARIZATION.md` explains *why* the
signing model is what it is; `MINISIGN_KEY_ROTATION.md` records the key history.
Where they disagree with this file about a command, this file is right.

---

## The shape of a release

```
SOURCE ON main (CI green)
  → release-preflight            everything knowable without Apple
  → tag v<version>               triggers release.yml on the signing runner
  → gates + tests                repository, version, sync, suite, isolation
  → build + Developer ID sign    hardened runtime, entitlements, timestamp
  → notarize + staple            app first, then the DMG built from it
  → manifest + SBOM + attest     latest.json, SPDX, provenance
  → SHA256SUMS + Minisign        signed with the key the registry names
  → DRAFT release                assets uploaded, visible to nobody
  → download the draft's assets  and verify THOSE bytes
  → publish                      the last operation
  → sync site                    published-release.json, then the advisory
```

The rule the whole design serves: **publishing is the last operation, not the
one that reveals a fault.** Anything that can be wrong should be wrong before
Apple is involved, and anything that survives that should be caught while the
release is still a draft — invisible to users and to the "latest release" API.

---

## Prerequisites

### The signing runner

Releases run on a self-hosted Apple-silicon Mac, because the Developer ID
private key is non-exportable and must not leave it. GitHub-hosted runners
cannot sign.

```bash
cd ~/actions-runner-coretend
caffeinate -dimsu ./run.sh          # -dimsu: no display/idle/disk sleep
```

It must print `Connected to GitHub` and `Listening for Jobs`. Confirm from
anywhere with:

```bash
gh api repos/ahmetbsbnr/coretend/actions/runners \
  --jq '.runners[] | "\(.name) \(.status) \(.busy)"'
```

Labels must be exactly `self-hosted, macOS, ARM64, coretend-signing` —
`release.yml` targets all four. A runner that is `offline` does not fail the
release: it queues it indefinitely. `Scripts/release-preflight.sh` checks this
precisely so that never goes unnoticed.

Only `release.yml` reaches this runner, and only on a version-tag push. Never
add a `pull_request` trigger to a workflow that runs on it: that would let an
outside contributor execute code beside the signing key.

### Secrets (repository level)

| Secret | What it holds |
|---|---|
| `CORETEND_DEVELOPER_ID_APPLICATION` | `Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)` — the identity string, not the key |
| `CORETEND_NOTARY_PROFILE` | `CoreTend-Notary` — the notarytool keychain profile name on the runner |
| `MINISIGN_SECRET_KEY` | The minisign secret key file's contents |
| `MINISIGN_PASSWORD` | Its password |

```bash
gh secret list -R ahmetbsbnr/coretend
```

The Developer ID *certificate and private key* live in the runner's login
keychain and are never a secret here. Neither Minisign secret is ever printed
by any workflow; both reach a `mktemp` file under `umask 077`.

### One-time on the runner

```bash
# Developer ID certificate: Xcode → Settings → Accounts → Manage Certificates
#   → + → Developer ID Application

# Notarization credentials (App Store Connect API key):
xcrun notarytool store-credentials "CoreTend-Notary" \
  --key Configuration/DeveloperID/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX --issuer <issuer-uuid>

xcrun notarytool history --keychain-profile CoreTend-Notary   # must succeed
```

Never regenerate the CSR or private key in `Configuration/DeveloperID/`.

---

## Cutting a release

### 1. Prepare the version

Bump in **one** place and let the gate find the rest:

- `Configuration/PublicIdentity.example.json` → `marketingVersion`, `buildNumber`

Then mirror where `Scripts/check-version-consistency.sh` requires:

- `Resources/Info.plist` → `CFBundleShortVersionString`, `CFBundleVersion`,
  `CoreTendMarketingVersion`
- `Documentation/PROJECT_STATE.json` → `version`

Write both release notes — the release body quotes the English one:

- `Release/Notes/<version>.en.md`
- `Release/Notes/<version>.fr.md`

Add the changelog entry in `Documentation/CHANGELOG.md`.

Land it on `main` and let CI go green.

### 2. Preflight

```bash
bash Scripts/release-preflight.sh <version>        # locally
gh workflow run release-preflight.yml -R ahmetbsbnr/coretend -f version=<version>
```

The workflow additionally proves the configured Minisign secret really signs
for the key this version requires — the check whose absence nearly published
v1.0.1 unverifiable. Fix everything it reports before tagging. It publishes
nothing, so run it as often as you like.

### 3. Tag

The tag must point at the exact commit CI validated:

```bash
git fetch origin main
git log --oneline -1 origin/main          # note the SHA; CI must be green on it
git tag -a v<version> -m "CoreTend <version>"
git push origin v<version>
```

### 4. Watch

```bash
gh run watch -R ahmetbsbnr/coretend
```

The release stays a **draft** until `verify-published-artifacts.sh` passes
against the downloaded assets. If the run fails before that step, nothing was
ever public.

### 5. Verify independently

```bash
bash Scripts/verify-published-artifacts.sh <version>
```

Run it again after publication, from a different machine if possible. It
re-downloads and re-checks everything rather than trusting the workflow log.

### 6. Point the site at it — only now

```bash
bash Scripts/sync-published-release.sh      # rewrites Configuration/published-release.json
bash Scripts/test-release-sync.sh           # must pass
```

Then, and only after the public release is verified, clear any advisory banner:
set `ADVISORY = None` in `Website/build.py` and remove the duplicated
`.site-advisory` rules from `Website/index.html` and
`Website/assets/shell/public.css`. Regenerate the visual baseline in the same
commit:

```bash
node Scripts/visual/capture.mjs --update
```

Commit, push, and confirm the deployed site serves the new version.

---

## Channels

| | Stable | Beta / RC |
|---|---|---|
| Version | `X.Y.Z` | `X.Y.Z-beta.N` / `X.Y.Z-rc.N` |
| `channel` in `PublicIdentity.example.json` | `stable` | `beta` / `release-candidate` |
| GitHub release | normal | prerelease |
| Site download button | yes | no — the site follows `published-release.json`, which tracks the newest *stable* |
| Minisign key | whatever `minisign-keys.json` maps the version to | same |

`release.yml` derives the channel from the tag shape and refuses to publish if
it disagrees with the repository's declared channel. A beta must never change a
stable invariant: the key registry is keyed by version, not by branch, precisely
because a beta-branch rotation once left stable publishing the wrong key.

---

## Minisign key rotation

Never rotate by editing `Configuration/minisign.pub` alone. That is exactly how
v1.0.1 nearly shipped unverifiable.

1. Generate the new key; keep the secret out of the repository.
2. Commit the public key as `Configuration/minisign-<KEYID>.pub`.
3. Add an entry to `Configuration/minisign-keys.json`: `keyId`, `status`,
   `publicKeyFile`, `firstVersion` (the first release it signs), `channels`,
   `reason`. Set `lastVersion` on the outgoing entry to the last release the old
   key signed.
4. Copy the new public key over `Configuration/minisign.pub`.
5. Update `MINISIGN_SECRET_KEY` and `MINISIGN_PASSWORD`.
6. Run `release-preflight.yml`. It must report the new key id.
7. Record it in `Documentation/MINISIGN_KEY_ROTATION.md` and `SECURITY.md`.

Old releases keep verifying with the key that signed them — that is why retired
keys stay tracked and why the registry maps *ranges*, not a single current key.

---

## When something fails

| Symptom | What it means | What to do |
|---|---|---|
| Release job queues forever | No online runner with all four labels | Start the runner; re-run the job. Nothing was published. |
| Preflight: key mismatch | The secret signs with a different key than the version requires | Land the rotation properly (above). **Never** edit the registry to make it pass. |
| `notarytool` rejects | Apple found a signing/entitlement problem | `xcrun notarytool log <submission-id> --keychain-profile CoreTend-Notary`. Fix, re-tag a new patch version. |
| Apple timeout / outage | Notarization did not complete | Re-run the job. Nothing was published; the tag stays valid. |
| `verify-published-artifacts` fails | The uploaded bytes are not what was built and verified | The release is still a **draft** — delete the draft, fix, re-tag. No user saw anything. |
| Draft exists, job failed | Assets uploaded, publication never happened | `gh release delete v<version> --yes` then re-tag, or fix and re-run. A draft is not public. |
| Tag pushed, pipeline red | The tag exists but nothing was published | Fix on `main`, then release a new patch version. Do not move an existing tag: it would silently change what a version means. |
| Release published but wrong | Bytes are public | Do not delete. Publish a corrected patch version and mark the bad one clearly in its notes; deleting breaks anyone who already has the URL. |
| Site shows the old version | `published-release.json` not synced | `Scripts/sync-published-release.sh`, commit, push, redeploy. |
| Certificate expired | Developer ID validity ended | Issue a new Developer ID Application certificate, install on the runner, update `CORETEND_DEVELOPER_ID_APPLICATION` if the string changed. Already-notarized releases keep working: notarization outlives the certificate. |
| Moving to a new Mac | Signing identity is machine-bound | The Developer ID private key is non-exportable by design. Issue a new certificate on the new Mac, re-register the runner, re-store the notary profile, update the secret. |

The workflow is safe to re-run: every step before publication is idempotent,
and publication itself only flips an existing draft.

---

## What is deliberately not automated

- **Tagging.** A human decides a release exists. Everything after is automatic.
- **Clearing an advisory banner.** It must follow a verified public release, not
  a hopeful one.
- **Deleting a published release.** Never automatic, and rarely right.
