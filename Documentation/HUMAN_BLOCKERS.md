# Human Blockers

Things that cannot be automated and require a real decision by the
project owner before public release. Nothing below should block the
automatable work in this phase — it's tracked here so it isn't lost.

## RESOLVED

Values and acts that are no longer open. Token names are written without
brackets throughout this file — the bracketed form is what the placeholder
gates grep for, and this document must not block the release it tracks.

| Item | Resolution |
|---|---|
| GitHub maintainer handle | `ahmetbsbnr` |
| Public repository | `ahmetbsbnr/coretend` (`https://github.com/ahmetbsbnr/coretend`) — **created and public**, default branch `main` at `b2bca85` |
| Production domain / subdomain | `ahmetbsbnr.com` / `coretend.ahmetbsbnr.com` (configured; not yet deployed) |
| Security contact (`SECURITY_CONTACT_TO_DEFINE`) | **GitHub private vulnerability reporting**, `github.com/ahmetbsbnr/coretend/security/advisories/new`. Verified live 2026-07-27. No email address was invented. |
| Legal identity / publisher of record (`LEGAL_NAME_TO_DEFINE`, `PUBLISHER_OF_RECORD_TO_DEFINE`) | `publisherOfRecord` in the gitignored `Configuration/PublicIdentity.local.json` — the given name the owner already publishes on their own GitHub, plus their handle and domain. **No surname was inferred** from the filesystem path or any local metadata. |
| Legal address (`LEGAL_ADDRESS_TO_DEFINE`) | **Deliberately withheld**, `legalAddress` is `null`. LCEN Art. 6 III-2 permits a non-professional publisher to withhold a personal address provided the host holds their identity; Vercel Inc. does. Stated openly on the page. See `LEGAL_IDENTITY_DETERMINATION.md`. |
| Approval to create the public GitHub repository | Done — repository is public |
| Approval to push to the public repository | Done — `origin/main` at `b2bca85`, built by the sanitised export |
| Apple Developer Program membership | **Enrolled**, Team `NSCUV5G738` (Apple ID `bas.ahmet5703@gmail.com`) |
| Code signing identity | **Installed 2026-08-31** — `Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)` in the login keychain, issued (G2 Sub-CA) from the pre-existing `Configuration/DeveloperID/developerID_CSR.csr`. `security find-identity -v -p codesigning` now lists it. |
| Notarization | **Proven 2026-08-31** — `Scripts/sign-and-notarize.sh` run for real against `0.9.1-rc.5`; app + DMG signed, notarized (both `Accepted`), stapled; `spctl --assess` → `accepted / Notarized Developer ID`. Credential = `notarytool` keychain profile `CoreTend-Notary` (App Store Connect API key, `.p8` in gitignored `Configuration/DeveloperID/`). |
| Publishing the first **signed** release | **Done 2026-09-03** — `v1.0.0` published signed, notarized, stapled, Minisign-signed; `Configuration/published-release.json` records `signed: true`, `notarized: true`. See `Documentation/RELEASE_STATE.md`. |
| Final screenshots for the website | **Done 2026-09-04** — 44 native captures (11 modules × EN/FR × light/dark), accepted by maintainer. See `Documentation/HUMAN_QA_REPORT.md`. |
| Multi-Mac / multi-macOS-version testing | **Done 2026-09-04** — maintainer attestation, second Mac and a different supported macOS version. See `Documentation/HUMAN_QA_REPORT.md`. Exact hardware/OS identifiers were not supplied. |

## OPEN

| Blocker | Why it needs a human | Where it is tracked |
|---|---|---|
| DNS record for `coretend.ahmetbsbnr.com` | Requires registrar access | `RELEASE_STATE.md` |
| ~~Approval to deploy the website~~ **DONE** | Site is public, FR/EN routes live, version/portfolio synced with `v1.0.0`. Superseded by the DNS row above for the custom subdomain specifically. | `Documentation/WEBSITE_DEPLOYMENT.md`, `RELEASE_STATE.md` |
| ~~Publishing the first GitHub prerelease~~ **DONE** | Superseded — `v1.0.0` is published as a public, non-prerelease, non-draft stable release. | `RELEASE_STATE.md` |
| ~~Trademark attorney review~~ **DONE 2026-09-02** | A trademark attorney reviewed the `COREXTEND` adjacency (per the maintainer) and found no conflict — two entirely separate products, two entirely separate meanings. Name cleared for the 1.0 release. A `®` filing is still a separate future step. | `Documentation/CORETEND_TRADEMARK_SCREENING.md`, `BRAND_CONFLICT_REGISTER.md` |

Publishing the first signed release, final website screenshots, and
multi-Mac/multi-macOS testing are now RESOLVED above (2026-09-03/04) —
moved out of this table.

Token resolutions are recorded centrally in
`Documentation/PUBLICATION_PLACEHOLDERS.md`.

## The placeholder mechanism is still armed

Resolving those values did not disarm the gate.
`Configuration/PublicIdentity.example.json` still carries bracketed tokens
as its defaults and is the only file excluded from the placeholder scan,
because those defaults *are* the intended visible-failure mode:
`Website/generate.py` reads the example file and overlays the gitignored
`PublicIdentity.local.json` key by key, so if the local file goes missing
the site regenerates with literal tokens rather than a reassuring legal
page over an undefined publisher.

`check-publish-readiness.sh` guards this more strictly than a text scan —
it requires the local file to exist, to contain no `_TO_DEFINE` value, and
to carry a `securityContact`. Generated site HTML is tracked and still
scanned.

The homepage screenshot remains a clearly labeled dev placeholder box. It
is not a bracket token, so the placeholder gate does not catch it; it must
be replaced manually before a production deploy.

## This session: distribution-gate progress (compat audit, ZIP, DMG, checksums, manifest, release notes, CI draft workflow, install guide)

No new placeholder tokens were invented. Maintainer handle, planned repo,
and planned domain — already known values from
`Configuration/PublicIdentity.example.json` — are now marked RESOLVED
above since they're facts, not blockers; the *actions* that use them
(create repo, push, deploy) remain OPEN and unperformed this session, per
the safety rules for this work.

## Open item: Dependabot Swift Package Manager ecosystem support

`.github/dependabot.yml` only enables the `github-actions` ecosystem.
Whether GitHub Dependabot supports a Swift Package Manager ecosystem
entry was not verified this session (no network check performed); rather
than guess at a config key that might silently no-op, this was left as a
documented follow-up in the file itself. Not currently blocking — the
project has zero external SPM dependencies (see
Documentation/DEPENDENCIES.md) — but should be revisited before or when a
real dependency is added.

## v0.7.0 gate session

Version bumped to 0.7.0 "Public Distribution" after an independent
re-verification of all 24 gate criteria (not a re-read of prior
session claims) — see CHANGELOG.md and PUBLIC_RELEASE_READINESS.md.
No blockers were resolved by this session; `Documentation/
FIRST_PUBLIC_RELEASE_CHECKLIST.md` now lists the ordered human-only
steps (identity, security contact, repo creation, push, tag, workflow
run, prerelease, site deploy, announce) still required before any
public release, none of which were performed.
