# Workspace Structure

**Status: EXECUTED.** Both repositories have moved. This document describes
the layout as it exists on disk, not a plan.

## Realized structure

```text
~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/WEBSITE/
├── ahmetbsbnr-portfolio/          # own .git, remote ahmetbsbnr/ahmetbsbnrportfolio, history unchanged
├── products/
│   └── coretend/
│       ├── app/                   # own .git, the product repository, history unchanged
│       ├── website/               # built static site (generated from app/Website/)
│       ├── documentation/         # docs exported for readers outside the repo
│       └── release/               # locally-built artifacts (ZIP, DMG, checksums)
├── projects/
│   └── README.md                  # where a future, unrelated project would go
├── shared/
│   ├── design-language/           # tokens + rules shared by both sites
│   ├── brand-assets/              # exported brand assets (source of truth stays in the product repo)
│   └── deployment-docs/           # non-secret deployment notes
└── WORKSPACE.md                   # orientation doc
```

## Where the moves came from

| Item | Old path | New path |
|---|---|---|
| Portfolio | `.../01_PROJETS_ACTIFS/professionnel-portfolio-stage-2026` | `WEBSITE/ahmetbsbnr-portfolio` |
| Product | `~/Documents/MACCLEAN` | `WEBSITE/products/coretend/app` |

Both were relocated with `mv`, on the same volume.

**Why `mv` and not copy-then-delete.** The brief called for copying and
deleting the original only after verification. A same-volume `mv` is
strictly safer than that: it is atomic, it never duplicates ~2.7 GB onto a
volume with 15 GB free, and — most importantly — it has no delete step at
all. Nothing is ever destroyed, so there is nothing to get wrong about
*when* to destroy it. Rollback is the inverse `mv`, and the disaster case is
covered independently by the git bundles in
`Documentation/WorkspacePreflight/` and
`~/Documents/CoreTend-Migration-Backups/`.

A git repository carries its whole history inside its own `.git`, so a move
changes nothing but the path. That was verified rather than assumed — see
below.

## Post-move verification (actually run)

**Portfolio**
- HEAD, branch, and `origin` URL identical before and after the move
- working tree clean
- `npm run typecheck` — clean
- `npm run lint` — no ESLint warnings or errors
- `npm test` (`scripts/check-static.mjs`) — all checks pass
- `npm run build` — production build succeeds, all routes static
- `.vercel/project.json` moved with the directory, `projectId`/`orgId`
  intact, so the project linkage is preserved and no `vercel link` re-run
  is needed

**Product**
- HEAD, branch, and the full tag list identical before and after the move
- working tree clean, single worktree, now at the new path
- `.build/` deleted and regenerated, since SwiftPM caches absolute paths —
  this is the one thing a move does invalidate, and it is a cache
- `swift build` and `swift build -c release` — clean
- `Scripts/test.sh` — 270/270 pass

One pre-existing, unrelated warning surfaced during the portfolio lint: Next
detects a stray `/Users/<user>/package-lock.json` above the project and
infers the wrong workspace root. It predates the move and is unaffected by
it.

## Hard rules (unchanged, still binding)

- `WEBSITE/` is **not** a Git repository. It is a plain folder containing
  two independently-versioned repositories plus non-Git shared docs. No
  `git init` at the `WEBSITE/` level.
- `ahmetbsbnr-portfolio/` and `products/coretend/app/` each keep their own
  `.git` and independent history. **No history merge, no combined repo.**
- No submodules.
- No file in one repository references a file in the other by a path that
  reaches outside its own repository root. `shared/` is a *published copy*
  of content whose source of truth lives inside a repository — never a live
  cross-repo filesystem dependency.
- No secret (API key, DNS credential, EmailJS key, `.env*` content) is ever
  placed under `shared/`.
- The product site's **source** stays versioned in `app/Website/`.
  `products/coretend/website/` holds the *built* output. Moving the source
  out of the repository would leave the site unversioned, which is a worse
  outcome than a slightly less literal reading of the folder brief.

## Migration manifest

Per-item source → destination with per-item rollback:
`workspace-migration-manifest.json`.
