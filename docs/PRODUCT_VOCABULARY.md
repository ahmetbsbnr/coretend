# Product vocabulary — canonical terms

One thing, one name, both languages. `CopyHonestyTests` guards the forbidden
column mechanically; the rest is enforced in review.

| Concept | English | Français | Never |
|---|---|---|---|
| Send to Trash | **move to the Trash** / "Moved to Trash" | **mettre à la corbeille** / « Mis à la corbeille » | delete, remove, clean (for the action), free, reclaim |
| Permanent deletion | CoreTend never does it | — | "delete" as a CoreTend verb |
| Skip a path forever | **exclude** | **exclure** | ignore, hide |
| Skip once | **skip** | **passer** | ignore |
| Undo a move | **put back** | **remettre** | restore (reserved for the Record event kind label), recover |
| Space used on disk | **used** | **utilisé** | occupied |
| Space that a move would take to the Trash | **moved to Trash** (after) / **would move to Trash** (before) | **mis à la corbeille** / **irait à la corbeille** | reclaimable, recoverable space, freed |
| Space actually back | not measurable — never stated | — | freed (real), reclaimed |
| Read-only pass over files | **scan** | **analyse** | check, inspect (reserved for Integrity) |
| Finding the scan proposes | **item** | **élément** | issue, problem |
| Something wrong that needs attention | **problem** | **problème** | issue, error (reserved) |
| Non-blocking notice | **notice** | **remarque** | warning (reserved for destructive confirmations) |
| CoreTend declined to touch | **refused** / "kept back" | **refusé** / « écarté » | skipped, ignored |
| Attempt that failed | **failed** | **échec** | error, couldn't |
| Path CoreTend never writes to | **protected** | **protégé** | system file, locked |
| Application bundle | **app** in UI, **application** in prose | **app** / **application** | program, software |
| Files an app leaves behind | **leftovers** | **résidus** | remnants, orphans |
| Support folders, caches, agents of an app | **associated files** | **fichiers associés** | components, dependencies |
| The audit history | **the Record** | **le registre** | log, activity, history |
| Row of the Record with file evidence | **operation** | **opération** | action, job |
| Row of the Record without file evidence | **event** | **événement** | activity |

Style:
- Sentence case everywhere except sidebar group labels and metric labels
  (small caps via `.textCase(.uppercase)`).
- No trailing period on labels, one on sentences. Ellipsis (…) on any control
  that opens something before acting.
- Numbers: `mcFormatBytes` for sizes; grouping separators from the locale;
  durations "4 min 11 s" / "22 s".
- French uses typographic apostrophes (’) and non-breaking spaces before
  `: ; ! ?` — check `LocalizationTypographyTests` (REMAINING_WORK E-03).
- Never claim to verify, guarantee, ensure or optimise.
