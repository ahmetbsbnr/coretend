<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Project History

The public repository starts from a single commit. This file explains what came
before it, so the fresh start reads as a deliberate choice rather than a gap.

## The earlier name: MacCare Local

CoreTend was developed under the name **MacCare Local**. It was renamed before
the first public release, for two reasons:

1. The old name sat in a crowded cluster of similarly-named macOS utilities
   (MacClean, MacCleanse, MacCleaner Pro, MacClean360 and others), where a new
   entrant is hard to tell apart and easy to mistake for something else.
2. A candidate replacement, *MacClear*, was researched and abandoned: it
   collided with an existing SwiftUI macOS cleaner of the same name covering
   nearly the same feature set. That research is preserved in
   `Documentation/BRAND_CONFLICT_REGISTER.md`.

`CoreTend` was then screened against the aggregated trademark registers and the
major software distribution channels before any public use. The result and its
limits are recorded in `Documentation/CORETEND_TRADEMARK_SCREENING.md`. The name
is used **unregistered**: no application has been filed and no registration is
claimed.

If you have an installation from the MacCare Local era, the app migrates your
data and preferences automatically on first launch under the new name. See
`Documentation/USER_DATA_RENAME_MIGRATION.md`.

## Why the pre-release history is not published

The development history is real and is preserved — privately, as a verified git
bundle held by the maintainer. It is not published, because it is not
publishable as it stands:

- Seven files carried an absolute `/Users/<name>` path from the build machine at
  various points across 244 commits.
- Several documents are session-continuity logs and workspace migration
  manifests: working notes written agent-to-agent during development, describing
  a private directory layout on one person's computer. They were never written
  for an audience.

Rewriting 244 commits to strip that would be slow and lossy, and would still
leave every intermediate state of every internal document in the public record.
Publishing a clean tree with an honest note is the better trade.

**Nothing about the software itself is withheld by this.** The complete source,
the full test suite, every build and packaging script, and every quality gate
are all in the public repository. What is omitted is the private record of the
development process, not the product.

The export is reproducible and its boundary is reviewable:
`Scripts/build-public-branch.sh` holds the exclusion list, verifies the staged
tree for personal paths, credentials and local-only configuration, and refuses
to create anything if a check fails.

## Version at first publication

The first public release is **0.9.0 — Public Beta**, distributed **unsigned**.

It is unsigned because code signing and notarisation require an Apple Developer
ID, which requires a paid Apple Developer Program membership that the project
does not have. Rather than pretend otherwise, the release states this plainly
and the download page explains exactly what macOS will show on first launch and
why. See `Documentation/INSTALL_UNSIGNED.md` and `Documentation/DISTRIBUTION_AUDIT.md`.

Everything needed to sign and notarise is already scripted, so the step is a
credential away rather than a rewrite.
