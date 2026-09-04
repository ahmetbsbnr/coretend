# ancien scanner externe removal — test count audit

Factual accounting of every test removed, modified, or added by
`eac408c` (refactor(protection): retire ancien scanner externe, replace with native Integrity
signals). Rationale for the removal itself is in `LEGACY_SCANNER_DECISION.md`; this
document only accounts for the test suite delta.

Verified directly by diffing `Tests/` between `eac408c~1` (24d7f13) and
`eac408c`, and by counting `@Test` occurrences across the whole tree at both
commits: **310 → 276**, a net decrease of 34. This is the delta for this one
commit only, not the wider gap since the 0.8.1 audit (274 tests) — many
unrelated commits (DMG layout, distribution/robustness tests, release
tooling) landed between the two and are not part of this accounting.

## Removed entirely (ancien scanner externe/LegacyScanner-specific, no replacement needed)

| File | Suite | Tests removed | Reason |
|---|---|---:|---|
| `Tests/LegacyScannerTests/LegacyScannerTests.swift` | ancien scanner externe output parsing (7); ancien scanner externeScanner process execution (5); Real ancien scanner externe fixture de signature scan (1); Quarantine (10) | 23 | Tested `ancien-scanner` output parsing, process execution, and the app-local Quarantine folder — all of it specific to the retired ancien scanner externe integration. |
| `Tests/LegacyScannerTests/ProtectionWatcherTests.swift` | ProtectionWatcher decisions | 16 | Tested the background FSEvents watcher that triggered ancien scanner externe scans on new files. The watcher itself was removed with the engine. |
| `Tests/LegacyScannerTests/WatcherStressTests.swift` | ProtectionWatcher burst | 1 | Stress test for the same removed watcher. |
| **Subtotal** | | **40** | |

Individual tests, for the record (all removed, no coverage loss — the
behavior they tested no longer exists in the product):
`parsesFoundLines`, `ignoresCleanAndNoise`, `missingBinaryReportsUnavailable`,
`honestScannedCountPrefersSummaryLineOverInputPathCount`,
`scannedCountFallsBackWhenSummaryLineMissing`, `argumentsArrayNeverUsesAShell`,
`defaultLimitsAddNoFlags`, `cleanResultReturnsNoFindings`,
`infectedResultReturnsFindingsAndDoesNotThrow`,
`errorExitThrowsScanFailedWithStderrDetail`,
`timeoutTerminatesAndThrowsPromptly`,
`taskCancellationTerminatesProcessAndThrowsCancelled`,
`realfixture de signatureFileIsDetected`, `quarantineAndRestoreRoundTrip`,
`deleteRemovesPermanently`, `quarantineRecordsRichMetadata`,
`restorePreservesOriginalPermissions`,
`restoreRecreatesMissingParentDirectory`,
`restoreNeverSilentlyOverwritesExistingFile`,
`restoreThrowsWhenQuarantinedFileIsMissingOnDisk`,
`restoreThrowsWhenVolumeIsMissing`,
`pathValidationRejectsRelativeOriginalPath`,
`deleteThrowsWhenQuarantinedFileAlreadyGone`,
`legacy-scannerAbsentReportsUnavailableAndNeverScans`,
`singleStableCleanFileGetsScannedOnce`,
`infectedFileRaisesAlertButIsNotQuarantined`, `deletedBeforeScanIsSkipped`,
`tempFileThatVanishesDuringStabilityWaitIsSkipped`,
`stillGrowingFileIsSkippedAsUnstable`, `unmountedVolumeIsSkipped`,
`repeatedSameFileIsDedupedAfterFirstScan`, `modifiedFileIsRescanned`,
`burstOfSamePathCoalescesToOneScan`, `disabledWatcherRefusesEvents`,
`consumeStreamScansEachDistinctFileAndStopsOnStop`,
`cancelledConsumeStopsProcessing`,
`renamedFileEvaluatesNewPathIndependentlyOfOldPath`,
`rateLimitEnforcesMinimumSpacingBetweenScanLaunches`,
`fingerprintsPersistAndDedupAcrossRestart`,
`largeBurstCoalescesToDistinctPathCount`.

## Removed partially (file kept, ancien scanner externe-specific tests/assertions removed)

| File | Removed | Kept / adjusted | Coverage loss? |
|---|---|---|---|
| `Tests/CoreTendAppTests/OnboardingLogicTests.swift` | 3 tests: `parsesFullancien scanner externeVersion`, `parsesEngineOnlyVersion`, `parsesGarbageSafely` (tested `ancien scanner externeVersionInfo.parse`, a type that no longer exists) | `missingOptionalsDegradeToLimited` and the "healthy" fixture kept, with `legacy-scannerAvailable`/`i.legacy-scannerAvailable` assertions stripped since the `SystemCheck.Inputs` field is gone | None — onboarding, diagnostics and preferences coverage (the categories called out as must-preserve) is intact; only the ancien scanner externe-specific slice was cut. |
| `Tests/CoreTendAppTests/DiagnosticReportTests.swift` | 0 tests removed | `legacy-scannerAvailable`/`legacy-scannerPath` fields in the test fixture renamed to `codeSignTier`/`codeSignValid` to match `DiagnosticReport.Inputs`'s new shape | None — same 3 tests, same redaction behavior under test, just relabeled fields. |

## Added (IntegrityCore, the replacement)

| File | Suite | Tests (as of eac408c) |
|---|---|---:|
| `Tests/IntegrityCoreTests/IntegrityCoreTests.swift` | ProvenanceScanner (5); CodeSignInspector (3); LoginItemScanner (1) | 9 |

