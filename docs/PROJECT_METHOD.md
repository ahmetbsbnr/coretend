# Project method — 1.x maintenance

> **1.x maintenance line.** Product development happens on CoreTend Next
> (`feat/reconstruction-open-musts` → `next`; local folder `../coretend-next`).
> This branch only carries fixes for the published 1.x release.

Start with [PASSATION](PASSATION.md), [TODO](TODO.md),
[architecture](../Documentation/ARCHITECTURE.md) and
[the recovery plan](../Documentation/Reconstruction/RECOVERY_PLAN.md).
Read local instructions and inspect Git state before editing. Preserve user work.
Older v2/greenfield plans are proposals or historical snapshots, not an active queue.

## Evidence and work sequence

Inspect callers and real behavior → document finding and scope → reproduce using
fixtures → smallest fix → regression test → review diff and relevant contracts →
verify → update handoff/backlog. Never claim a build proves UI interaction or that
metadata flags prove a published signature. Keep unresolved behavior explicit.

## Decided and derived documents

Architecture and recovery decisions are maintained documents in this worktree.
Feature inventory, settings matrix, website tokens and Homebrew cask have existing
generators/checks. Fix their source/generator and regenerate; do not hand-edit
rendered output. There is no tracked Scripts/dev.sh or generated architecture
pipeline here. Older references to those tools belong to the other v2 layout.

## Commands

```sh
bash Scripts/test.sh --filter SafetyCenter
bash Scripts/test.sh
zsh Scripts/build.sh release
bash Scripts/repository-doctor.sh
bash Scripts/check-spdx-headers.sh
git diff --check
```

Test runner serializes Swift Testing and disables XCTest; native UI tests require
separate execution. Use synthetic roots/store/preferences for tests and captures.
Never run cleanup against user data to establish a baseline. Do not expose secrets.
Record toolchain warnings rather than silently loosening gates.

## Decisions requiring separate authorization

Safety posture changes, credentials, destructive Git operations and release or
publication are outside routine recovery. Local builds and tests are authorized.
No automatic commit; leave a reviewable working diff and exact verification state.
