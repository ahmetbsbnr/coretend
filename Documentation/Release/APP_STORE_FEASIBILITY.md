# Mac App Store feasibility

Status: future investigation. CoreTend is currently distributed directly as
an open-source, ad-hoc-signed build. This document does not claim App Store
compatibility.

## Current direct-distribution constraints

The direct build is not App Sandbox enabled and scans user-selected locations,
application metadata, launch items and other protected filesystem locations.
It relies on Full Disk Access where macOS requires it and uses a user-initiated
HTTPS update-manifest request. These assumptions do not transfer unchanged to
the Mac App Store.

## Feasibility audit

- App Sandbox entitlements and security-scoped bookmarks would be required for
  user-selected folders and persisted access.
- Full Disk Access is not a substitute for sandbox entitlement design.
- Broad inventory of `/Applications`, user Library data, launch agents and
  associated application data would need a capability-by-capability review.
- The direct updater channel must be removed or replaced by the App Store
  update pipeline in any MAS edition.
- Finder reveal, Trash actions and persistence must be tested against App Store
  review rules and sandbox-scoped URLs.
- No StoreKit configuration, MAS export profile or submission pipeline exists
  in this repository.

## Decision

Do not degrade the direct build to simulate MAS support, and do not create a
second edition without owner approval. A future MAS feasibility branch must
first produce an entitlement matrix, a reduced-capability UX proposal, a
separate build configuration and a review-guideline audit. Developer ID direct
distribution and Mac App Store distribution remain distinct pipelines.
