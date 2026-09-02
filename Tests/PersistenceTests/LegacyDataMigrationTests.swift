// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import Persistence

/// Every test here runs entirely inside a temp directory tree. Nothing in this
/// file can reach `~/Library` — the migration takes its legacy roots and
/// destination as parameters precisely so that guarantee is structural rather
/// than a convention people have to remember.
private struct Sandbox {
    let root: URL
    let legacy: URL
    let legacyAlternate: URL
    let destination: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-migration-\(UUID().uuidString)", isDirectory: true)
        legacy = root.appendingPathComponent("MacCareLocal", isDirectory: true)
        legacyAlternate = root.appendingPathComponent("MacCare Local", isDirectory: true)
        destination = root.appendingPathComponent("CoreTend", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func migration(preferences: LegacyPreferenceSource? = nil,
                   defaults: UserDefaults? = nil) -> LegacyDataMigration {
        LegacyDataMigration(
            legacyRoots: [legacy, legacyAlternate],
            destination: destination,
            preferenceSource: preferences,
            preferenceDestination: defaults)
    }

    /// Builds a realistic legacy directory: a real SQLite store with real
    /// rows, a quarantine folder with a manifest, and the fingerprint cache.
    func seedLegacy(at dir: URL? = nil) throws -> URL {
        let target = dir ?? legacy
        let fm = FileManager.default
        try fm.createDirectory(at: target.appendingPathComponent("Quarantine"), withIntermediateDirectories: true)
        try Data("fingerprints".utf8).write(to: target.appendingPathComponent("watch-fingerprints.json"))
        try Data(#"[{"id":"q1"}]"#.utf8)
            .write(to: target.appendingPathComponent("Quarantine/manifest.json"))
        return target
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// Writes a genuine store with activity + exclusions + settings, so the
/// migration is exercised against a real database file rather than a
/// placeholder that happens to have the right name.
private func seedRealStore(at path: String) async throws {
    do {
        let store = try Store(path: path)
        try await store.recordActivity(ActivityRecord(
            kind: .cleanup, summary: "Smart Care run", itemCount: 7, bytes: 4_096))
        try await store.addExclusion(path: "/Users/someone/Keep/This")
        try await store.setSetting("securityProfile", value: "strict")
        try await store.setSetting("dryRunDefault", value: "false")
    }

    // This fixture represents a store written by the previous schema. The
    // current Store constructor has already applied v4, so roll back only the
    // migration marker after seeding; opening the migrated copy must then run
    // the real v4 removal exactly as an upgraded installation would.
    let db = try Database(path: path)
    try db.run("DELETE FROM schema_migrations WHERE version = 4")
}

/// `Any` is not `Sendable`, so the stub stores plist-shaped values as strings
/// and hands back the type each key really has. That keeps the stub honest
/// about types (a bool key returns a `Bool`) without an unchecked escape.
private struct StubPreferences: LegacyPreferenceSource {
    enum Value: Sendable {
        case bool(Bool)
        case int(Int)
        case string(String)

        var any: Any {
            switch self {
            case .bool(let v): v
            case .int(let v): v
            case .string(let v): v
            }
        }
    }

    let values: [String: Value]
    func value(forKey key: String) -> Any? { values[key]?.any }
}

/// An isolated defaults domain per test, so no test writes into the real
/// preferences of whatever binary is running the suite.
private func scratchDefaults() -> (UserDefaults, String) {
    let suite = "coretend.tests.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suite)!, suite)
}

@Suite("Legacy data migration")
struct LegacyDataMigrationTests {

    // MARK: - Nothing to do

    @Test func noLegacyDataLeavesEverythingAlone() throws {
        let box = try Sandbox()
        defer { box.cleanup() }

        let report = box.migration().run()

        #expect(report.status == .noLegacyData)
        #expect(report.legacySource == nil)
        #expect(report.migrated.isEmpty)
        #expect(report.didAnything == false)
        // Must not litter: no destination directory is created when there is
        // nothing to put in it.
        #expect(FileManager.default.fileExists(atPath: box.destination.path) == false)
    }

    // MARK: - The normal path

    @Test func normalMigrationCopiesEveryItemAndLeavesTheSourceUntouched() async throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try await seedRealStore(at: box.legacy.appendingPathComponent("store.sqlite").path)

        let report = box.migration().run()

        #expect(report.status == .completed)
        #expect(report.legacySource == box.legacy.path)
        #expect(report.migrated.contains("store.sqlite"))
        #expect(report.migrated.contains("Quarantine"))
        #expect(report.migrated.contains("watch-fingerprints.json"))
        #expect(report.failures.isEmpty)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: box.destination.appendingPathComponent("store.sqlite").path))
        #expect(fm.fileExists(atPath: box.destination.appendingPathComponent("Quarantine/manifest.json").path))

        // Non-destructive: the source is still fully intact.
        #expect(fm.fileExists(atPath: box.legacy.appendingPathComponent("store.sqlite").path))
        #expect(fm.fileExists(atPath: box.legacy.appendingPathComponent("Quarantine/manifest.json").path))
        #expect(fm.fileExists(atPath: box.legacy.appendingPathComponent("watch-fingerprints.json").path))
    }

    @Test func migratedStoreKeepsItsActivityExclusionsAndSettings() async throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try await seedRealStore(at: box.legacy.appendingPathComponent("store.sqlite").path)

        _ = box.migration().run()

        // The point of the whole migration: the user's real data is readable
        // under the new identity, not merely present as bytes.
        let migrated = try Store(path: box.destination.appendingPathComponent("store.sqlite").path)
        let activity = try await migrated.activity()
        #expect(activity.count == 1)
        #expect(activity.first?.summary == "Smart Care run")
        #expect(activity.first?.itemCount == 7)
        let exclusions = try await migrated.exclusions()
        #expect(exclusions.contains("/Users/someone/Keep/This"))
        #expect(try await migrated.setting("securityProfile") == "strict")
        #expect(try await migrated.setting("dryRunDefault") == nil,
                "the retired preview preference is removed during migration")
    }

    @Test func quarantineContentsSurviveTheMove() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        let quarantined = box.legacy.appendingPathComponent("Quarantine/infected-sample.bin")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: quarantined)

