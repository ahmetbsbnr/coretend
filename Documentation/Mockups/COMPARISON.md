# Phase 2 — three readings of direction B, compared

Direction B (`DESIGN_RESEARCH.md` §4.2): *the product is the record of what
changed and what is safe.* The Safety Log stops being a hidden screen and
becomes the spine.

Three mockups of **the same screen** — the record, as the app's home. Same
palette, same sidebar, same 1180×800 window. Rendered offline by
`Scripts/render-mockups.sh` into `Renders/`; the PNGs are the comparison, not
the prose.

| | B1 — the feed | B2 — list + inspector | B3 — the statement |
|---|---|---|---|
| Entries visible at 800 pt | **3½** | **8**, plus a full detail pane | **10** |
| Where an entry's detail lives | inline, expanding the card | a dedicated pane | nowhere |
| Where "put it all back" lives | on every card | on the selected entry | nowhere |
| Where a refusal's *reason* lives | inline | its own section | a 9-character pill |
| Native macOS precedent | none in the system | Mail, Console, Time Machine | Activity Monitor |

## Why not B1

The feed is the idiom every competitor already uses, and it is the one the
window cannot afford: 3½ entries in a full-height window against a header that
claims 1 284. Worse, it puts *undo* on every card at equal weight, so the
destructive-looking affordance is repeated 1 284 times down a scroll. The
ledger's point is that the record is long and the actions are deliberate; this
layout inverts both.

## Why not B3 — and this one is a correctness objection, not taste

B3 reads best at a glance, and its running `RECLAIMED` column is the reason to
reject it: **CoreTend cannot compute that number.** The app moves items to the
Trash. Whether space is actually reclaimed depends on the user emptying the
Trash, outside the app, at a time the app is not told about. A column that
looks like an audited balance but is really an optimistic sum of *intents* is
precisely the number this product exists in order not to print. The 21:06 row
in the mockup ("Trash emptied by macOS") is the tell: it is the only event that
moves real space, and it carries `—` in the change column.

A ledger may only show quantities it can stand behind. Cut that column and B3
becomes a table with nowhere to put per-item evidence, refusal reasoning, or
reversal — the three things direction B exists to make legible.

The summary strip above the table survives on its own merits, minus the
fabricated total. It is kept.

## Verdict — B2, with what the others proved

**B2 (list + inspector)** ships. It is the only one that holds the long record
and the deep evidence at once, and it is the one macOS itself already teaches:
Mail, Console, Time Machine. Selection carries the weight, so `Put it all back`
appears once, attached to one decided thing.

Absorbed from the other two:

- from **B3**: the summary strip over the list — *still reversible* and
  *refused* only, both of which are facts CoreTend owns;
- from **B1**: a refusal is a first-class entry with its own row and its own
  reason, never a footnote on someone else's entry.

## Two defects the renders found by measurement

Both were in all three mockups, and both would have shipped on looks alone.
Measured on `--raised` (#22272C), the surface they actually sit on:

| | before | after | note |
|---|---|---|---|
| timestamps, `--text3` #717D88 | **3.58:1** | 7.00:1 | in a ledger the time is the primary key, not decoration |
| neutral pill ink, `--slate` #8794A0 | **3.67:1** | 6.03:1 | `Read only` / `Final` are states, not chrome |

`--meta` and `--neutralInk` exist for exactly this: load-bearing metadata gets a
token that passes 4.5:1, and the muted tokens stay for rules and hairlines.
