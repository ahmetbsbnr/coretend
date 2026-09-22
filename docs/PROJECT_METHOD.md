# Project method — how work moves here

`ENGINEERING_RULES.md` is how a *decision* gets made. This is how a *task*
gets from "somebody noticed something" to "it is in the product and proven".
It describes what this repository already does; it does not propose a new
process beside the one in use.

---

## 1. Two kinds of artifact, treated differently

Everything in this project is either **decided** or **derived**, and the two
are never edited the same way.

| | Decided | Derived |
|---|---|---|
| What | information architecture, visual direction, acceptance, vocabulary, the queue | the architecture diagram, the settings matrix, the switch list, the module list, the task counts |
| Who writes it | a person, on purpose | a script, from the source |
| How it goes wrong | it stops being what we want | it stops describing what is |
| The guard | review, and the commit that argues for it | a `--check` that fails when it drifts |

A derived artifact is never hand-edited. If it is wrong, the generator or the
code is wrong. This is why the app's architecture is a *generated* picture: a
hand-drawn one was checked against the code and five of its edges were wrong.

**Derived, today:** `docs/architecture/` (`generate-architecture.py`),
`Documentation/SETTINGS_MATRIX.md` (`generate-settings-matrix.py`),
`dev.sh env` and `dev.sh modules` (read from source at call time),
`dev.sh tasks` (reads the queue at call time),
`Website/assets/tokens/` (`export-design-tokens.py`),
`Documentation/Captures/` (`capture-matrix.sh`).

## 2. Where work comes from

In order of precedence:

1. **The queue** — `CORETEND_VNEXT_TASKS.md`. Take the next unblocked item in
   file order. Do not ask which one; the file decides.
2. **A gap audit**, when the queue runs dry. An empty queue while the product
   is pre-alpha means the planning artifact is behind the product, never that
   the product is done. Run the audit from an angle the last one did not use,
   and refill.
3. **Something a gate caught** — the doctor, a test, a capture that was read.
4. **The user**, whose instruction outranks all three.

`Scripts/dev.sh tasks` renders the current state of (1) and (2) — counts per
section, open items in file order with their line numbers, blocked items with
their reason.

## 3. Plan before iterating, for anything non-trivial

Write what you intend before doing it, and separate two kinds of statement so
they can never be confused:

- **FINDING** — observed, with the evidence that produced it. A finding with
  no reproduction is not a finding.
- **PROPOSAL** — a decision being asked for. Not done yet.

`docs/CORETEND_V2_AUDIT_AND_PLAN.md` is the worked example, including the
part that matters most: it records the three proposals that **execution
reversed**. A plan that only records its successes teaches nothing, and the
reversals are where the codebase talked back.

## 4. The commit is the unit

One change, its reasoning, and its verification arrive together. The commit
message carries what the diff cannot: why this and not the alternative, what
was measured, and what was left undone.

State the evidence class (`ENGINEERING_RULES` §1) — visual, interaction,
functional, absence — because a claim that does not name its evidence is a
claim the next reader has to re-derive.

Before the message is written, the check has been made to fail on purpose
(§2 of the same file). Every gate added this way in this repository found a
real defect while being verified; the ones that were not verified that way
are the ones that were silently broken for months.

## 5. What runs, and when

```sh
Scripts/dev.sh test [filter]    # while iterating — narrow, fast
Scripts/test.sh                 # before a commit — the whole suite, 0 failures
Scripts/build.sh release        # 0 warnings, required before committing
Scripts/dev.sh doctor           # private data, licences, drift, safety gates
Scripts/dev.sh cover            # per-module line coverage, when the question is "is this tested"
Scripts/dev.sh arch --check     # the architecture still describes the code
zsh Scripts/capture-matrix.sh   # when a visual claim is about to be made
zsh Scripts/audit-accessibility.sh
```

`Scripts/test.sh` is the only correct test command. A plain `swift test` omits
flags this project needs and behaves differently.

## 6. Entering the project

**A person**, in this order: `docs/INFORMATION_ARCHITECTURE.md` (what the app
*is*) → `docs/architecture/ARCHITECTURE.md` (what the code *is*, generated) →
`docs/CORETEND_VNEXT_VISUAL_DIRECTION.md` (what it should look like) →
`DEVELOPMENT.md` (how to build it).

**An agent**, in this order: `CLAUDE.md` (the hard constraints) →
`docs/ENGINEERING_RULES.md` (the decision procedure) →
`docs/architecture/architecture.json` (the system, machine-readable) →
`Scripts/dev.sh tasks --json` (what is open) → the queue.

Both then run `Scripts/dev.sh doctor` before believing anything about the
current state.

## 7. What is never decided without the maintainer

Listed in `ENGINEERING_RULES` §7 and repeated here because it is the one
section of this file that is not about efficiency: the safety posture,
release, history, credentials, and deleting a diagnostic for a problem that
is still open.

## 8. Visualisation

`docs/architecture/ARCHITECTURE.md` renders its Mermaid diagram wherever
Markdown is read, and carries the destination table, the engine list, the data
model and the safety invariants beside it. `Scripts/graph.sh` answers the
questions a diagram cannot — what breaks if this symbol changes, where a
change ripples furthest — from a code graph that re-extracts itself whenever
it does not describe `HEAD`.

Neither is a picture someone maintains. That is the point.
