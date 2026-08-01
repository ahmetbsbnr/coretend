# CoreTend Gold Master Status

Last updated: 2026-08-01T21:15:00+03:00

This is the durable delivery journal for the CoreTend gold-master work. It records verified state only. A blank preview or production field means that gate has not passed yet.

## Git checkpoint

- Starting CoreTend HEAD: `3eb23e7c474a8dce9dc269e5f188d08d901a94c8`
- Starting portfolio HEAD: `e813aefa7738d2d855ea003c560907b7d2d722a5`
- Working branch in both repositories: `feat/coretend-gold-master`
- CoreTend local and remote `main`: verified equal before the branch was created
- Portfolio local and remote `main`: verified equal before the branch was created
- Both starting worktrees: clean
- Starting stashes: none
- Starting secondary worktrees: none

## Verified backups

Workspace-relative backup directory: `_backups/coretend-gold-master-20260801T173042Z/`

| Repository | Bundle | SHA-256 | Verification |
| --- | --- | --- | --- |
| CoreTend | `coretend-all.bundle` | `40e18c5bd302d1b7c100bb4ea40f8527177c8b8f6a532e929e691f3f3ed02349` | complete history, 31 refs |
| Portfolio | `portfolio-all.bundle` | `f725ebc70770a512e9c2ac470d1484bbf00496508ff5c0d841670f2c6ac7fa5e` | complete history, 13 refs |

The backup directory contains a restoration README. No separate worktree patches were needed because both repositories had no staged, unstaged, or untracked changes.

A second verified safety checkpoint was created before continuing the recovered
local work: `_backups/coretend-gold-master-20260801-2148/`. It contains complete
CoreTend and portfolio bundles, bundle-verification reports, binary worktree and
index patches, untracked-file archives, SHA-256 sums, and `RESTORE.md`. The
CoreTend worktree patch is non-empty and its untracked archive contains the
release, fixture, site-build, and test work recovered on this branch. The
portfolio remained clean.

## Gold-master reference

- Source supplied for this delivery: `coretend-site.html`
- Immutable comparison copy: `_references/coretend-site-gold.html` relative to the workspace root
- Size: `94,546` bytes
- SHA-256: `c317df39e9253884da8786eea6d28547c2d08561f71a95a5305d75bd6f680bf1`
- Copy verification: byte-for-byte comparison passed

## Completed gates

- [x] Locate both canonical repositories
- [x] Verify local branches and starting HEADs
- [x] Verify remote default branches without changing local refs
- [x] Confirm clean tracked and untracked state
- [x] Inspect stashes and secondary worktrees
- [x] Create and verify full Git bundles
- [x] Record bundle checksums and restoration commands
- [x] Preserve the supplied gold master without modification
- [x] Create and push `feat/coretend-gold-master` in both repositories
- [x] Deploy an untouched staging copy of the gold master
- [x] Establish initial desktop and mobile gold-master baselines
- [ ] Reconcile gold-master claims with released product facts
- [ ] Achieve app/site simulation parity
- [ ] Export and gate shared design tokens
- [ ] Complete bilingual, theme, accessibility, responsive, and performance gates
- [ ] Complete portfolio parity and deployment gates
- [ ] Complete application, capture, repository, workspace, CI, Security, and release gates

## Commits

- `c4f4854` `docs: establish gold master checkpoint`
- `682535a` `feat: gate public release facts and demo fixtures`

## Test evidence

| Scope | Command or check | Result |
| --- | --- | --- |
| CoreTend remote state | `git ls-remote --symref origin` | passed |
| Portfolio remote state | `git ls-remote --symref origin` | passed |
| CoreTend bundle | `git bundle verify` | passed |
| Portfolio bundle | `git bundle verify` | passed |
| Gold-master copy | `cmp` and `shasum -a 256` | passed |
| Public release gate | `python3 Scripts/test-public-release-gate.py` | 14 passed |
| Demo fixture validation | `python3 Scripts/check-demo-fixtures.py` | passed |
| Demo fixture tests | `python3 -m unittest discover -s Tests/DemoFixturesValidatorTests -p 'test_*.py'` | 6 passed |
| Gold desktop baseline | 1440x900 light, SHA-256 `1e8d0058f97b15707927a92fbb6c62ec072fcc3fdb2e9207dfa261532ab88ce7` | captured |
| Gold mobile baseline | 430x932 light, SHA-256 `d30f4abfb857d1e2188abd226367947bbe62671b0f2b2502b83720cb006bfe1b` | captured; horizontal overflow visible |

No product, site, application, accessibility, or deployment test is marked passed at this checkpoint.

## Deployment URLs

- Gold-master staging preview: `https://coretend-d1v2pne45-ahmets-projects-ed32c752.vercel.app`
  (`dpl_HGAGeFg9bzSazzCaqvuK3SwhwquW`, READY). Vercel Deployment Protection
  currently returns an SSO 302 to unauthenticated requests, so public preview
  inspection is still an open gate.
- Product-site branch preview: pending
- Product-site production: not changed
- Portfolio branch preview: pending
- Portfolio production: not changed

## Known defects and unresolved facts

- The supplied HTML still contains the demonstrative checksum `9f2c41a8...`; it must not reach the final production site.
- The supplied HTML uses Google Fonts at runtime; the canonical repository already has self-hosted Archivo and IBM Plex Mono assets.
- The supplied HTML contains product statements, metrics, example paths, Gatekeeper copy, download targets, and networking claims that remain unverified against the released application.
- The current canonical website is a separate generated bilingual static site; its behavior and deployment topology must be compared before replacement.
- The production download asset and the known release checksum must be fetched and independently verified before either is published in site copy.
- The recovered gold integration still rotates the full logo in the header and hero; this directly violates the independent-arc motion gate.
- The recovered gold integration uses `data-lang-link` in markup but looks for `data-lang-btn` in JavaScript; route-aware language switching is not yet valid.
- The 430x932 baseline visibly overflows horizontally and crops the hero controls and copy.

## Next gate

Replace global logo rotation with independent centered SVG arcs, correct the
route-aware FR/EN mechanism and mobile overflow, then build the isolated public
output and run the first route/canonical/link crawl before deploying the adapted
branch preview.
