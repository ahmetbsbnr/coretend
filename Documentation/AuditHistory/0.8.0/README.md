# Audit History — 0.8.0 (FROZEN)

These are the 0.8.0 state files exactly as they stood at the end of the 0.8.0
Functional Completion phase. They were moved here by the 0.8.1 Final Canonical
Audit Resync (2026-07-25) so that the `Documentation/CURRENT_*.json` files at the
top level can describe 0.8.1 without either overwriting history or being
contradicted by it.

**These files are frozen. Do not edit them to agree with a later state.** A
historical snapshot that gets quietly updated is worse than no snapshot: it
destroys the only record of what was actually believed and measured at that
commit.

| File | Describes |
|---|---|
| `CURRENT_PROJECT_STATE.json` | 0.8.0 project state: HEAD `a3fe7f7…`, branch `feat/functional-completion`, 250 tests / 55 suites, 42 features |
| `CURRENT_AUDIT_STATE.json` | 0.8.0 audit state: audit package commit `8acd2a5…`, and its own explanation of why it was deliberately *not* advanced to the later doc-only HEAD |
| `PROJECT_STATE.json` | 0.8.0 phase narrative, done/partial/not-started lists, limitations as understood then |

## Values here that are superseded, not wrong

| Field | 0.8.0 (frozen here) | 0.8.1 (current) |
|---|---|---|
| Tests | 250 passing / 55 suites | 274 passing / 57 suites |
| Features | 42 | 46 |
| Branch | `feat/functional-completion` | `feat/coretend-rebrand-workspace` |
| Product name | CoreTend (renamed during 0.8.1) | CoreTend |
| Version | 0.8.0 | 0.8.1 |

Each was correct for its own commit. The current state lives in
`Documentation/CURRENT_PROJECT_STATE.json` and
`Documentation/CURRENT_AUDIT_STATE.json`.

The pre-rename baseline these snapshots sit against is
`Documentation/PRE_REBRAND_BASELINE.md`; the tag
`pre-coretend-rebrand-0.8.0` marks the same point in git.
