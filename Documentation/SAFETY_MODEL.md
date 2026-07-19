# SAFETY MODEL

## Core invariants
1. Scans never delete. Deletion is a separate, explicit step.
2. Deletion engines accept only `ApprovedFileOperation` (produced by `SafetyCenter.approve`),
   never raw URLs from UI.
3. Default deletion method: `FileManager.trashItem` (reversible). No `rm -rf` anywhere.
4. Global dry-run, ON by default.
5. Every path validated twice: at approval and again at execution (defends against
   symlink swaps / moved files between scan and action).

## PathValidator
- Rejects: empty, relative, `/`, home directory itself, protected roots
  (/System, /bin, /sbin, /usr/{bin,sbin,lib,libexec,share}, /private/var/db,
  /Library/Apple, /Volumes/Recovery), anything outside the per-operation allowlist,
  symlinks resolving outside the allowlist.
- Path-under check respects component boundaries ("/a/bc" not under "/a/b").
- User content roots (Documents, Desktop, Pictures, Music, Movies) are never
  auto-selected by rules (enforced by FileRulesTests).

## Audit
SafetyCenter keeps an in-memory audit log per operation ("DRY-RUN|TRASH path rule=id");
will persist to SQLite once Persistence lands.

## Not yet implemented (planned)
Quarantine, restore manifests, reinforced confirmation for non-reversible ops,
hard-link and open-file checks, volume identity checks.
