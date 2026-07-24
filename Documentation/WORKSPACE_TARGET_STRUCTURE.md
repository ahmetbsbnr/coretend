# Workspace Target Structure

Documentation only — nothing below has been created on disk this phase.
No folder has been moved. This describes the destination, not a completed
migration.

## Current state (verified this session)

- Portfolio: `~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/professionnel-portfolio-stage-2026` (own `.git`, remote `ahmetbsbnr/ahmetbsbnrportfolio`)
- Product: `~/Documents/MACCLEAN` (own `.git`, no remote configured yet)
- Both live under `~/Documents`, in different, unrelated subtrees today —
  there is no existing shared workspace parent.

## Target structure

```text
<WORKSPACE_PARENT>/
└── WEBSITE/
    ├── portfolio/                      # professionnel-portfolio-stage-2026, own .git, unchanged history
    ├── products/
    │   └── <approved-product-slug>/    # MACCLEAN's current content, own .git, unchanged history
    ├── shared/
    │   ├── design-language/            # tokens/typography/spacing docs shared by both sites (see CROSS_SITE_DESIGN_LANGUAGE.md)
    │   ├── brand-guidelines/           # logo usage, voice, do/don't — populated after a name is approved
    │   └── deployment-docs/            # non-secret deployment notes (Vercel project linkage docs, DNS runbooks with secrets redacted)
    ├── archives/                       # superseded audit ZIPs, historical snapshots, old AuditPackages/ output
    └── WORKSPACE.md                    # top-level orientation doc for anyone opening <WORKSPACE_PARENT>/WEBSITE
```

`<WORKSPACE_PARENT>` is deliberately left unresolved — the phase brief
does not specify it, and choosing a real path is a decision that affects
existing shell aliases, editor workspaces, and any local automation the
user already has pointed at `~/Documents/MACCLEAN` and the portfolio's
current path. That choice is `BLOCKED_HUMAN`, not assumed here.

`<approved-product-slug>` similarly cannot be filled in — it is the output
of the brand-clearance process (`BRAND_NAME_CLEARANCE.md`), which is
currently `BLOCKED_HUMAN`.

## Hard rules for the eventual migration

- `WEBSITE/` itself is **not** a Git repository. It is a plain folder that
  contains two independently-versioned repositories plus non-Git shared
  docs. No `git init` at the `WEBSITE/` level.
- `portfolio/` and `products/<slug>/` each keep their own `.git` directory
  and independent commit history. **No history merge, no combined repo,
  ever**, per the phase's explicit constraint.
- No Git submodule is introduced unless a future, separately-documented
  decision explicitly calls for one — the default is: no submodules.
- No file in one repo references a file in the other by absolute or
  relative path that reaches outside its own repo root. `shared/` is
  copied into each repo's own build process (or referenced by a
  documented, versioned copy step) — never a live cross-repo filesystem
  dependency.
- No secret (API key, DNS credential, EmailJS key, `.env*` content) is
  ever placed under `shared/`. `shared/deployment-docs/` holds process
  documentation only, with any real secret redacted the same way
  `Configuration/PublicIdentity.local.json` and `.env.local` already are
  today (gitignored, never committed).
- No Vercel project configuration is moved or re-linked before the new
  paths are verified working — `.vercel/project.json` links a local
  folder to a specific Vercel project by ID; moving the folder without
  re-running `vercel link` (or preserving the exact linkage) risks
  deploying to the wrong project or losing the link entirely.
- The old locations (`~/Documents/MACCLEAN`,
  `.../01_PROJETS_ACTIFS/professionnel-portfolio-stage-2026`) are **not
  deleted** until the new location is confirmed working end-to-end
  (build, test, deploy-dry-run) — see `WORKSPACE_ROLLBACK_PLAN.md`.

## Migration manifest

The concrete file/folder move list (source → destination, per top-level
item, with a rollback note per item) lives in
`workspace-migration-manifest.json` — kept separate from this structural
description so the manifest can be regenerated without rewriting the
narrative rules above.
