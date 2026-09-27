### Task 4: Redesign folder, cleanup and duplicate review flows

**Base:** `528662f feat(app): refresh overview performance and record views`

**Files:** `Sources/CoreTendApp/ExploreScanView.swift`, `CleanupView.swift`, `DuplicateScanView.swift`.

**Required outcome:** Apply Observatoire semantic surfaces, spacing, typography and deliberate motion across the three file workflows. Explore must make selected root, current filters, measured allocations, unknown sizes, partial scans, stale state, and item review legible. Cleanup must show explicit rule selection, risk text, exact-folder validation and zero preselection. Duplicates must distinguish exact groups from heuristic similar-image candidates and keep conservative keep/delete decisions explicit. Empty/loading/partial/error states must come from existing state.

**Preserve:** All existing view initializers, scanners, exclusion behavior, security-scoped access lifetimes, Quick Look, cancellation, selection, revalidation, proposal logging, confirmation dialogs, Trash action and event APIs. Never select items automatically. No filesystem behavior changes, inferred risk/safety labels, invented sizes, new data persistence, or automated tests.

**Acceptance:** User can understand scan scope and data limits; unknown is never shown as zero; visual encodings have text/accessibility equivalents; filters/search remain usable; selected items and destructive action are reviewable; action still requires current explicit confirmation and goes to macOS Trash. `swift build --product CoreTendApp` only; do not run tests.
