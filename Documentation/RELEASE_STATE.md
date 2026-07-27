<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Release State

## Current post-release checkpoint — 2026-07-27

No application source changed, so no 0.9.1 binary is being prepared. The
public 0.9.0 assets remain immutable and were downloaded again: ZIP and DMG
hashes match `SHA256SUMS`, `unzip -t` and `hdiutil verify` pass, and
`latest.json` is valid. New website/media work must not be described as part of
the downloadable 0.9.0 binary.

The branch now contains three approved media sources (Smart Care screenshot,
menu-bar screenshot, and genuine Gatekeeper clip) plus local site changes. Nothing
in this checkpoint has been pushed, merged, deployed, or attached to the
release yet. `v0.9.0` remains annotated and points to `a6aa3bf`.

## Local presentation work after v0.9.0 — 2026-07-27

The binary release remains exactly the annotated `v0.9.0` tag at
`a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`. The current branch contains
post-release website, help, documentation and media-validation work; none of
it is represented as part of the downloadable 0.9.0 binary.

The public ZIP, DMG, `latest.json` and `SHA256SUMS` were downloaded again and
validated. Their sizes, hashes, archive integrity and manifest values match
the production state below. The available binary is arm64, requires macOS 14
or later, is unsigned by Developer ID and is not notarized.

This historical paragraph is superseded by the checkpoint above: two supplied
media items subsequently passed full privacy review and were integrated.

## Production state — verified 2026-07-27

The annotated `v0.9.0` tag is public and still resolves to
`a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`. GitHub hosts a non-draft
prerelease at
`https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.0` with the ZIP,
DMG, `latest.json`, and `SHA256SUMS` assets. GitHub licence detection remains
`NOASSERTION` / `Other`; no licence change was made during deployment.

Production is served by Vercel project `ahmets-projects-ed32c752/coretend`,
deployment `dpl_GcQWq468fFGa6zcaLWLx1tinVhGg`, at
`https://coretend.ahmetbsbnr.com`. DNS, HTTP-to-HTTPS redirection, TLS,
security headers, public routes, asset downloads and checksums were verified.
Production indexing is enabled; `robots.txt` allows crawling and references
the public sitemap.

Downloaded artifact verification reproduced the recorded sizes and hashes:
ZIP 2833085 bytes / `1d224b7655cfbcb15b5f9a37302c454775fae34d17d7f010f8c9ab026999b7d8`;
DMG 5192666 bytes /
`f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d`.
`SHA256SUMS`, ZIP integrity, DMG integrity and `latest.json` validation pass.
The isolated post-deployment gate reports **55 PASS, 0 FAIL,
2 NOT_APPLICABLE, 0 HUMAN_ACTION_REQUIRED**.

The prepublication snapshot below is historical and is superseded by this
section. No branch commit was pushed as part of the deployment.

Snapshot at commit `a6aa3bf`, tag `v0.9.0` (local only). Written 2026-07-27.

## Version

**0.9.0**, unsigned public beta. Not 1.0.0; not claimed as signed or
notarized anywhere. The launch gate refuses any 1.x while this holds.

## Strategy: unsigned public beta

`security find-identity -v -p codesigning` reports **0 valid identities**. A
Developer ID requires a paid Apple Developer Program membership, out of scope.
That fixes the outcome — see `DECISIONS.md` D-N6.

## Artifacts — verified at HEAD `a6aa3bf`

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `CoreTend-0.9.0-arm64-unsigned.zip` | 2833085 | `1d224b7655cfbcb15b5f9a37302c454775fae34d17d7f010f8c9ab026999b7d8` |
| `CoreTend-0.9.0-arm64-unsigned.dmg` | 5192666 | `f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d` |

Verification commands and results, this exact build:

- `unzip -t Release/CoreTend-0.9.0-arm64-unsigned.zip` → **No errors detected.**
- `hdiutil verify Release/CoreTend-0.9.0-arm64-unsigned.dmg` → **checksum is VALID.**
- `(cd Release && shasum -a 256 -c SHA256SUMS)` → **ZIP: OK, DMG: OK, latest.json: OK.**
- `python3 -m json.tool Release/latest.json` → valid JSON.
- ZIP contains `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` (Apache-2.0 §4).

`Release/latest.json` — key fields: `version: 0.9.0`, `releaseTag: v0.9.0`,
`sourceCommit: a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`, `treeState: clean`,
`signed: false`, `notarized: false`, `releasable: true`.

`Release/latest.json`, `Release/SHA256SUMS` and `dist/` are **generated,
gitignored, never committed.**

## Signing and notarization