        _ = box.migration().run()

        let moved = box.destination.appendingPathComponent("Quarantine/infected-sample.bin")
        #expect(try Data(contentsOf: moved) == Data([0x00, 0x01, 0x02, 0x03]))
        // And the original quarantined file is still where it was.
        #expect(FileManager.default.fileExists(atPath: quarantined.path))
    }

    @Test func alternateLegacyDirectoryNameIsAlsoFound() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        // Only the space-separated variant exists.
        _ = try box.seedLegacy(at: box.legacyAlternate)

        let report = box.migration().run()

        #expect(report.status == .completed)
        #expect(report.legacySource == box.legacyAlternate.path)
        #expect(report.migrated.contains("Quarantine"))
    }

    // MARK: - Existing new-identity data

    @Test func existingNewDataIsNeverOverwritten() async throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try await seedRealStore(at: box.legacy.appendingPathComponent("store.sqlite").path)

        // A real CoreTend install already in use: different data, same name.
        try FileManager.default.createDirectory(at: box.destination, withIntermediateDirectories: true)
        let newStorePath = box.destination.appendingPathComponent("store.sqlite").path
        let newStore = try Store(path: newStorePath)
        try await newStore.recordActivity(ActivityRecord(
            kind: .scan, summary: "Already mine", itemCount: 1, bytes: 1))

        let report = box.migration().run()

        #expect(report.status == .completedWithSkips)
        #expect(report.skipped.contains("store.sqlite"))
        #expect(report.migrated.contains("store.sqlite") == false)

        // The in-use store is byte-for-byte the one that was already there.
        let after = try Store(path: newStorePath)
        let activity = try await after.activity()
        #expect(activity.count == 1)
        #expect(activity.first?.summary == "Already mine")

        // Items the new install did NOT have are still brought over — a
        // partial new install shouldn't lose its quarantine history.
        #expect(report.migrated.contains("Quarantine"))
    }

    @Test func secondRunChangesNothing() async throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try await seedRealStore(at: box.legacy.appendingPathComponent("store.sqlite").path)

        let first = box.migration().run()
        #expect(first.status == .completed)
        let fingerprint = try Data(contentsOf: box.destination.appendingPathComponent("watch-fingerprints.json"))

        let second = box.migration().run()

        #expect(second.status == .completedWithSkips)
        #expect(second.migrated.isEmpty)
        #expect(second.skipped.contains("store.sqlite"))
        #expect(try Data(contentsOf: box.destination.appendingPathComponent("watch-fingerprints.json")) == fingerprint)
    }

    // MARK: - Interruption and resumption

    @Test func interruptedRunResumesAndLeavesNoHalfCopiedItem() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try Data("legacy-store-bytes".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite"))

        // Simulate a crash mid-copy: a stale temp file from a previous run,
        // and the real destination item absent.
        try FileManager.default.createDirectory(at: box.destination, withIntermediateDirectories: true)
        let staleTemp = box.destination.appendingPathComponent(".migrating-abc123-store.sqlite")
        try Data("half-written".utf8).write(to: staleTemp)

        let report = box.migration().run()

        // The item is treated as not-yet-migrated and copied properly.
        #expect(report.migrated.contains("store.sqlite"))
        #expect(try Data(contentsOf: box.destination.appendingPathComponent("store.sqlite"))
                == Data("legacy-store-bytes".utf8))
        // A stale temp file is never mistaken for migrated data.
        #expect(FileManager.default.fileExists(atPath: staleTemp.path))
    }

    @Test func corruptDatabaseFileIsCopiedVerbatimAndNotSilentlyDropped() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        // Not valid SQLite at all.
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF])
        try garbage.write(to: box.legacy.appendingPathComponent("store.sqlite"))

        let report = box.migration().run()

        // The migration copies bytes; it does not validate or repair them.
        // Dropping an unreadable file would destroy the only evidence a user
        // has for recovering it.
        #expect(report.migrated.contains("store.sqlite"))
        #expect(try Data(contentsOf: box.destination.appendingPathComponent("store.sqlite")) == garbage)
        #expect(report.failures.isEmpty)
    }

    @Test func sqliteSidecarsMigrateWithTheirDatabase() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try Data("db".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite"))
        try Data("wal".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite-wal"))
        try Data("shm".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite-shm"))

        let report = box.migration().run()

        #expect(report.migrated.contains("store.sqlite"))
        #expect(report.migrated.contains("store.sqlite-wal"))
        #expect(report.migrated.contains("store.sqlite-shm"))
    }

    // MARK: - Failures

    @Test func unwritableDestinationIsReportedNotSwallowed() throws {
        let box = try Sandbox()
        defer {
            // Restore permissions first, or the cleanup itself fails.
            try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                   ofItemAtPath: box.destination.path)
            box.cleanup()
        }
        _ = try box.seedLegacy()
        try Data("db".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite"))

        try FileManager.default.createDirectory(at: box.destination, withIntermediateDirectories: true)
        // Read-only destination: every copy must fail.
        try FileManager.default.setAttributes([.posixPermissions: 0o500],
                                              ofItemAtPath: box.destination.path)

        let report = box.migration().run()

        #expect(report.status == .completedWithErrors)
        #expect(report.failures.isEmpty == false)
        #expect(report.migrated.isEmpty)
        // The source is untouched even on the failure path.
        #expect(FileManager.default.fileExists(atPath: box.legacy.appendingPathComponent("store.sqlite").path))
    }

    @Test func unreadableLegacyItemFailsThatItemOnly() throws {
        let box = try Sandbox()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: box.legacy.appendingPathComponent("store.sqlite").path)
            box.cleanup()
        }
        _ = try box.seedLegacy()
        let store = box.legacy.appendingPathComponent("store.sqlite")
        try Data("db".utf8).write(to: store)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: store.path)

        let report = box.migration().run()

        // One item fails, the rest still migrate — a single permission problem
        // must not cost the user their quarantine history too.
        #expect(report.status == .completedWithErrors)
        #expect(report.failures.contains { $0.item == "store.sqlite" })
        #expect(report.migrated.contains("Quarantine"))
        #expect(report.migrated.contains("watch-fingerprints.json"))
        // No partial file left behind for the failed item.
        #expect(FileManager.default.fileExists(
            atPath: box.destination.appendingPathComponent("store.sqlite").path) == false)
    }

    // MARK: - Rollback

    @Test func rollbackRemovesOnlyWhatThisRunCreated() async throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try await seedRealStore(at: box.legacy.appendingPathComponent("store.sqlite").path)

        // Pre-existing item under the new identity, which rollback must spare.
        try FileManager.default.createDirectory(at: box.destination, withIntermediateDirectories: true)
        try Data("mine".utf8).write(to: box.destination.appendingPathComponent("watch-fingerprints.json"))

        let migration = box.migration()
        let report = migration.run()
        #expect(report.skipped.contains("watch-fingerprints.json"))
        #expect(report.migrated.contains("store.sqlite"))

        let removed = migration.rollback(report)

        #expect(removed.contains("store.sqlite"))
        #expect(FileManager.default.fileExists(
            atPath: box.destination.appendingPathComponent("store.sqlite").path) == false)
        // The pre-existing file is still there, with its own content.
        #expect(try Data(contentsOf: box.destination.appendingPathComponent("watch-fingerprints.json"))
                == Data("mine".utf8))
        // And the legacy source is, as always, untouched — so rollback is
        // followed by a working old install, not an empty one.
        #expect(FileManager.default.fileExists(
            atPath: box.legacy.appendingPathComponent("store.sqlite").path))
    }

    @Test func migrationCanBeRerunAfterARollback() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()
        try Data("db".utf8).write(to: box.legacy.appendingPathComponent("store.sqlite"))

        let migration = box.migration()
        let first = migration.run()
        migration.rollback(first)
        let second = migration.run()

        #expect(second.migrated.contains("store.sqlite"))
        #expect(try Data(contentsOf: box.destination.appendingPathComponent("store.sqlite"))
                == Data("db".utf8))
    }

    // MARK: - Preferences

    @Test func onboardingAndMenuBarPreferencesMoveToTheNewDomain() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        let (defaults, suite) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacyPrefs = StubPreferences(values: [
            "menuBarEnabled": .bool(false),
            "onboardingDone": .bool(true),
            "onboardingStep": .int(4),
        ])

        let report = box.migration(preferences: legacyPrefs, defaults: defaults).run()

        #expect(Set(report.migratedPreferenceKeys) == ["menuBarEnabled", "onboardingDone", "onboardingStep"])
        #expect(defaults.bool(forKey: "onboardingDone") == true)
        #expect(defaults.integer(forKey: "onboardingStep") == 4)
        #expect(defaults.bool(forKey: "menuBarEnabled") == false)
        // A user who had already finished onboarding must not be shown it
        // again just because the app changed its name.
    }

    @Test func preferencesAlreadySetUnderTheNewIdentityWin() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        let (defaults, suite) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(9, forKey: "onboardingStep")

        let legacyPrefs = StubPreferences(values: ["onboardingStep": .int(2), "onboardingDone": .bool(true)])
        let report = box.migration(preferences: legacyPrefs, defaults: defaults).run()

        #expect(report.migratedPreferenceKeys.contains("onboardingStep") == false)
        #expect(defaults.integer(forKey: "onboardingStep") == 9)
        // The key that had no new value still migrates.
        #expect(report.migratedPreferenceKeys.contains("onboardingDone"))
    }

    @Test func preferencesMigrateEvenWithNoLegacyFilesOnDisk() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        let (defaults, suite) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Preferences and Application Support are independent data classes,
        // keyed differently by the OS. One can exist without the other.
        let report = box.migration(preferences: StubPreferences(values: ["onboardingDone": .bool(true)]),
                                   defaults: defaults).run()

        #expect(report.status == .completed)
        #expect(report.migratedPreferenceKeys == ["onboardingDone"])
        #expect(defaults.bool(forKey: "onboardingDone") == true)
    }

    @Test func unrelatedLegacyPreferenceKeysAreNotCopied() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        let (defaults, suite) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let report = box.migration(
            preferences: StubPreferences(values: [
                "onboardingDone": .bool(true),
                "NSWindow Frame MainWindow": .string("0 0 100 100"),
                "SomeOtherAppKey": .string("x"),
            ]),
            defaults: defaults).run()

        #expect(report.migratedPreferenceKeys == ["onboardingDone"])
        #expect(defaults.object(forKey: "NSWindow Frame MainWindow") == nil)
        #expect(defaults.object(forKey: "SomeOtherAppKey") == nil)
    }

    // MARK: - Journal

    @Test func everyRunIsJournalledBesideTheData() throws {
        let box = try Sandbox()
        defer { box.cleanup() }
        _ = try box.seedLegacy()

        let migration = box.migration()
        migration.run()
        migration.run()

        let log = box.destination.appendingPathComponent("migration-log.json")
        #expect(FileManager.default.fileExists(atPath: log.path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let history = try decoder.decode([LegacyDataMigration.Report].self, from: Data(contentsOf: log))
        #expect(history.count == 2)
        #expect(history.first?.status == .completed)
        #expect(history.last?.status == .completedWithSkips)
    }

    // MARK: - Constants

    @Test func migrationTargetsTheDirectoryTheStoreActuallyUses() throws {
        // If these ever drift, the migration would faithfully copy data into
        // a directory the app never reads.
        #expect(LegacyDataMigration.currentDirectoryName == "CoreTend")
        #expect(try Store.defaultPath().contains("/CoreTend/store.sqlite"))
        #expect(LegacyDataMigration.legacyBundleIdentifier == "local.maccare.app")
        #expect(LegacyDataMigration.legacyDirectoryNames == ["MacCareLocal", "MacCare Local"])
    }
}
