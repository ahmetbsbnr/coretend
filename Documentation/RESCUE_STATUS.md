# Rescue Status

Updated: 2026-08-01 19:25 Europe/Istanbul

## Recovery

- Branch: `main`
- Reference HEAD before rescue: `95646a6177795ea3f277d72e893ca6f50780f1ac`
- Recovered local HEAD: `62a3e0fb5a2403f55489ceb1a33cf3844278375a`
- Current HEAD after fast-forward: `494fe55`
- Worktree at recovery: clean
- Untracked files at recovery: none
- Backup: `/Users/ahmetbasbunar/Developer/Website/_backups/coretend-rescue-20260801-192501`
- Backup verification: readable; `SHA256SUMS` written
- Process scan: blocked by macOS sandbox for `/bin/ps`

## Recovered Changes

- Site CoreTend: `Website/generate.py`, generated EN/FR legal and privacy pages
- Tests: `Tests/SafetyCoreTests/PathValidatorTests.swift`
- Vercel configuration: `vercel.json`
- Visual baseline: `Scripts/visual/reference.json` from `origin/main`
- Portfolio: no recovered local changes found
- Documentation: no recovered local changes found before this file
- Packaging: no recovered local changes found
- Other: none

## Gate Status

- Production CoreTend 404: pending verification
- `/`, `/en/`, `/fr/` and assets HTTP 200: pending verification
- Portfolio obsolete / ClamAV removal: pending inspection
- UI tests with isolated app: pending execution
- Skips and no-result test explanation: pending inspection
- Human visual inspection preparation: pending
- CI / Security / Vercel / Git verification: pending
- Public download unchanged while Developer ID is missing: pending verification
