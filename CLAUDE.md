# CoreTend — what is actually true of this project

Repo-level orientation. The workspace file at `~/Developer/Website/CLAUDE.md`
still applies; this one records the things only true inside CoreTend, and
corrects constraints that used to be stated and are no longer true.

## Build & test — the real commands

- `swift build` · `swift build -c release`
- **`bash Scripts/test.sh` — never raw `swift test`**
- `bash Scripts/package-local.sh` — signed local .app into `build/`
- `CORETEND_CAPTURE_SEED=seed-record.sh zsh Scripts/capture-module.sh <out.png> <module>`
- `bash Scripts/render-mockups.sh` — renders `Documentation/Mockups/*.html`

Several of these need a real macOS sandbox of their own and fail with
"Operation not permitted" inside a restrictive outer sandbox: anything driving
WebKit, and `swift build` when the module cache is unreachable.

## Xcode — the constraint that changed

There is **no `.xcodeproj` and there will not be one**: the package is the
build system. That is the invariant.

What is *not* an invariant, and used to be written as one: "no Xcode". Xcode's
command-line tools are used, deliberately, because nothing else produces these
outputs — `ictool` and `icrtool` for the app icon
(`/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/`),
`actool` for asset catalogues, and the Xcode toolchain's `swiftc`. Anyone
removing an Xcode dependency should check which of these it feeds first.

Known-broken: `actool` produces no `Assets.car`, no warning and no error from a
hand-authored `.icon` package. That is why the layered icon item is blocked
rather than worked around.

## Do not

- Never regenerate the Developer ID CSR or private key in
  `Configuration/DeveloperID/`. "Unsigned" is a documented release state, not a
  bug to silently fix.
- `Localizable.strings` are **UTF-16**. Appending with a UTF-8 writer corrupts
  the file silently. A merge-conflict marker in one of them once truncated the
  parser and made 18 keys unreachable *in a released build* — the parser stops
  at the first malformed line and says nothing.
- `safety_log` is append-only. `purgeSafetyLog()` is the only deletion path, it
  is all-or-nothing, and nothing restores it.
- Migrations resume from `MAX(version)`, so `ALTER TABLE ADD COLUMN` is not
  idempotent across a partially-applied history. Prefer the `settings` table.

## Where the decisions live

`docs/` is the source of truth for the rebuild: `INFORMATION_ARCHITECTURE.md`
(destinations, models), `DESIGN_SYSTEM.md` (surfaces, colour, type, states),
`PRODUCT_VOCABULARY.md` (one name per thing), `FRONTEND_REBUILD.md` (code
layout and per-module spec), `ACCESSIBILITY.md`, `UI_QA_MATRIX.md`, and
`REMAINING_WORK.md` — an atomic backlog. Take the next open item there; do
not redesign.

QA procedure: `bash Scripts/test.sh` → `bash Scripts/package-local.sh` →
`zsh Scripts/capture-module.sh <out> <module> <light|dark> <compact|standard|large> [seed]`
→ look at the image. A capture is refused if the app is not showing what was
asked; a refused capture is a bug to fix, never to work around.

## Interface principles — so the old design does not creep back

These are conclusions that cost something to reach. Changing one is a decision
to take on purpose, not a detail to smooth over.

1. **Measure contrast on the surface the control actually sits on.** A reading
   taken anywhere else is a reading of something else. `.glassProminent`
   measured 11.13:1 isolated and 2.61:1 in place, and was reverted for it.
   Guidance that fails measurement loses to the measurement.
2. **Never print a quantity the app cannot stand behind.** CoreTend moves items
   to the Trash; it is never told when the user empties it, so there is no
   honest "freed" or "reclaimed" total. "Freed (real)" shipped and claimed a
   check that was never performed. `SafetyLedgerSummaryTests` fails if such a
   total reappears.
3. **A refusal is a first-class record.** What CoreTend declined to touch, and
   why, is evidence — never a footnote on somebody else's entry, and never
   flattened together with a failure.
4. **The sidebar follows the user's accent**, not a decorative brand accent
   (HIG, sidebar, 8 June 2026). Measured 10.83–12.28:1 across all seven system
   accents in the running app.
5. **The app owns its palette** rather than inheriting system black and white —
   but it is not mono-theme: Light and Dark are both real, both derived from the
   brand.
6. **Verify negatively.** A check that cannot fail is not a check. The capture
   script once photographed the Dashboard eleven times while every assertion
   passed, because the Dashboard renders fine.
7. **An empty screen proves nothing about a layout.** Captures of data-bearing
   views are seeded (`Scripts/support/seed-record.sh`).
8. **Destructive and irreversible are not the same thing.** Anything with no
   path back is confirmed, and is never the most prominent control on screen.
