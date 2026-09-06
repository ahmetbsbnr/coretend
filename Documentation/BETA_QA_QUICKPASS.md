<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend 1.1.0-beta.1 — maintainer QA quick pass

**This document is not evidence.** It is a guided linear sequence for the
maintainer to run on-device tonight. When each step passes, record the result
in `Documentation/BETA_QA.md` (the "Outstanding — HUMAN VERIFICATION REQUIRED"
list and the command-palette / ⌘-trigger sections), as
`PASS — <YYYY-MM-DD> — build 1100 (<how built>)`, and only then flip the
line-20 verdict to `READY TO SIGN: YES`.

Nothing here is pre-filled PASS. A single FAIL blocks signing.

## Build under test

Use the **ad-hoc candidate** the release pipeline produces:

```
Scripts/build-xcode.sh          # -> build/CoreTend.app (universal, ad-hoc)
open build/CoreTend.app
```

(The final signed/notarized DMG is smoke-tested separately, after signing —
see `Documentation/BETA_RELEASE_COMMANDS.md`.)

Target ~30 minutes. Do the whole flow once in **dark + French**, then repeat
only the starred (★) steps in **light + English**.

Legend per step: **Do** → **Expect** → mark **PASS / FAIL** → **Record under**
(the `BETA_QA.md` item number, or "palette" / "trigger").

---

## A. Launch, theme, language, window (covers items 1, 12; trigger)

1. **Do:** launch `build/CoreTend.app`; if a TCC "access other apps' data"
   prompt appears, **Allow** (needed for real scans).
   **Expect:** Dashboard renders; sidebar shows all 17 rows in 4 groups; no
   blank column. **Record under:** item 1.
2. ★ **Do:** System Settings → Appearance → toggle Light/Dark while CoreTend
   is open.
   **Expect:** every visible surface re-themes; text contrast stays legible;
   the teal selection marker and focus rings stay visible. **Record:** item 1.
3. **Do:** Settings (Réglages) → Général → Langue → switch FR ⇄ EN.
   **Expect:** sidebar, headers, buttons, and byte figures change immediately
   with **no relaunch** and no mixed-language state; `3,9 Go` in FR becomes
   `3.9 GB` in EN. **Record:** item 12.
4. ★ **Do:** resize the window to ~900×632, then ~1320×820, on Dashboard.
   **Expect:** the circular ⌘ trigger stays inside the header band, clear of
   the rounded window corner, never overlapping the page title; the title
   stays readable at the narrow size. **Record:** trigger.

## B. Command palette (covers palette; item 6)

5. **Do:** press ⌘K. Type `dupl`.
   **Expect:** the search field shows a caret immediately; the list filters to
   Duplicates as you type. **Record:** palette.
6. **Do:** press Return on the filtered result.
   **Expect:** navigates to Duplicates; palette closes. **Record:** palette.
7. **Do:** ⌘K again, then click **once** on empty content **outside** the
   palette panel (e.g. lower-left of the window).
   **Expect:** palette closes on that single click; the control under the
   pointer does **not** activate (no navigation, no scan started). **Record:**
   palette (this is the release-blocking physical-gesture check).
8. **Do:** ⌘K, then press Escape. Then ⌘K, then click the ✕.
   **Expect:** each closes the palette cleanly; focus does not get stuck.
   **Record:** palette.
9. **Do:** with the palette open, check the sidebar.
   **Expect:** all sidebar rows still visible; opening/closing the palette
   never scrolls the sidebar. **Record:** item 6.

## C. Duplicates — sidebar P0 + live scan (covers items 5, 6)

10. **Do:** Dashboard → Duplicates → Space Lens → Duplicates → Recovery Plan →
    Duplicates → Applications → Duplicates → Dashboard. Resize narrow↔wide
    between two of the hops. Tab through the Duplicates controls.
    **Expect:** the sidebar is **always** fully visible, the active module
    keeps its teal marker, no empty/phantom column, no automatic sidebar
    scroll. **Record:** item 5.
11. **Do:** on Duplicates, click **Rechercher les doublons / Search for
    duplicates**. Watch idle → scanning → results (or empty).
    **Expect:** through every phase the sidebar stays intact and does not
    scroll; the scanning view shows pause/resume/cancel; results group by
    duplicate set with a keeper suggestion; "Rien à récupérer" if none.
    **Record:** item 5.
