<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Minisign key rotation — completed record

**Status: DONE.** Executed for the `v1.2.0-beta.1` release. This is the
canonical historical record; it supersedes the earlier analysis draft
(`MINISIGN_ROTATION_PLAN.md`, removed).

> **Landed on the stable line at `v1.0.1`.** The key changed in the GitHub
> Actions secret at rotation time, but only the `v1.2` branch received the
> public half; `main` kept publishing `A399E8FD75C1719E` as
> `Configuration/minisign.pub` while CI signed with `F8473FB09E1DB730`. Any
> stable release would have failed release.yml's own "verify before
> publishing" step. `Scripts`-side proof: the `Minisign preflight` workflow.
> So the boundary is by *release date*, not by branch:
> **through `v1.0.0` → `A399E8FD75C1719E`; `v1.0.1` and later →
> `F8473FB09E1DB730`.**

## What changed

| | Previous | Current |
|---|---|---|
| Minisign key ID | `A399E8FD75C1719E` | `F8473FB09E1DB730` |
| Public key file | `Configuration/minisign-A399E8FD75C1719E.pub` (kept) | `Configuration/minisign.pub` + `Configuration/minisign-F8473FB09E1DB730.pub` |
| Signs | releases through `v1.0.0` | `v1.0.1`, `v1.2.0-beta.1` and every later release |
| Role now | historical verification key | current release-signing key |

Apple **Developer ID Application** identity
(`Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)`) and Apple
notarization are **unchanged**. Only the supplemental Minisign key changed.

## Why

The private key for `A399E8FD75C1719E` still exists
(`~/.minisign/minisign.key`, and a named backup copy), but its password could
no longer be unlocked and was not recoverable from the login keychain, `.env`
material, the encrypted DevArchive, or any password store. Without the
password the key cannot sign new releases.

This is a **key-custody problem, not a compromise.** There is no evidence the
previous private key was ever exposed. `v1.0.0` and earlier are not affected
and remain verifiable with `A399E8FD75C1719E`.

## Trust surfaces updated for the rotation

- `Configuration/minisign.pub` → `F8473FB09E1DB730`; old key preserved as
  `Configuration/minisign-A399E8FD75C1719E.pub`; new key also stored explicitly
  as `Configuration/minisign-F8473FB09E1DB730.pub`.
- `Documentation/SIGNING_NOTARIZATION.md` — "Minisign key history" section.
- `SECURITY.md` — "Release signing" section with the key-history table.
- `Documentation/RELEASE_STATE.md` — rotation section; the `v1.0.0` entry now
  names `A399E8FD75C1719E` explicitly as its verification key.
- `Documentation/CHANGELOG.md` — Security note under `1.2.0-beta.1`.
- `Release/Notes/1.2.0-beta.1.en.md` / `.fr.md` — signing section rewritten.
- `Website/index.html` — "How do I verify the download?" answer carries the
  key history (EN + FR).
- `Release/latest.template.json` — `minisignKeyId: "F8473FB09E1DB730"`, which
  flows into the generated `dist/latest.json`.
- GitHub `v1.2.0-beta.1` release — publishes the new `minisign.pub`
  (`F8473FB09E1DB730`) as an asset. The `A399E8FD75C1719E` public key stays
  available from the `v1.0.0` release assets and from this repo.

## Verification performed

- **F847 self-test:** signed a disposable file with the `F8473FB09E1DB730`
  private key and verified it with the `F8473FB09E1DB730` public key — PASS.
  The same signature is correctly **rejected** by the `A399E8FD75C1719E`
  public key (key-ID mismatch).
- **Historical chain intact:** `v1.0.0` `SHA256SUMS` + `SHA256SUMS.minisig`
  still verify against `A399E8FD75C1719E`. The rotation did not rewrite or
  invalidate any published release.
- `v1.2.0-beta.1` `SHA256SUMS` is signed with `F8473FB09E1DB730` and verifies
  against the published `minisign.pub`.

## Key custody

Both keypairs are preserved under unambiguous filenames in
`~/CoreTend-Backups/minisign/` (directory mode `700`, private keys mode
`600`); neither key was overwritten:

- `coretend-minisign-A399E8FD75C1719E.{key,pub}` — historical.
- `coretend-minisign-F8473FB09E1DB730.{key,pub}` — current.

`~/CoreTend-Backups/minisign/KEYS.md` is the metadata-only inventory (key ID,
purpose, effective range, status — no passwords).

The `F8473FB09E1DB730` password is in the login keychain
(`security find-generic-password -a coretend-minisign -s CoreTendMinisign`)
and in GitHub Actions secrets (`MINISIGN_SECRET_KEY` / `MINISIGN_PASSWORD`,
which already held this key). **Human follow-up:** confirm the
`F8473FB09E1DB730` password is also stored in the maintainer's synchronised
password manager, and that the private key is included in the encrypted
off-Mac backup set.
