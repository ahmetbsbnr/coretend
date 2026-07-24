# Security Audit — Session 2

Evidence: `grep -rn "rm -rf|sudo |Process(|/bin/sh|/bin/bash|try!|as!"` over `Sources/`, `Scripts/`, `.github/`,
plus a full read of `Sources/SafetyCore/SafetyCore.swift` and `Sources/MalwareEngine/MalwareEngine.swift`.
Commit at start of session `f1ec7d4`.

## Findings

### 1. Single `Process()` shell-out — LOW exploitability, mitigated
`Sources/MalwareEngine/MalwareEngine.swift:56`. Invokes a user-installed `clamscan` binary. Arguments passed as
a discrete `[String]` array (`process.arguments = [...]`), never through `/bin/sh -c`, so there is no shell
injection surface even with adversarial filenames. Binary path is restricted to 3 hardcoded, well-known install
locations (`MalwareEngine.swift:34-38`) checked with `isExecutableFile` — an attacker who can write to one of
those paths already has local code-execution equivalent capability, so this isn't a meaningfully new attack
surface. **Mitigation: adequate as-is.**

### 2. `rm -rf` usage in shell scripts — LOW, all in dev/test tooling, not shipped app code
Occurrences: `Scripts/clean.sh:16,20`, `Scripts/package-local.sh:7`, `Scripts/package-zip.sh:24`,
`Scripts/package-dmg.sh:24`, `Scripts/uninstall.sh:169`, `Scripts/uninstall-local.sh:56`,
`Scripts/test-uninstall.sh:55,62`, `Scripts/repository-doctor.sh:62`, `Scripts/test-distribution.sh:29`.
- `Scripts/uninstall.sh` (the public-facing uninstaller): comment at line 17 states it never needs sudo since
  every path is user-owned under `$HOME`; per `CONTINUATION.md` session notes it uses a canonicalized allowlist
  and refuses `/` and full `$HOME`. Not re-verified line-by-line this session (already audited/fixed in a prior
  session per orchestrator's explicit "already fixed, don't touch" instruction — out of scope to re-touch).
- `package-*.sh` / `clean.sh` targets are build-local staging directories (`$STAGE`, `$APP`), not user data.
- Test scripts (`test-uninstall.sh`, `test-distribution.sh`) operate on `mktemp -d` fake homes/temp dirs with
  `trap 'rm -rf ...' EXIT` cleanup — standard, safe pattern.
**No unquoted variable expansion found feeding these `rm -rf` calls in the grep sample** (all use `"$var"`
quoting or `--` separators). Not exhaustively re-audited char-by-char this session — flagged for scripts-audit
depth in session 3.

### 3. `sudo` — only appears in a negative/documentation context
`Scripts/test-release-manifest.sh:68` and `.github/workflows/security.yml:47-56` reference `sudo` only as
strings being *checked against* (a dangerous-command detector), not executed. `Scripts/uninstall.sh:17` states
sudo is never used. **No actual `sudo` invocation found anywhere in the tracked tree.**

### 4. Force-unwraps (`!`) — 4 real occurrences, all provably safe
Excluding `!=`, the repo-wide grep found exactly 4 force-unwrap sites (`) !` after a call), all on
compile-time-constant, hardcoded string literals passed to `URL(string:)!`/`Calendar.date(byAdding:...)!`:
- `Sources/CoreTendApp/AppUpdatesView.swift:40` — `URL(string: "macappstore://showUpdatesPage")!`
- `Sources/CoreTendApp/OnboardingView.swift:23` — `URL(string: "x-apple.systempreferences:...")!`
- `Sources/CoreTendApp/MyActivityView.swift:38-39` — `calendar.date(byAdding: .day, value: -7/-30, to: now)!`
  (adding a fixed small day offset to `Date()` cannot realistically fail on Gregorian calendar)
All four are on literal/constant inputs, not user- or filesystem-derived data — **no crash risk found**.
`SimilarImagesEngine.swift:104` hit is a substring match artifact of the grep pattern (`"...t!"` inside a
comment), not a force-unwrap. **No `as!` found anywhere in `Sources/`.**

### 5. `try?` usage — 46 occurrences in `CoreTendApp/*.swift` alone, not individually re-audited
Not exhaustively triaged this session (would require per-callsite review of whether a silently-swallowed error
could hide a security-relevant failure, e.g. a failed path validation being treated as "no findings"). Spot
check: `Store` initialization (`AppEnvironment.swift:11`) falls back to `:memory:` on failure — an honest
degradation, not a security bypass, since an in-memory store can't corrupt persisted data. **Flagged for
session 3 scripts/technical-debt audit if a full triage is wanted.**

### 6. GitHub workflow permissions — not deep-audited this session
`.github/workflows/{ci.yml,release-draft.yml,security.yml}` exist; `security.yml` already implements a
dangerous-command detector (curl|sh, unrestricted sudo) per the grep above. Full permissions-block review
(`permissions:` scoping, `pull_request_target` risk, secret exposure) is queued for the session-3 CI/GitHub
audit — not claimed here.

## Sub-scores (1–10, higher = safer; evidence-based, not aspirational)

| Dimension | Score | Basis |
|---|---|---|
| Deletion safety | 9/10 | `PathValidator` protected-root list + allowlist + symlink-escape resolution + re-validation at execute time + Trash-only (never `unlink`/`rm`) + dry-run default. Not 10 because the audit log is in-memory-only (finding above), so a completed deletion isn't durably logged for later forensic review. |
| System security | 8/10 | Single `Process()` call, argument-array (no shell), restricted binary paths, no `sudo`, no privilege escalation found anywhere in `Sources/`. Not fully audited: `try?` triage (finding 5). |
| Distribution security | UNKNOWN this session | Two real defects (SHA256SUMS drift, dmgSize mismatch) were already found and fixed in a prior session per orchestrator note; not re-verified fresh this session (deferred to session-3 `DISTRIBUTION_AUDIT.md` if budget allows). |
| Website security | UNKNOWN this session | Not audited — queued session 3. |
| Repo security | 8/10 | No secrets/hardcoded personal data found in tracked files (`check-private-data.sh` PASS per session 1, re-confirmed via `bash Scripts/test.sh` this session which includes the same suite indirectly — full historical `git log -p` sweep still not done, a known gap noted in `TEST_INVENTORY.md`). |
| Workflow security | UNKNOWN (partial) this session | `security.yml` has a real dangerous-command detector; full permissions-scope review not done — queued session 3. |

## Not audited this session (explicitly, not silently)
Full `try?`/`try!` per-callsite security triage beyond the counts above; GitHub workflow `permissions:` blocks;
website security; full historical git-log secret sweep; scripts other than the ones already grepped.
