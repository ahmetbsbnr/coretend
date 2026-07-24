# Product Rename Rollback

Per-step rollback for `PRODUCT_RENAME_PLAN.md`. Written before any rename
step executes.

## General rule

Every rename step is proposed as its own atomic commit (matching this
project's existing convention of small, atomic commits). Rolling back any
single step is `git revert <that step's commit>` — no step depends on
being un-reversible once the next step has landed, **except** step 9
(bundle identifier + user data), which has its own dedicated rollback
below because it touches real data outside Git's reach.

## Steps 1-8 (text-only, no persisted state)

`git revert` the relevant commit(s). Re-run
`bash Scripts/test.sh && swift build && swift build -c release &&
bash Scripts/repository-doctor.sh` to confirm the revert is clean. No
data migration involved, no special sequencing needed for rollback.

## Step 9 (bundle identifier + local user data) — the one that needs care

This step's migration (see `USER_DATA_RENAME_MIGRATION.md`) is
**copy-based, never move-based, never delete-based**: the new bundle
identifier's `Application Support` directory is populated by *copying*
from the old one, and the old directory is left in place, untouched. This
design choice exists specifically so rollback is trivial:

1. `git revert` the `Info.plist`/`PublicIdentity.example.json` bundle-ID
   commit — the binary now looks for its data under the old bundle ID's
   path again.
2. The old `~/Library/Application Support/MacCareLocal/` directory was
   never touched by the forward migration, so the app immediately finds
   its original data with zero data loss.
3. If the new bundle ID's directory was already used for real work
   (i.e. someone ran the renamed app and it wrote new activity/settings
   under the new identity), that new-identity data is **not**
   automatically merged back — it stays under the new bundle ID's
   directory, inert, until a human decides what to do with it. This is a
   deliberate, documented limitation, not a bug: automatically merging
   two divergent SQLite histories is exactly the kind of "silent,
   irreversible" operation this project's SafetyCore philosophy rejects
   everywhere else, and rebrand rollback should not be the one place that
   philosophy is abandoned.

## Verification after any rollback

Same battery as after any forward step:
`bash Scripts/test.sh && swift build && swift build -c release &&
bash Scripts/repository-doctor.sh`, plus a manual launch to confirm the
app finds its pre-existing data (activity history, exclusions, settings)
under the restored bundle identifier.