| Property | Value | How verified |
|---|---|---|
| Signing identities | 0 | `security find-identity -v -p codesigning` |
| Built app signature | `Signature=adhoc`, `TeamIdentifier=not set` | `codesign -dv build/CoreTend.app` |
| Signature integrity | valid on disk | `codesign --verify --deep --strict` |
| Gatekeeper | **rejected** | `spctl --assess --type execute` |
| Notarization | not performed, not possible without a Developer ID | — |

The `spctl` rejection is the **expected, correct** result for this build. It is
recorded as a rejection, never reframed as a pass.

## GitHub

- Repository: `github.com/ahmetbsbnr/coretend`, public, default branch `main`
  at `b2bca85` — verified via `gh api repos/ahmetbsbnr/coretend`.
- Private vulnerability reporting: **enabled**.
- Secret scanning: **enabled**. Push protection: **enabled**.
  Dependabot security updates: **enabled**.
- `secret_scanning_non_provider_patterns` and `secret_scanning_validity_checks`:
  disabled — optional hardening, never claimed enabled.
- Licence detection: was `NOASSERTION`; `LICENSE` restructured to the verbatim
  Apache-2.0 text to fix this (commit `45ed83b`). **Unconfirmed against the
  live API** — nothing has been pushed since the change. Verify with
  `gh api repos/ahmetbsbnr/coretend --jq .license.spdx_id` after pushing.

## Tag

`v0.9.0`, annotated, **local only, never pushed**. Points at `a6aa3bf`
(verified: `git rev-parse v0.9.0^{commit}` = `git rev-parse HEAD`).

No `v0.9.0` or `0.9.0` tag existed before this session created one. It was
moved once, from `a43d644` to `a6aa3bf`, entirely locally, to fix a bug found
in the gate that was checking it (`git rev-parse` on an annotated tag returns
the tag object's own sha, not the commit sha — the gate now dereferences with
`^{commit}`). It has never been pushed, so this was not "silently moving an
existing published tag" — it is local iteration before publication.

## GitHub prerelease

**Not created.** Exact commands, once authorised:

```sh
git push origin v0.9.0
gh release create v0.9.0 \
  --title "CoreTend 0.9.0 — Public Beta" \
  --prerelease \
  --notes-file Release/Notes/0.9.0.en.md \
  Release/CoreTend-0.9.0-arm64-unsigned.zip \
  Release/CoreTend-0.9.0-arm64-unsigned.dmg \
  Release/latest.json
```

## Vercel / site deployment

**Not performed.** Vercel CLI authenticated as `ahmetbsbnr`; no project
created, no domain added. `Website/vercel.json` generated and ready (headers
per `WEBSITE_SECURITY.md`). Exact sequence in `WEBSITE_DEPLOYMENT.md`.

## DNS / SSL

`coretend.ahmetbsbnr.com` **already resolves** (`dig +short` returns two
addresses) but **returns HTTP 404** — the name points somewhere real, the site
is not deployed there yet. Neither DNS nor SSL is marked complete; both require
the deploy first, then re-verification with `dig`, `curl -sI`, and
`openssl s_client … | openssl x509 -noout -dates`.

## Public download

**Not available.** No GitHub release exists, so `Website/en/download.html`
correctly shows "prepared, not yet published" with no download link — verified
by regenerating the site against the current manifest.

## Proof summary

| Item | Result | Evidence |
|---|---|---|
| Tests | 296 / 58 suites, 0 failures | `bash Scripts/test.sh` |
| Debug build | clean | `swift build` |
| Release build | clean | `swift build -c release` |
| Final launch gate | 52 PASS, 0 FAIL, 2 NOT_APPLICABLE, 2 HUMAN_ACTION_REQUIRED | 3 runs, identical, exit 0 each |
| ZIP | valid | `unzip -t` |
| DMG | valid | `hdiutil verify` |
| Checksums | match | `shasum -a 256 -c SHA256SUMS` |
| Repo clean | yes | `git status --porcelain` empty |
| Push performed | **no** | `git log --oneline origin/main` unchanged at 1 commit |
| Deploy performed | **no** | no Vercel project exists |
| Secrets | none found in tracked files | `check-private-data.sh` PASSED |

## Remaining human actions

1. `git push origin v0.9.0`
2. `gh release create v0.9.0 --prerelease …` (command above)
3. Verify downloads publicly (URL, HTTP status, checksum match)
4. `cd Website && vercel deploy --prod`
5. `vercel domains add coretend.ahmetbsbnr.com`, then create the CNAME at the
   registrar for `ahmetbsbnr.com` — the one step outside this environment
6. Verify DNS/TLS for real, then flip `siteIndexable` to `true` and regenerate
7. Confirm GitHub reports `Apache-2.0` after the push
