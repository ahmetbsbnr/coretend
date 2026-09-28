# Governance

CoreTend uses a simple, single-maintainer-led model — no foundation,
no formal committee, no complex CLA.

## Roles

- **Maintainer(s)** — merge access, release authority. Currently:
  `ahmetbsbnr` (see `.github/CODEOWNERS`).
- **Contributors** — anyone submitting a PR or issue under
  [CONTRIBUTING.md](CONTRIBUTING.md).

## Decision-making

Day-to-day changes (bug fixes, docs, small features) are decided by
maintainer review of a PR — no vote required. Larger or contentious
changes (new engine, new destructive capability, safety-model change, new
dependency) should start as an issue describing the design
first so the design is discussed before code is written.

## Contribution licensing: DCO, not a CLA

Every commit must include a `Signed-off-by` line (`git commit -s`),
certifying the [Developer Certificate of Origin](https://developercertificate.org/)
— you wrote it or have the right to submit it under the project's license
(Apache-2.0 for code, CC-BY-4.0 for docs — see [LICENSE](../LICENSE) /
[LICENSES/](../LICENSES/)). No separate CLA to sign, no copyright assignment.

## Safety-affecting changes

Anything touching `SafetyCore`, the cleanup rule catalog (`ScanCore/CleanupRuleCatalog.swift`), or
any code path that deletes/moves a user's file requires: a maintainer
review specifically of the safety implications, and a passing test that
proves the relevant invariant (`make qualify` must pass).
This is not optional and cannot be waived by general PR approval.

## Changing this document

Governance changes are a design decision — open an issue before
proposing a change here.
