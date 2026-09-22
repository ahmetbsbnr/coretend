# Engineering rules — how a decision gets made here

The conventions are written down elsewhere and this file does not repeat them.
`CLAUDE.md` holds the eleven interface principles and the hard constraints;
`DEVELOPMENT.md` holds the commands; `DESIGN.md` and
`CORETEND_VNEXT_VISUAL_DIRECTION.md` hold the visual language;
`PRODUCT_VOCABULARY.md` holds the words; `CORETEND_VNEXT_ACCEPTANCE.md` holds
what "done" means.

What was not written down is the *procedure* — how to decide, what counts as
knowing, and what may never be decided alone. This is that page.

---

## 1. Evidence: what each kind of claim costs

| Claim | What makes it true |
|---|---|
| **Visual** — "it renders correctly" | A capture that was taken *and opened and read*. The harness refuses a capture whose module, appearance or size does not match what was asked; trust that refusal, never work around it |
| **Interaction** — "it responds" | Execution: the hit-test instrument, a scripted event, or a test. A code path that looks right is not an interaction claim |
| **Functional** — "it works" | A test, or a direct verification run whose output was read |
| **Absence** — "there is no X" | A search that would have found X, shown. "I did not see one" is not absence |

"It should work" is none of these. Neither is a green build: this repository
has shipped a build that exited 0 having compiled nothing, and a test that
passed for a reason unrelated to what it named.

**Say which one you used.** A claim that does not name its evidence is a claim
the next reader has to re-derive.

## 2. Checks: a check that cannot fail is not a check

Before adding a test, a gate or an assertion, make it fail on purpose. Then
make it pass. This is not ceremony — three defects in this file's own history
were found exactly that way:

- `systemRejected` passed for eight months without ever reaching the branch
  it names, because an earlier guard fired first.
- The secret scanner matched every run, so nobody read its output.
- The coverage parser would have printed a confident, wrong table.

A check that fires on correct code is worse than no check, because it teaches
people to skip the output. A check that cannot fire is worse still, because it
teaches them to trust it.

**Corollary.** When a gate is noisy, fix the gate. Do not add an exception for
the thing it is wrongly flagging.

## 3. Direction of safety

When a guess can be wrong in two directions, decide which error you would
rather make, and say so where the code is.

The worked example lives in `PathValidator.isPath`: protected roots compare
case-insensitively because over-refusing is the safe error there, and the
allowlist compares case-sensitively because over-permitting is never the safe
error. The same function, opposite defaults, both reasoned.

This is why "just make it consistent" is not automatically an improvement.

## 4. Where a thing goes

```
Sources/
  <Engine>/            logic with no view — builds and is tested without SwiftUI
  DesignSystem/        tokens and components
  CoreTendApp/
    App/               lifecycle, window, routing, catalogue
    Shell/             sidebar, menus, module chrome, inspector layout
    Modules/<Name>/    one directory per sidebar destination, ten of them
    Support/           formatting, paths, permissions, scan plumbing, L10n
    Diagnostics/       code that exists so the app can be observed
Tests/
  TestSupport/         helpers every suite shares — one copy, never two
Scripts/
  support/             what only a script calls
```

- A **module directory** is a sidebar destination, and there are exactly eight
  plus Settings and Onboarding. Adding one is an information-architecture
  decision (`docs/INFORMATION_ARCHITECTURE.md`), not a place to put a file.
- **`Support/`** is not a junk drawer by default and becomes one by neglect.
  A file belongs there when more than one module uses it; a file used by one
  module belongs in that module.
- **`Diagnostics/`** ships in release builds on purpose: the evidence pipeline
  runs against the packaged release app.
- A **`DesignSystem`** token earns its place by having more than one call site,
  or by naming a decision.

**No new top-level directory** without a reason in the commit message. A new
directory is a claim that a category exists.

**Nothing outside `Sources/` writes the layout down.** Tests locate a source
file by name (`SourceTree.find`), and so do the scripts that gate on one.
Thirteen test files and three scripts had hardcoded paths, which is what made
a directory reorganisation read as "real regression risk" and kept it
deferred — the risk was never the move, it was everything that had memorised
the old shape. A contract test says which file it is about; where that file sits is
not its business.

**Lists derive from source.** `generate-settings-matrix.py`, `dev.sh env`,
`dev.sh modules` all read their contents out of the code rather than restating
it. A hand-kept list goes stale for exactly the person who needed to read it.

## 5. What justifies itself

- **A rectangle** — after alignment, whitespace, typography and a surface
  change have been tried. A box that exists because the screen looked empty is
  an information-architecture problem wearing a border.
- **An abstraction** — when the codebase already needs it. One call site is
  not a pattern.
- **An animation** — when it explains a change. It must also name its
  `MCMotion` token *and* honour Reduce Motion; the token says what the motion
  is for, not whether it may play at all.
- **A dependency** — against the fact that this app has **zero runtime
  dependencies**. That is the single largest security asset here; it is not
  traded for convenience.
- **A number shown to a person** — when the engine can stand behind it. No
  invented threshold, no "freed" total, no health score.

## 6. Unknown is not fine

A state this build does not recognise is never rendered as "all clear". Where
a verdict comes from the OS, enumerate what it calls *fine* and treat
everything else — including tokens added after this binary was compiled — as
needing attention. Listing the bad values and defaulting the rest to safe is
how a future macOS thermal level above `critical` gets reported as nothing to
worry about.

## 7. What is never decided alone

An agent, or a contributor working without the maintainer, does not decide:

- **The safety posture.** Trash-only, protected roots, append-only
  `safety_log`, explicit confirmation. These change by decision, never by
  refactor.
- **Release.** No build, tag, notarisation or publication without the
  maintainer's explicit authorisation. Metadata describes bytes that were
  actually published — never set a flag ahead of the signature that justifies
  it, never leave one set after a release that did not get one.
- **History.** No force-push, no rewrite. The published release provenance
  (SLSA attestation, Minisign signature, `published-release.json`'s
  `sourceCommit`) binds to real commit hashes; rewriting makes a signed
  release unverifiable.
- **Credentials.** Never regenerate the Developer ID CSR or key; never read or
  echo the private key or the notarisation `.p8`.
- **Deleting a diagnostic for an open problem.** Its sibling question being
  answered is not the same as the problem being closed.

## 8. When you are wrong

State the correction in a sentence and continue. The commit message is where
the reasoning goes — including reasoning that reversed a plan, because the
next reader needs to know the alternative was considered and why it lost.

Three items in the recent audit were reversed by evidence after being planned:
protecting `/Library/LaunchDaemons` (it would have broken app uninstallation),
gating the instruments out of release builds (it would have destroyed the
evidence pipeline), and calling `FileRules` under-tested (it was not; two
specific invariants were missing). Being talked out of a plan by the codebase
is the process working.

## 9. An empty queue is a planning gap

`CORETEND_VNEXT_TASKS.md` running dry while the product is pre-alpha means the
planning artifact is behind the product, never that the product is finished.
Run a fresh gap audit — from a new angle, not a repeat of the last one — and
refill it. Cleanup, dead-code removal and test repairs are real work and are
not a substitute for that audit.
