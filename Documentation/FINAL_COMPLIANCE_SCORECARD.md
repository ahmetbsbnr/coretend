# Final Compliance Scorecard

AUDITED_SOURCE_COMMIT: `b7cad75` (HEAD at session-4 start). Computed from
`Documentation/requirements-traceability.json` (69 requirements, corrected this session — see
`Documentation/REQUIREMENTS_COMPLIANCE_SUMMARY.md` for the A11Y-003 correction). This is the
canonical scoring artifact required by the original audit brief's §23. Session 4 of the
requirements-reconciliation phase.

## Formula (per brief §23)

```
points(requirement) =
    1.00  if status == COMPLIANT_VERIFIED
    0.50  if status == COMPLIANT_PARTIAL
    0.25  if status == IMPLEMENTED_UNVERIFIED
    0.00  if status in {NON_COMPLIANT, BLOCKED_HUMAN, BLOCKED_ENVIRONMENT, UNKNOWN}

domain_score = sum(points) / count(requirements in domain)   [excluding DEFERRED_APPROVED / SUPERSEDED / NOT_APPLICABLE from both numerator and denominator]
```

MUST, SHOULD, and MAY are scored **separately** — never blended — because a MUST failure and a MAY
failure are not equivalent risk.

## Overall (all 69 requirements, priority breakdown)

| Priority | Count | Points earned | Points possible | Score |
|---|---|---|---|---|
| MUST | 54 | 44.25 | 54 | **81.9%** |
| SHOULD | 14 | 6.25 | 14 | **44.6%** |
| n/a (disclosed limitation — MAC-003) | 1 | 1.0 | 1 | 100% |
| **Total** | **69** | **51.5** | **69** | **74.6%** |

MUST breakdown: 39 COMPLIANT_VERIFIED, 6 COMPLIANT_PARTIAL, 9 IMPLEMENTED_UNVERIFIED,
**0 NON_COMPLIANT, 0 BLOCKED_***. No MUST requirement is NON_COMPLIANT or BLOCKED as of this
session (A11Y-003 correction removed the only MUST NON_COMPLIANT entry — see below). 15 of 54 MUST
requirements (27.8%) are still short of COMPLIANT_VERIFIED, which is what caps the verdict.

SHOULD breakdown: 4 COMPLIANT_VERIFIED, 4 COMPLIANT_PARTIAL, 1 IMPLEMENTED_UNVERIFIED,
1 NON_COMPLIANT (VIS-003), 1 BLOCKED_ENVIRONMENT (A11Y-002), 3 UNKNOWN. The lower SHOULD score is
expected and lower-stakes by design — SHOULD gaps do not cap the verdict the way MUST gaps do.

## Domain-by-domain breakdown

Points earned / points possible (score %) per domain, MUST and SHOULD/MAY shown separately.
Domains with no gaps at all in a priority tier are marked clean.

| Domain | MUST pts/poss (score) | Required actions (MUST) | SHOULD/MAY pts/poss (score) | Required actions (SHOULD/MAY) |
|---|---|---|---|---|
| ARCH | 2/2 (100%) | none | — | — |
| DIST | 2/2 (100%) | none | 0.5/1 (50%) | DIST-003 partial — see register |
| DOC | 2/2 (100%) | none | — | — |
| I18N | 1/1 (100%) | none | 0.5/2 (25%) | I18N-002 minor bare-string, I18N-003 unknown (pluralization/dates) |
| LEGAL | 4/4 (100%) | none | — | — |
| MAC | 2/2 (100%) | none | — | — |
| OSS | 1/1 (100%) | none | 1/1 (100%) | none |
| PRIV | 3/3 (100%) | none | — | — |
| PROD | 2/2 (100%) | none | 1.5/2 (75%) | PROD-004 partial |
| PROTECTION | 1/1 (100%) | none | — | — |
| SAFE | 6/6 (100%) | none | — | — |
| SEC | 3/3 (100%) | none | — | — |
| TEST | 1/1 (100%) | none | — | — |
| OPS | 1.25/2 (62.5%) | OPS-004 (IMPLEMENTED_UNVERIFIED) needs verification | 2/2 (100%) | none |
| WEB | 3.75/5 (75%) | WEB-003 partial, WEB-004 unverified — verify | — | — |
| FUNC | 7.0/10 (70%) | FUNC-003/005/008 partial, FUNC-006/007 unverified — module-by-module functional re-verification pass (queued since session 3) | — | — |
| A11Y | 0.5/1 (50%) | A11Y-003 partial — Increase Contrast handling still missing | 0.5/3 (16.7%) | A11Y-001 partial, A11Y-002 blocked (needs live VoiceOver+keyboard session), A11Y-004 unknown (chart text alternatives) |
| VIS | 0.75/2 (37.5%) | VIS-001 unverified (needs display), VIS-002 partial | 0/1 (0%) | VIS-003 NON_COMPLIANT — design-token drift (3 hardcoded colors, 25 raw font-size sites), real fix needed, out of this session's scope |
| MOTION | 0.5/2 (25%) | MOTION-001/002 both unverified — needs per-view animation audit + live idle/scanning capture | — | — |
| PERF | 0.5/2 (25%) | PERF-002/004 unverified — needs Instruments profiling | 0.25/2 (12.5%) | PERF-001 unverified, PERF-003 unknown |

