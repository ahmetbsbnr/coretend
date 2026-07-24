# Brand Name Clearance — "CoreTend"

**Engineering verdict: `CLEAR_FOR_ENGINEERING`**
**Publication verdict: `BLOCKED`**
**Decision date: 2026-07-24**
**Machine-readable version: `Documentation/brand-name-clearance.json`**

## Decision

`CoreTend` was selected and approved directly by the project owner. The
approval is recorded locally and un-versioned in
`Configuration/BrandRenameApproval.local.json`
(template: `Configuration/BrandRenameApproval.example.json`).

That approval authorises the **local technical rename** — source, targets,
bundle identifier, resources, documentation, site, assets, and user-data
migration. It does **not** authorise publication.

## What was and was not established

**Established:** the owner has chosen this name, and the product site will
live at `coretend.ahmetbsbnr.com`, a subdomain of a root domain the owner
already controls. No domain is being acquired, so the domain-acquisition
and domain-reputation risk class that sank the previous candidate does not
apply here.

**Not established:** no trademark-registry search and no prior-software-usage
search has been run for `CoreTend`. None is claimed. The absence of a
recorded conflict in `Documentation/BRAND_CONFLICT_REGISTER.md` §2 means
*nobody looked*, not *nothing is there*. Treating those two as the same
thing is the exact failure mode this document exists to prevent.

## Why engineering may proceed anyway

The risk a trademark search protects against is **use in commerce**. A
local rename produces no use in commerce:

- nothing is pushed;
- nothing is deployed;
- nothing is published or listed;
- no release is cut;
- the artifacts are unsigned and stay on the build machine.

Under those conditions the cost of proceeding is bounded and fully
reversible — the rollback plan is `Documentation/PRODUCT_RENAME_ROLLBACK.md`,
and the rename is mechanical enough to redo under a different name if the
eventual search demands it. The cost of *not* proceeding is that every
downstream deliverable stays blocked behind a search that has not been
scheduled.

## Why publication may not

`Scripts/check-brand-clearance.sh --publication` fails, by design, and will
keep failing until **all** of these land:

1. `legalReviewStatus` becomes `accepted` in the local approval record,
   which requires a real registry search in the relevant classes
   (Nice 9 / 42) across EUIPO, INPI, USPTO, UKIPO, and WIPO.
2. A prior-software-usage search for `CoreTend` / `coretend` across GitHub,
   the App Store, and package registries comes back without a
   same-category conflict.
3. `publicReleaseAllowed` becomes `true`.
4. The independent publication blockers unrelated to the name are resolved:
   legal identity, security contact, and a signing decision.

The project's non-negotiable rule is unchanged and still binding:
**confirmed prior software usage in the same category is sufficient for
`CONFLICT_HIGH` on its own**, with or without a registered trademark. That
rule is what closed out the previous candidate; it applies to this one the
moment a search is actually run.

## Previous candidate

`MacClear` was researched, found `CONFLICT_HIGH`, and abandoned. That
research is preserved verbatim:

- `Documentation/RebrandHistory/BRAND_NAME_CLEARANCE_MACCLEAR.md`
- `Documentation/RebrandHistory/BRAND_SEARCH_EVIDENCE_MACCLEAR.md`
- `Documentation/RebrandHistory/brand-name-clearance-macclear.json`

Its findings also produced a useful negative constraint that the new name
satisfies: stay out of the `Mac*` cleaner-name cluster
(`MacClean`, `MacCleanse`, `MacCleaner Pro`, `MacClean360`) entirely.