12. **Do:** during the scan, select a couple of result rows as they appear;
    click into the sidebar and back.
    **Expect:** selecting rows never greys the sidebar module marker or
    changes the selected module. **Record:** item 6.

## D. Storage — scan lifecycle (covers item 4)

13. **Do:** Storage → Démarrer l'analyse / Start scan. Let it run, then
    **Pause**, then **Resume**, then **Cancel**. Run it again and let it
    **complete**.
    **Expect:** live progress is real (phase label + counts + elapsed, no fake
    %); Pause visibly halts progress; Resume continues; Cancel returns to
    idle; Finalizing is brief; the completed state's reclaimable / review /
    selected / recovered read as visually distinct. Friendly locations
    (e.g. "Bibliothèque › Caches") are readable, not raw paths. **Record:**
    item 4.
14. **Do:** in the completed/review state, select nothing → select some →
    select all eligible.
    **Expect:** the confirm bar always shows the **selected amount**; with
    nothing selected the destructive button is disabled. **Do not** confirm
    the Trash move unless you want it. **Record:** item 4.

## E. Smart Scan (covers items 1, 2, 18; feeds item 3)

15. ★ **Do:** Dashboard → **Lancer l'analyse intelligente / Run Smart Scan**.
    Watch idle → running → completed.
    **Expect:** six modules listed; running shows elapsed time and truthful
    per-module state, no fake percentage, no row jumping or clipping; the
    result keeps the four dimensions separate (potentially recoverable / to
    review / attention / informational), with exact vs non-exact recoverable
    behaving sensibly. **Record:** item 1.
16. **Do:** start a fresh Smart Scan; while it runs, click another sidebar
    module, then come back to Dashboard.
    **Expect:** the scan is still running (or finished) — it did **not**
    restart, and the layout did not jump. **Record:** item 2.
17. **Do:** on a completed result, open a per-dimension drill-in and return.
    Then click **Nouvelle analyse intelligente / New Smart Scan**.
    **Expect:** drill-ins open real detail; "New Smart Scan" genuinely
    re-scans (fresh numbers/timestamp), not a replay. **Record:** item 1.

## F. Recovery Plan (covers item 3)

18. **Do:** from a completed Smart Scan, use **Examiner le plan de
    récupération / Review Recovery Plan**.
    **Expect:** the handoff is immediate — **no second full preparation
    scan**; a "from Smart Scan" note is shown; the candidate categories and
    counts match what Smart Scan reported; the plan stays user-editable.
    **Stop at the confirmation boundary — do not execute** (unless you have
    disposable content and want to). **Record:** item 3.
19. **Do:** check the ready view's bottom confirm bar and the goal card.
    **Expect:** the last row clears the confirm bar (not hidden behind it);
    the summary card adapts to width; Advisor badges wrap instead of
    truncating; FR byte figures use `,` and `Go`/`Mo`; pre-execution wording
    is truthful ("Recoverable from Trash", never "Moved to Trash" before you
    confirm). **Record:** item 3.

## G. Space Lens (covers items 6, 7, 8, 9)

20. **Do:** Space Lens → **Analyser le dossier personnel**, or "Choisir un
    dossier…" → `~/Library` (read-only). Watch it scan.
    **Expect:** progressive partial results appear; update cadence feels
    smooth (~8/s), not jittery; layout stays stable, no flicker; the UI stays
    responsive; **Cancel** and **Pause/Resume** work with low latency; memory
    stays sane (glance at Activity Monitor). **Record:** item 7.
21. **Do:** after it settles: click a bubble, then a list row; double-click a
    bubble to drill in, then a row; use the keyboard to drill; use breadcrumb
    and Back across two levels; try double-clicking a *file* and the *Other*
    bucket.
    **Expect:** bubble ⇄ list selection stays in sync; drilling works from
    bubble, row, and keyboard with a visible focus ring; a file and *Other*
    do **not** drill; breadcrumb and Back move levels correctly; no offscreen
    bubble pile, no layout corruption. **Record:** item 8.