**Points missing, MUST only, by domain**: FUNC −3.0, A11Y −0.5, VIS −1.25, MOTION −1.5, PERF −1.5,
OPS −0.75, WEB −1.25. Total MUST points missing: **9.75 of 54** (the 44.25/54 = 81.9% score above).

## Verdict

Per the brief: **no MUST requirement that is COMPLIANT_PARTIAL, IMPLEMENTED_UNVERIFIED,
NON_COMPLIANT, or BLOCKED_* permits FULLY_CONFORMING_VERIFIED.** 15 of 54 MUST requirements fall
into those categories, so FULLY_CONFORMING_VERIFIED is ruled out categorically, independent of the
percentage score.

Verdict tiers (as used by this scorecard, since the original brief names the five labels but not
numeric cutoffs — thresholds set here and documented for future-session consistency):

- **FULLY_CONFORMING_VERIFIED**: 100% MUST COMPLIANT_VERIFIED, zero exceptions.
- **FULLY_CONFORMING_UNVERIFIED_MANUAL**: all MUSTs functionally complete (no NON_COMPLIANT/BLOCKED),
  gaps are pure-verification-pending (IMPLEMENTED_UNVERIFIED only, no COMPLIANT_PARTIAL), MUST score ≥95%.
- **MOSTLY_CONFORMING**: zero NON_COMPLIANT/BLOCKED MUSTs, MUST score ≥75%, gaps include real
  partial-compliance items (not just verification-pending).
- **PARTIALLY_CONFORMING**: MUST score 50–75%, or any NON_COMPLIANT/BLOCKED MUST present.
  present.
- **NON_CONFORMING**: MUST score <50%, or safety/security-critical MUST is NON_COMPLIANT/BLOCKED.

**This audit's numbers**: MUST score 81.9%, zero NON_COMPLIANT MUST, zero BLOCKED_* MUST, but 6
COMPLIANT_PARTIAL MUSTs (real, not just verification-pending — e.g. VIS-002 anti-reference grep-only
check, FUNC-003 environment-blocked live scan, A11Y-003 half-handled contrast). This does not
qualify for FULLY_CONFORMING_UNVERIFIED_MANUAL (that tier requires zero COMPLIANT_PARTIAL MUSTs) but
clears the MOSTLY_CONFORMING bar (≥75%, zero NON_COMPLIANT/BLOCKED MUSTs).

### **VERDICT: MOSTLY_CONFORMING**

Justification: all safety-critical (SAFE), security (SEC), privacy (PRIV), legal (LEGAL), and
distribution (DIST MUST) domains are 100% COMPLIANT_VERIFIED — the areas where a false-positive
"fine" reading would be most dangerous are, in fact, fine. The shortfall is concentrated in domains
that are lower-stakes and honestly explainable: MOTION/VIS/PERF unverified items are environment-
blocked (no display/Instruments access this session, not a code defect), and FUNC gaps are a known,
already-queued module-by-module re-verification backlog. Zero MUST requirement is NON_COMPLIANT or
BLOCKED_HUMAN. This is a real, non-flattering, non-rounded-up verdict: it is not
FULLY_CONFORMING_VERIFIED and should not be represented as such anywhere in this documentation set.

## Cross-reference to the separate 41-feature audit vocabulary

This scorecard uses the **requirements-compliance vocabulary** (COMPLIANT_VERIFIED, etc., 69
requirements). A separate, earlier audit — `Documentation/FEATURE_INVENTORY.md` — uses a **different
vocabulary** (VERIFIED_COMPLETE, etc., 41 features, 31 verified) for a different question ("does
each named feature exist and work?" vs. "does the product meet each sourced requirement?"). The two
are not comparable line-for-line and should never be quoted interchangeably. See
`Documentation/PROJECT_COMPLETE_AUDIT.md` for the explicit cross-reference paragraph.
