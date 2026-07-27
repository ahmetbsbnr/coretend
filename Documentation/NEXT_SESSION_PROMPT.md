<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Next Session Prompt

## Current authoritative resume state — 2026-07-27

- Production: `https://coretend.ahmetbsbnr.com`
- Vercel project: `ahmets-projects-ed32c752/coretend`
- Deployment:
  `https://coretend-6gh4uz2bc-ahmets-projects-ed32c752.vercel.app`
  (`dpl_GcQWq468fFGa6zcaLWLx1tinVhGg`)
- GitHub prerelease:
  `https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.0`
- Tag target: `a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`
- Public verification: DNS, HTTPS/TLS, routes, release links, four downloads,
  checksums, ZIP, DMG and manifest all pass.
- Gate: **55 PASS / 0 FAIL / 2 NOT_APPLICABLE /
  0 HUMAN_ACTION_REQUIRED**.
- Production indexing: enabled; no public `X-Robots-Tag: noindex`;
  `robots.txt` and `sitemap.xml` valid.
- GitHub licence detection: still `NOASSERTION` / `Other`; do not change legal
  terms as part of a deployment follow-up.
- No branch commit was pushed and `main` was not changed.
- An empty Vercel project `app` exists from an interrupted upload and has no
  deployments. Remove it only with explicit authorization.

The remainder of this file is the historical prepublication prompt and is
superseded by the state above.

Self-contained resume prompt. Written 2026-07-27 at the end of the 0.9.0
launch phase's local work.

---

You are resuming work on **CoreTend**, a local macOS maintenance utility.

```
cd ~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/products/coretend/app
```

## State

- Branch: `feat/coretend-rebrand-workspace`
- HEAD / last stable commit: `a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`
- Tag `v0.9.0`: **exists locally, points at HEAD, never pushed**
- Working tree: clean
- Tests: 296 / 58 suites, 0 failures (`bash Scripts/test.sh`)
- Builds: Debug and Release both clean
- `bash Scripts/final-launch-gate.sh --expect-version 0.9.0 --expect-head v0.9.0`
  → **52 PASS, 0 FAIL, 2 NOT_APPLICABLE, 2 HUMAN_ACTION_REQUIRED**, exit 0,
  verified identical across three consecutive runs

## Done this phase (local only — verify against `git log`, don't trust this list blindly)

Placeholder tokens resolved and re-verified; version bumped to 0.9.0 with the
version-consistency gate fixed (it could not run at all before — it crashed on
a partial local override instead of overlaying it); licence cross-references
repaired; final security audit with one self-caught and self-fixed leak
(committed the developer's account name, caught by `check-private-data.sh`,
fixed, never pushed); accessibility QA record written, including one
speculative "fix" that was reverted after checking the call site showed it
fixed nothing reachable; site made config-driven — the download page now reads
the real release manifest instead of static prose, and the repository-is-public
claim (now false) was removed; Vercel hosting config generated with the
security headers `WEBSITE_SECURITY.md` specified; a final launch gate written,
with a nondeterminism bug (SIGPIPE under `pipefail`) found and fixed at four
sites; the licence presentation restructured — `LICENSE` is now the verbatim
Apache-2.0 text so GitHub stops reporting `NOASSERTION`, confirmed
byte-identical to the old embedded copy before the change so nothing was
relicensed; the launch gate's `--expect-head` fixed to dereference annotated
tags (`git rev-parse <tag>` returns the tag object's own sha, not the commit
sha).

## Not done — by explicit instruction, not oversight

Nothing was pushed. No GitHub release. No Vercel deploy. No DNS touched.
Every one of these is a deliberate human decision, stated as out of scope for
this phase.

## Next task, in order

1. **Push the tag**: `git push origin v0.9.0`
2. **Create the GitHub prerelease** (exact command in `RELEASE_STATE.md`)
3. **Verify the public download** for real: URL reachable, HTTP status,
   checksum matches
4. **Confirm licence detection**:
   `gh api repos/ahmetbsbnr/coretend --jq .license.spdx_id` → expect
   `Apache-2.0`, not `NOASSERTION`
5. **Deploy the site** (`WEBSITE_DEPLOYMENT.md` has the exact sequence)
6. **Attach DNS** — the one step needing registrar access outside this
   environment
7. **Verify DNS/TLS for real**, then flip `siteIndexable` to `true` and
   regenerate the site

## First command

```sh
cd ~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/products/coretend/app && \
  git status --short --branch && \
  git log -5 --oneline && \
  bash Scripts/final-launch-gate.sh --expect-version 0.9.0 --expect-head v0.9.0
```

## Human blockers

- Registrar access for `ahmetbsbnr.com`, to create the CNAME for
  `coretend.ahmetbsbnr.com`
- Apple Developer Program membership, if 1.0.0 signed is ever wanted (not
  planned for this beta)
- Attorney review before any trademark filing or significant commercial use
  (COREXTEND watch item — see `DECISIONS.md` D-N2, D-N3)

## Remote operations already performed

None this phase. `git log --oneline origin/main | wc -l` is still `1` — the
single sanitised-export commit from a prior phase. That commit's contents are
unrelated to this session's work: the export was already built and pushed
before this phase started, and this phase never re-ran that export.

## Remote operations NOT performed

Tag push, GitHub release, Vercel project creation, Vercel deploy, DNS record
creation, `siteIndexable` flip.

## Hard rules, carried forward

- **Never infer or invent a surname** for the publisher from any technical
  source. Public identity stays "Ahmet" only.
- **Never invent a legal address.** `legalAddress` stays `null` — withheld
  under LCEN Art. 6 III-2, disclosed openly as withheld.
- **Never claim 1.0.0, signed, or notarized.** This is 0.9.0 unsigned beta.
  `spctl` rejection is recorded as a rejection, not reframed as success.
- **Never recommend disabling Gatekeeper system-wide.** Give the per-app
  right-click → Open step only.
- **Never read a gate's exit code through a pipe.** `gate.sh | tail -1` reports
  `tail`'s status. This already caused one bad commit here.
- **Never use `producer | grep -q` inside a gate.** SIGPIPE under `pipefail`
  reports failure on a match, nondeterministically. Capture output, match with
  `case`.
- **Never checkout an orphan branch or reset the working tree** for the export.
  `Scripts/build-public-branch.sh` builds with `commit-tree` against a
  throwaway index instead.
- **Never move a tag that has been pushed**, silently or otherwise. `v0.9.0`
  has only ever existed locally — moving it once during this session, before
  any push, to fix a bug in the check examining it, is not the same thing.

## First-contact caution

Before trusting any claim in this file or in `CONTINUATION.md`, verify it
against real source — `git log`, `git status`, and rerunning the gates — rather
than accepting the prose. That discipline is what caught the account-name leak,
the nondeterministic gate, and the tag-dereference bug in this phase.
