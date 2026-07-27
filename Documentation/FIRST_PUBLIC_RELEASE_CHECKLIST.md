# First Public Release Checklist

v0.7.0 "Public Distribution" passed its automated gate check (see
`Documentation/PUBLIC_RELEASE_READINESS.md` and the CHANGELOG 0.7.0
entry) entirely inside this development environment. Everything below
is **human-only**, cannot be automated or pre-decided by an agent, and
has **not** been executed. Do these in order; each depends on the ones
before it.

1. **Finalize identity** — DONE. `publisherOfRecord` is set in the
   gitignored `Configuration/PublicIdentity.local.json`, and
   `maintainerGitHub`/`repository`/`developerDomain` are confirmed.
   `legalAddress` stays `null` on purpose (LCEN Art. 6 III-2). Real
   personal data was never written to the example file, and no surname
   was invented.
2. **Security contact** — DONE. `SECURITY.md`, `CODE_OF_CONDUCT.md`,
   `PRIVACY.md` and the website Legal/Privacy pages route to GitHub
   private vulnerability reporting, verified live 2026-07-27. No email
   address was invented.
3. **Verify legal mentions** — re-run `Scripts/check-placeholders.sh`
   after steps 1-2; it must report zero remaining tokens.
4. **Inspect git history** — before making the repo public, review the
   full commit history (not just the current tree) for anything that
   shouldn't be public: personal paths, secrets, accidental large
   binaries.
5. **Inspect screenshots** — replace the website's placeholder
   screenshot box and fill in `Documentation/VisualAudit/After` on a
   machine with an attached display (`Scripts/capture.sh`); this
   sandbox has no display, a standing limitation since v0.3.0.
6. **Test the ZIP** on a clean, separate Mac (not this dev machine) —
   download-equivalent copy, extract, first-launch Gatekeeper flow,
   confirm `Documentation/INSTALL_UNSIGNED.md` matches what a real user
   sees.
7. **Test the DMG** the same way — mount, drag to Applications, first
   launch.
8. **Verify SHA-256** independently on that second machine using only
   published values, not values copied from this checkout.
9. **Create the GitHub repository** (`ahmetbsbnr/coretend` per
   `PublicIdentity.example.json`) — not done by this agent, per the
   session's safety rules.
10. **Push** `main` (and this branch, once merged) to the new remote.
11. **Enable repo security settings** — secret scanning, Dependabot
    alerts, branch protection on `main`.
12. **Create the release tag** (`v0.7.0`) on the real remote.
13. **Run the release workflow** — `.github/workflows/release-draft.yml`
    is `workflow_dispatch`-only by design; trigger it manually from the
    Actions tab.
14. **Download the workflow's artifacts** and diff their checksums
    against a fresh local build to confirm CI produced the same thing.
15. **Retest** the CI-built ZIP/DMG exactly like steps 6-8, since the
    CI runner is a different machine than this dev environment.
16. **Create a GitHub prerelease** (not a full release) from the
    verified artifacts, marked prerelease, unsigned/non-notarized
    called out in the release body.
17. **Deploy the website** (`Website/`) to the real domain once it
    exists — this agent explicitly did not touch DNS or any deploy
    target.
18. **Test the live download** end-to-end from the deployed site as an
    anonymous outside user would.
19. **Announce the beta** once 1-18 are all confirmed working.

None of the above were executed by this session. See
`Documentation/HUMAN_BLOCKERS.md` for the underlying open items each
step resolves.
