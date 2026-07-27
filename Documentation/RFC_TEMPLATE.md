# RFC: [Title]

Copy this file to `Documentation/rfcs/NNNN-short-title.md` (create the
`rfcs/` directory if it doesn't exist yet) and open a PR with just the RFC
for discussion before writing implementation code.

## Summary
One paragraph: what is being proposed.

## Motivation
What problem does this solve? Who's affected? What happens if we do
nothing?

## Design
How it works. For anything touching scanning/deletion, be explicit about:
- What paths/roots are affected.
- How it goes through [SafetyCore](SAFETYCORE.md) (`PathValidator`,
  `SafetyCenter`) — no new destructive path may bypass it.
- Dry-run behavior.
- What's reversible (Trash) vs. not.

## Alternatives considered
What else was considered, and why this approach.

## Risks / safety impact
Does this touch `SafetyCore`, `FileRules` allowlists, `Quarantine`, or any
code path that can delete/move a user file? If yes, this RFC requires
explicit maintainer sign-off on the safety implications before
implementation — see [GOVERNANCE.md](../GOVERNANCE.md).

## Testing plan
What new tests prove this works and stays safe — see
[TESTING.md](TESTING.md).

## Migration / compatibility
Any schema (`MIGRATIONS.md`), settings, or breaking-behavior impact for
existing users.

## Unresolved questions
Anything still open for discussion.
