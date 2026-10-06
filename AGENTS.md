# AGENTS.md

This folder is the **CoreTend 1.x maintenance** checkout (branch `fix/1.x-trash-sqlite`, based on `main`).
Product development happens in `../coretend-next` (CoreTend Next); read its `AGENTS.md` before any feature, design or planning work.

- Here: fixes for the published 1.x only. Start with `docs/PASSATION.md` and `docs/TODO.md`.
- Design rule from the maintainer: never add eyebrow/overline text above a page title. Page headers start with the title; a subtitle and functional section labels are allowed.
- Tests: `bash Scripts/test.sh` (not plain `swift test`). After moving this folder, a stale `.build/` breaks the build; use `--scratch-path` or rebuild.
- Before calling XcodeBuildMCP tools, load the XcodeBuildMCP skill when one is available in the session.
