# Publication Audit — v0.6.0 Open Source Foundation

Date: 2026-07-20 (session start of the Open Source Foundation phase).
Scope: full working tree at HEAD `b82558e` before any 0.6.0 work.

## Method
- `grep -rIl "/Users/$(id -un)"` across `*.swift *.md *.json *.sh`
- `grep -rIlE` for common secret patterns (api_key/secret/password/token
  assigned to a literal) across `*.swift *.sh *.json`
- `find` for `*.env*` files
- `find` for `*.sqlite*` / `*.db` files
- `git remote -v` (confirm no push destination configured)
- Manual review of `Documentation/*` for personal data, real scan logs,
  real quarantine data, screenshots.

## Findings

| Category | Result |
|---|---|
| Hardcoded secrets/tokens/passwords in source | None found |
| `.env` files | None found |
| Absolute personal paths in tracked source (`*.swift/*.md/*.json/*.sh`) | None found |
| Real SQLite/WAL/SHM databases with real user data tracked in repo | None found (`.build/build.db` and worktree build DBs are SwiftPM build caches, not app data, and are excluded from git via `.build/`) |
| Real scan/quarantine logs | None found tracked |
| Git remote configured | None (`git remote -v` empty) — confirms nothing has ever been pushed from this clone |
| LICENSE / NOTICE present before this phase | Missing — added this phase |
| README present before this phase | Missing — added this phase |
| `.claude/` directory | Untracked (`git status` shows `?? .claude/`), contains local agent worktrees/settings; not part of git history, left untracked and now explicitly ignored |

## Absolute-path note
The developer's macOS account name and the literal path of the working copy
(`~/Documents/MACCLEAN` at the time of this audit, since moved into the
`WEBSITE/` workspace)
appear only in this session's tool-invocation context and in the local
filesystem location of the working copy — not inside any tracked file in
the repository at audit time. `Scripts/check-private-data.sh` (added this
phase) codifies this check so future commits can't silently reintroduce
absolute developer paths.

## Conclusion
No secrets, credentials, or personal data were found in tracked files.
The primary pre-publication gaps were *absence* of open-source
scaffolding (license, README, CI, docs) rather than presence of private
data. That scaffolding is being added through this branch,
`feat/open-source-foundation`. See PUBLIC_RELEASE_READINESS.md for the
running checklist of what still blocks a real publish.