22. **Do:** type in the search field; apply a category filter; resize the
    window during use.
    **Expect:** search and filter keep the canvas and list in sync; selection
    handling is deterministic (no fl\icker between two items); resize reflows
    cleanly. **Record:** item 9.
23. **Do:** move focus between Space Lens bubbles and the sidebar.
    **Expect:** focusing a bubble never greys or moves the sidebar module
    marker. **Record:** item 6.

## H. Restore Center (covers item 17)

24. **Do:** make a disposable file (e.g. `~/Desktop/coretend-qa-throwaway.txt`).
    Use a CoreTend flow that Trashes it (e.g. add its folder as a Space Lens
    target is not destructive — instead: put the file where a Cleanup/Clutter
    rule would catch it, or use Applications/Leftovers on a throwaway app
    support folder). Then Restore Center → select it → Restore.
    **Expect:** it returns to its **original** location; a pre-existing file
    at that path causes a **refused collision**, never an overwrite; history
    states (available / restored / missing-from-Trash) read correctly.
    **Do not empty the Trash.** External-volume restore is optional.
    **Record:** item 17.

## I. Integrations (covers items 13, 14, 15, 16)

25. **Do:** System Settings → Privacy & Security → Extensions → enable
    **CoreTend** Finder extension. In Finder, right-click a folder, a
    supported image, and a `.app`; then try an empty selection, a multi
    selection, a symlink, and an unsupported item; try it with CoreTend
    closed, open, and with its window closed/background.
    **Expect:** the action hands the selection to CoreTend via `coretend://`
    and does nothing else; unsupported/empty selections are handled
    gracefully; the handoff is consumed once (no duplicate); protected
    locations are refused. **Record:** item 13.
26. **Do:** add the **CoreTend** widget from the widget gallery — small, then
    medium — in light and dark.
    **Expect:** aggregate figures only (free space, trend in words, last
    scan); **no file paths, no private metadata**; nothing clipped;
    read-only. **Record:** item 14.
27. **Do:** open the Shortcuts app; search "CoreTend".
    **Expect:** it lists the 7 App Intents and 6 App Shortcuts; run one
    read-only action; the FR phrases resolve. **Record:** item 15.
28. **Do:** Settings → Notifications → grant permission; set schedule to
    Daily, observe the option set is only **Off / Daily / Weekly**; trigger a
    test notification if the build exposes one.
    **Expect:** a real OS permission prompt, then a delivered notification
    with correct text; no notification spam; a scheduled scan is read-only.
    **Record:** item 16.

## J. Reduce Motion, VoiceOver, relaunch (covers items 10, 11, 18)

29. **Do:** System Settings → Accessibility → Display → **Reduce Motion** on.
    Re-run a Smart Scan and a Space Lens scan.
    **Expect:** no unnecessary scaling/spring animation; the scan-stage motif
    and bubble canvas still function; turn Reduce Motion back **off**
    afterwards. **Record:** item 10.
30. **Do:** turn on VoiceOver (⌘F5). Navigate the sidebar, the Smart Scan
    module rows, and Space Lens bubbles + list + breadcrumb + Back + search.
    **Expect:** meaningful labels everywhere; a Space Lens bubble announces
    "…&nbsp;percent of this folder, directory" (or similar) — **never**
    "Circle"; turn VoiceOver off afterwards. **Record:** item 11.
31. **Do:** navigate warm between several modules, close the window, reopen
    from the Dock, quit (⌘Q), relaunch.
    **Expect:** no stale Smart Scan state carried across a relaunch; no crash;
    the Dashboard comes back clean. **Record:** item 18.

---

## When done

- Every item above **PASS** → update `Documentation/BETA_QA.md`:
  - annotate each "Outstanding — HUMAN VERIFICATION REQUIRED" item and the
    palette / ⌘-trigger notes with `PASS — <date> — build 1100`,
  - change the line-20 verdict to **`V1.1.0-BETA.1 READY TO SIGN: YES`**,
  - commit on `release/v1.1.0-beta.1`.
- Confirm the Apple Developer portal App Group registration (see
  `Documentation/RELEASE_v1.1.0-beta.1.md` → Signing prerequisites).
- Then run `Documentation/BETA_RELEASE_COMMANDS.md`.

Any **FAIL** → record it in `BETA_QA.md` with repro detail; do **not** sign.
