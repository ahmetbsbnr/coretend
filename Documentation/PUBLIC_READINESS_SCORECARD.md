# Public Readiness Scorecard — session 3

Each axis scored independently, /100 possible on that axis alone (not a
weighted share of one grand total). Evidence points to the specific
session-1/2/3 doc that backs the score.

| Axis | Score | Why |
|---|---|---|
| Functionality | 70/100 | 34/42 features `VERIFIED_COMPLETE`, 8 partial/unverified (`FEATURE_INVENTORY.md`, generated from `feature-inventory.json`). Core scan/clean/quarantine paths solid; audit-log persistence now real (SQLite), a few view-layer paths still unverified or partial — see `Scripts/check-feature-inventory.sh`. |
| Data security | 80/100 | Single `Process()` call is argument-array-only, no shell injection surface; `PathValidator` blocklist+allowlist+symlink-escape; 0 secrets found; 0 `.env`/forbidden files tracked; CI has a dedicated `security.yml` (`SECURITY_AUDIT_CURRENT.md`, this session's CI audit). Points withheld: no external pen-test, no fuzzing of the file-path validator beyond unit tests. |
| Stability | 75/100 | 86/86 tests pass, release build target is warning-gated in CI. Points withheld: only ever run on one physical machine — no crash telemetry (by design, local-only) means real-world stability under varied hardware/macOS versions is unknown, not just unverified. |
| Tests | 75/100 | 86 tests, 27 suites, sub-second run time, exercises engines/persistence/duplicate-detection/totals-consistency. Points withheld: no UI/view-layer tests (SwiftUI view logic for Cloud Cleanup/My Clutter/Duplicates is `IMPLEMENTED_UNVERIFIED`), no `Process()`-invocation integration test for the real ClamAV binary. |
| Distribution | 55/100 | Packaging mechanics verified solid this session (checksums match, arm64 confirmed, extract/mount/launch/quit all clean, licenses ship). Points withheld heavily: unsigned/unnotarized, no public release exists, single-arch only, single-machine-tested. |
| Compatibility | 40/100 | `SUPPORTED_MACS.md`/`MACOS_VERSION_POLICY.md` state a policy but it is asserted, not tested against real hardware/OS variety — arm64-only, one physical Mac, one macOS version used across all sessions. |
| Accessibility | 60/100 | Reduce Motion/Reduce Transparency centralized in design-system components and confirmed present at the call sites that animate (this session's grep). VoiceOver descriptions exist for Protection's mesh view. Points withheld: no VoiceOver walkthrough performed, no automated accessibility audit tool run (Accessibility Inspector), coverage confirmed by code-reading not interaction testing. |
| Localization | 90/100 | 327/327 EN/FR key parity, 0 unused keys, 1 non-localized literal and it's correctly the product name (this session's fresh count, not just a line-count check like CI's). Points withheld: translation *quality* (is the French idiomatic/correct) not evaluated — only structural parity. |
| User docs | 80/100 | Extensive `Documentation/` set: FAQ, Installation, Troubleshooting, Uninstall, First Launch, Full Disk Access, Known Limitations all present and (per prior sessions) evidence-based rather than templated filler. |
| Dev docs | 85/100 | Architecture inventory, decisions log, RFC template, good-first-issues, CONTINUATION.md running log — unusually thorough for project age. |
| Open-source repo readiness | 65/100 | LICENSE/NOTICE/THIRD_PARTY present and internally mostly consistent (one dead-link defect found session 2, not yet fixed), issue templates + CODEOWNERS + dependabot.yml present (this session's CI audit), 3 real workflow files. Points withheld: repo has never actually been pushed anywhere (`git remote -v` empty across all 3 sessions) — "repo readiness" is judged on a local clone that has never faced a real PR, fork, or external contributor. |
| Legal | 60/100 | License split (Apache-2.0 code / CC-BY-4.0 docs) is coherent and real. Points withheld: `LICENSE`'s own cross-references are broken (session 2 finding, unresolved), website legal-identity placeholders unresolved (this session). |
| Privacy | 90/100 | Zero network code found anywhere in `Sources/` across two independent sweeps (session 2 + this session's re-check via the security/CI audit), zero telemetry, zero analytics on the website. |
| Website | 55/100 | Structurally sound (static HTML, no framework, no trackers, FR/EN parity across all 13 pages) — this session's audit. Points withheld: legal placeholders unresolved, no live download to offer, no automated a11y scan run, never deployed. |
| Support | 30/100 | Issue templates exist but point at a repo that isn't public; no other support channel verified. |
| Public operability | 35/100 | Everything needed to *build* a release exists and works; nothing needed to *operate* a public release (signing, hosting, a live repo, a support inbox) is in place yet. |

## Overall readiness level: **INTERNAL_READY**

Justification: the engineering artifact (app, tests, packaging pipeline,
CI, docs) is solid enough for internal/developer use and honest
self-auditing — 86/86 tests, clean security posture, real localization
parity, working packaging. It is not **TESTER_READY** yet because
distribution is unsigned/unnotarized (real Gatekeeper friction for anyone
who isn't the developer) and has never been tested off the one machine it
was built on. It is not **PUBLIC_BETA_READY** because there is no public
repo, no live website, and legal identity is still placeholder text. This
is not a pessimistic default — it is the level the actual evidence in
`DISTRIBUTION_AUDIT.md`, `WEBSITE_AUDIT.md`, and `TECHNICAL_DEBT.md`
supports, no lower and no higher.