## Categories the task brief asked to verify were preserved

Onboarding, diagnostics, preferences, hostile files, offline mode, process
errors, folder watching, security, integrity, localization — none of these
were reduced by this commit outside the ancien scanner externe-specific slice above:

- **Onboarding / diagnostics / preferences**: `OnboardingLogicTests.swift` and
  `DiagnosticReportTests.swift` both kept their non-ancien scanner externe coverage (see
  table above).
- **Hostile files, offline mode, process errors, folder watching**: none of
  the removed tests covered these outside the ancien scanner externe watcher's own scope
  (`ProtectionWatcherTests.swift` tested *its* watcher, not folder-watching in
  general — `ScanEngine`, `DuplicateEngine` and the rest of the app's own
  folder-scanning/watching code is untouched and still has its full suite,
  e.g. `symlinkedDirectoryNotDescended`, `missingRootYieldsFinishedNotError`,
  `cancellationStopsStream` under `Tests/ScanCoreTests`).
- **Security / integrity**: this is precisely what `IntegrityCoreTests.swift`
  now covers, extended below.
- **Localization**: `.strings` parity between `Base.lproj` and `fr.lproj` is
  enforced generically for the whole app by CI's "Localization key-parity
  check" step (`.github/workflows/ci.yml`), not a per-feature test. The
  Integrity strings already exist bilingually (`integrity.*` keys present in
  both files) and pass that gate.

## IntegrityCore test matrix added this phase (286 tests total after this work)

The original 9 tests above covered the two easy cases (quarantine present /
absent, Apple-signed, missing path, directory-skip, limit). Ten more were
added to reach the full matrix the phase brief asked for:

| Scenario requested | Test added | File |
|---|---|---|
| Fichier sans quarantaine | *(already covered)* `noQuarantine` | — |
| Fichier avec quarantaine | *(already covered)* `withQuarantine` | — |
| Métadonnées malformées | `malformedQuarantineMetadata` — raw garbage bytes via `setxattr`, not the clean setter API (see note below) | ProvenanceScannerTests |
| Signature Apple valide | *(already covered)* `appleSystemApp` | — |
| Signature Developer ID | `teamSignedBinary` — honestly `.enabled(if:)`-gated on a real non-Apple codesigning identity existing; skips with a stated reason in this environment (see Blocked below) | CodeSignInspectorTests |
| Signature ad hoc | `validAdHocSignature` — a real `codesign -s -` signed binary | CodeSignInspectorTests |
| Signature absente | *(already covered, strengthened)* `plainFileIsUnsigned` now also asserts `signatureValid == false` | — |
| Bundle corrompu | `corruptedBundle` — a `*.app` directory with a garbage `Info.plist`, no real bundle structure | CodeSignInspectorTests |
| Chemin inaccessible | `permissionDeniedFolder` / `permissionDeniedLocation` (chmod 000) | Provenance + LoginItem |
| LaunchAgent valide | `validLaunchAgent` — needed a small refactor, see below | LoginItemScannerTests |
| Plist malformé | `malformedPlist` | LoginItemScannerTests |
| Symlink | `symlinkedPlist` | LoginItemScannerTests |
| Dossier absent | `missingLocation` | LoginItemScannerTests |
| Permissions refusées | `permissionDeniedLocation` | LoginItemScannerTests |
| Localisation FR/EN | Covered generically by CI's key-parity gate, not a Swift test (see above) | — |

**Refactor required**: `LoginItemScanner.scan()` hardcoded the three real
system LaunchAgents/LaunchDaemons paths with no way to point it at a temp
directory, which is the only way to test "valid/malformed/missing/
permission-denied" without writing into the user's actual
`~/Library/LaunchAgents` — exactly the kind of real-per-user-store test
pollution this project's own `KNOWN_LIMITATIONS.md` already flags as a defect
elsewhere. Added `LoginItemScanner.defaultLocations()` and an optional
`locations:` parameter defaulting to it; both existing call sites
(`ProtectionView.swift`, the original `scanIsSafeAndLabeled` test) are
unchanged.

**Bug found and fixed while writing `validAdHocSignature`**: `CodeSignInspector`
checked bit `0x00000004` for "ad hoc", citing `Security/CSCommon.h`. A real
`codesign -s -` signature reports `flags=0x2(adhoc)` (verified with
`codesign -dvvv`, not assumed) — `0x2` is `CS_ADHOC` from `cs_blobs.h`; `0x4`
is the unrelated `CS_FORCED_LV` (hardened-runtime library validation) bit.
The effect in the shipped code: an ad-hoc-signed binary — a very common case
on macOS (locally built tools, some Homebrew binaries) — was misclassified
as `.teamSigned` instead of `.adHocOrUnsigned`, which is a real correctness
bug for a feature whose entire purpose is telling the user what actually
signed something. Fixed to check `0x00000002`.

**Blocked, not faked**: `teamSignedBinary` (Developer ID / any other non-Apple
team signature) cannot be exercised without a real signing identity —
`security find-identity -v -p codesigning` reports 0 in this environment
(same root cause as the signing/notarization blocker tracked in
`HUMAN_BLOCKERS.md` and `Configuration/DeveloperID/`). The test is gated with
`.enabled(if:)` against that same check, so it reports as *skipped* with a
stated reason rather than a fabricated pass. It will start running for real
the moment a Developer ID Application certificate is imported into the
keychain — no test code changes needed.

## Final count

`bash Scripts/test.sh`: **286 tests, 57 suites, 0 failures** (285 executed +
1 cleanly skipped pending the Developer ID identity). Debug and release
builds both clean, 0 warnings.
