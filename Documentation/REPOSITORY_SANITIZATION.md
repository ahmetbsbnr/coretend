# Repository Sanitization Log

Tracks concrete actions taken during the Open Source Foundation phase in
response to PUBLICATION_AUDIT.md. This is a running log — append, don't
rewrite past entries.

## 2026-07-20 — initial pass
- Confirmed no secrets, `.env` files, or real user SQLite data are
  tracked (see PUBLICATION_AUDIT.md for method/results). No removal was
  necessary because none was found.
- Confirmed `git remote -v` is empty: this clone has never had a push
  destination configured, so no data has left this machine via git.
- Created `feat/open-source-foundation` local branch; all phase work
  happens there per the safety rule (no public push, no remote add).
- `.claude/` is untracked local tooling state (agent worktrees, local
  settings) — left untracked; added to `.gitignore` explicitly so it can
  never be committed by accident.
- Hardened `.gitignore` (see commit) to explicitly cover: build
  artifacts, `.build/`, `DerivedData/`, `.DS_Store`, local
  SQLite/WAL/SHM files, logs, diagnostics exports, quarantine data, local
  scan results, caches, generated DMG/ZIP archives, code-signing
  certs/keys/provisioning profiles, `.env*`, `node_modules/`, a local
  `.vercel/` dir, temp captures, and `.claude/`.

## No git-history rewrite performed
No secrets or private data were found anywhere in the audited tree, so
there was no basis to rewrite git history (`filter-repo`/BFG). If a
future audit finds something in an already-committed file, it must be
removed going forward in a new commit and documented here; history
rewriting is out of scope unless a real secret is found, and if it ever
happens it must be documented explicitly (old vs new commit hashes, exact
command run, exact reason) per the phase's safety rule.
