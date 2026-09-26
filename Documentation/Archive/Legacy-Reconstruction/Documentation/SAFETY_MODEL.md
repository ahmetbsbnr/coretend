# SAFETY MODEL

## Core invariants
1. Scans never delete. Deletion is a separate, explicit step.
2. Deletion engines accept only `ApprovedFileOperation` (produced by `SafetyCenter.approve`),
   never raw URLs from UI.
3. The only production removal method is `FileManager.trashItem` (reversible).
   If macOS cannot move an item to Trash, the operation fails and leaves the
   source in place, including under temporary directories. No permanent-delete
   fallback exists.
4. Every destructive surface shows a reviewed selection and asks for explicit
   confirmation immediately before execution.
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
SafetyCenter emits structured lifecycle events per operation. Persistence
stores redacted approved/executed/refused/skipped/error rows in SQLite. An
operation cannot be approved unless its approval event is durably written;
otherwise approval fails closed. Later event write failures increment the
in-memory unrecorded-event count shown in the Safety Log.

Activity records only successfully moved items. Displayed byte totals mean
recorded logical item size moved to Trash, not storage freed: items remain in
Trash and can be restored until the user empties it. Candidate and duplicate
sizes are estimates for review, not recovered-space totals.

## Not yet implemented (planned)
Quarantine, restore manifests, reinforced confirmation for non-reversible ops,
hard-link and open-file checks, volume identity checks.
