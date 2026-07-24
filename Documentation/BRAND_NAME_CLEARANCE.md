# Brand Name Clearance — "MacClear"

**Verdict: `CONFLICT_HIGH`**
**Date: 2026-07-24**
**Machine-readable version: `Documentation/brand-name-clearance.json`**

## Decision

`MacClear` is **not cleared for engineering**. This session's own research
(`Documentation/BRAND_SEARCH_EVIDENCE.md`, `Documentation/BRAND_CONFLICT_REGISTER.md`)
found three independent, real, exact-name "MacClear"/"macclear" software
projects on GitHub, all in the identical category (macOS cleanup utility),
one of which (`Matcha00/MacClear`) is a near-exact functional and technical
twin of MacCare Local: SwiftUI, native macOS, cleans caches/logs/dev-junk/
downloads/temp-files/large-old-files/duplicates/app-leftovers/system-level
caches, Trash-default deletion, risk-tiered auto-selection, Full Disk
Access instructions.

This independently confirms — via a different, real finding rather than
just restating it — the user brief's underlying concern that "MacClear" is
already occupied in this exact space. The specific "since 2018, App
Store, uninstaller" product named in the brief was not independently
reproduced by this session's tooling, but that is a tooling limitation,
not evidence the claim is false, and it is moot regardless: the three
confirmed conflicts already meet the bar.

## Why this is CONFLICT_HIGH, not lower

Per the project's own non-negotiable rule: **confirmed prior software
usage in the same category is sufficient for `CONFLICT_HIGH`, even with no
exact registered trademark found.** No registered-trademark search was
even completable this session (see the tool-limitation section below), so
that factor is neutral, not exculpatory — the software-usage evidence
alone already crosses the threshold.

Aggravating factors on top of the baseline:
- **Three** independent instances, not one — this is a genuinely occupied
  name in the category, not a single obscure edge case.
- One instance (`Matcha00/MacClear`) matches not just the name and
  category but the *implementation* (SwiftUI, Swift Package Manager,
  identical safety posture of Trash-default + risk-tiered auto-select +
  FDA-gated). A side-by-side comparison would look deliberate even though
  it plainly is not.
- The `.com` domain is already registered and carries a negative
  reputation signal (ad/tracker blocklist entry, broken TLS) — even a
  clean legal path would still need a different domain strategy.

## What this verdict blocks (per the phase's non-negotiable rule)

Per this phase's instructions, `CONFLICT_HIGH` means, until further
notice:
- no file, folder, repo, or product renamed to MacClear;
- no logo, icon, or asset produced under the MacClear name;
- no bundle identifier changed;
- no legal/license text changed to reference MacClear;
- no repository moved under a `macclear` path;
- no domain or GitHub org registered under this name;
- no artifact (ZIP/DMG/site) produced under the MacClear name;
- no attempt to route around the conflict via casing or spacing tricks
  (`Mac Clear`, `MAC-CLEAR`, `macClear`, etc. — same category of conflict).

None of the above happened this session, and none will until a name
reaches `CLEAR_FOR_ENGINEERING` **and** a human approval file exists (see
below).

## What would be required to proceed with MacClear anyway

Per the same rule, full rename is only permitted if **all four** hold:
1. Status is `CLEAR_FOR_ENGINEERING` (not the case — see above).
2. No serious prior software usage is identified (not the case — three
   found).
3. Official registries show no relevant conflict (not established either
   way — see tool-limitation note).
4. `Configuration/BrandRenameApproval.local.json` exists locally
   (gitignored) with `approvedByHuman: true` and
   `legalReviewStatus: "accepted"`.

None of the four hold today. **MacClear stays blocked.** See
`Documentation/BRAND_NAME_ALTERNATIVES.md` for a screened shortlist of
alternatives, and `Documentation/BRAND_NAME_SHORTLIST.md` for the top 5 —
selection among them is explicitly left to the user, not made here.

## Tool-limitation note (official registries)

EUIPO eSearch Plus, TMview, INPI DATA, WIPO Global Brand Database, UKIPO,
and USPTO TESS/TMsearch all require interactive, JavaScript-driven search
forms this session's `mcp__web__web_search` tool cannot drive — every
attempt returned only each registry's static homepage/about content, never
actual search results. This is logged honestly in
`BRAND_SEARCH_EVIDENCE.md` as `INCONCLUSIVE_TOOL_LIMITATION`, not
misrepresented as "checked and clear." A real trademark clearance still
requires either manually running those registries' own search forms or
engaging a clearance-search professional/service before any legal
reliance — this is `CLEAR_WITH_COUNSEL_REVIEW` territory even in the
hypothetical case where the software-usage conflicts above turn out to be
resolvable (e.g. the existing repos are inactive hobby projects with no
trademark filed, which is plausible but not verified).

## Status field

```
status: CONFLICT_HIGH
name: MacClear
clearedForEngineering: false
humanApprovalFilePresent: false
blocksRename: true
```
