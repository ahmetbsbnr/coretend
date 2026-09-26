# docs — the decision documents

Two kinds of file live in this repository, and they are not edited the same
way. **Decided** documents are written by a person on purpose. **Derived** ones
are generated from the source and fail a gate when they stop describing it —
never hand-edit those. `PROJECT_METHOD.md` explains the distinction and the
working method it implies.

Everything in this directory is decided. The derived artifacts live beside what
they describe: `Documentation/SETTINGS_MATRIX.md`,
`Website/assets/tokens/`, `homebrew/coretend.rb`.

## Start here

| If you are | Read, in order |
|---|---|
| a person | [`PROJECT_METHOD.md`](PROJECT_METHOD.md) → [`../DEVELOPMENT.md`](../DEVELOPMENT.md) → [`PRODUCT.md`](PRODUCT.md) |
| an agent | [`ENGINEERING_RULES.md`](ENGINEERING_RULES.md) → [`PROJECT_METHOD.md`](PROJECT_METHOD.md) → [`CORETEND_V2_PROGRAM.md`](CORETEND_V2_PROGRAM.md) |

Then `bash Scripts/repository-doctor.sh`, before believing anything about the
current state.

## What is here

| File | What it settles |
|---|---|
| [`ENGINEERING_RULES.md`](ENGINEERING_RULES.md) | how a decision is made: what evidence a claim costs, why a check is made to fail before it is trusted, what is never decided alone |
| [`PROJECT_METHOD.md`](PROJECT_METHOD.md) | how a task moves from noticed to proven |
| [`CORETEND_V2_PROGRAM.md`](CORETEND_V2_PROGRAM.md) | the development programme for 2.0: where the product stands, the field it ships into, MoSCoW, the visual programme, the App Store track, sequencing |
| [`THREAT_MODEL.md`](THREAT_MODEL.md) | what CoreTend is exposed to, what it defends against, and what it does not |
| [`CORETEND_V2_AUDIT_AND_PLAN.md`](CORETEND_V2_AUDIT_AND_PLAN.md) | the security and quality audit, and what executing it reversed |
| [`PRODUCT.md`](PRODUCT.md) | what the product is and who it is for |
| [`PRODUCT_VOCABULARY.md`](PRODUCT_VOCABULARY.md) | one name per thing, in both languages |
| [`ACCESSIBILITY.md`](ACCESSIBILITY.md) | the accessibility contract, and what is checked rather than claimed |
| [`TODO.md`](TODO.md) | the shipping line's own backlog |
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | every third-party licence the product or the site carries |
| [`TRADEMARKS.md`](TRADEMARKS.md) | what the name and the mark may be used for |
| [Reconstruction cahier](superpowers/specs/2026-09-25-coretend-reconstruction-design.md) | product scope, QQOQCCP, requirements, MoSCoW, RACI, safety invariants and acceptance |
| [Reconstruction roadmap](superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md) | sequenced programmes, entry/exit gates and reconstruction completion criteria |
| [Safety and persistence plan](superpowers/plans/2026-09-25-coretend-safety-persistence-contracts.md) | fail-closed operations, truthful Trash records, privacy-safe audit and acceptance gates |
| [Measured baseline](../Documentation/Reconstruction/BASELINE.md) | current evidence and conflicts for this checkout |
| [Requirement traceability](../Documentation/Reconstruction/REQUIREMENTS_TRACEABILITY.md) | FR/NFR mapping from cahier to implementation, proof and gaps |
| [Open decisions](../Documentation/Reconstruction/DECISIONS.md) | choices requiring maintainer decision, owner and blocked programme |

The 2.0 rebuild carries more of these on `develop/v2` — the visual direction,
the acceptance criteria, the information architecture and the generated
architecture model, which is derived from that branch's source tree and would
describe code `main` does not have.

`Documentation/` holds the research, the audits, the capture galleries and the
release evidence.
