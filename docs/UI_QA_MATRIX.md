# UI QA matrix

Generated captures live in `Documentation/Captures/` via `Scripts/capture-matrix.sh`;
open `Documentation/Captures/index.html` for the side-by-side gallery. Last full run:
2026-09-19, 48 captures, 0 refused, every sidebar rendered. File name encodes
`<module>-<fixture>-<appearance>-<size>.png`; the app writes `showing.txt`
and the script refuses any capture whose module/appearance/size differ.

| Module | Fixtures | Sizes | Appearances | Extra |
|---|---|---|---|---|
| Overview | empty · seeded · attention (no FDA) | C S L | L D | Increase Contrast |
| Record | empty · seeded · many (2 000 rows) | C S L | L D | filter active, search active |
| Cleanup | idle · scanning · review (many) · done · no permission | S | L D | — |
| Explore › Map | idle · deep tree · one huge file | C S L | L D | — |
| Explore lenses | empty · seeded | S | D | — |
| Duplicates | empty · groups (200) · one group | C S L | L D | — |
| Applications | seeded (148) · leftovers · updates | S L | L D | — |
| Integrity | ok · problems · no FDA | S | L D | — |
| Performance | live | S | L D | — |
| Settings | default (Dev ID) · App Store | S | L D | — |
| Onboarding | step 1–3 · refused | S | L D | — |

Long-French pass: every module once in `fr` at compact width.
