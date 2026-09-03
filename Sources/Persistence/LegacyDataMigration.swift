// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Reads a preference value out of the *old* bundle identifier's domain.
/// `UserDefaults.standard` cannot see it — it only ever reads the running
/// bundle's own domain — so this is abstracted both to make that explicit and
/// to keep the migration testable without touching the real preferences
/// database.
public protocol LegacyPreferenceSource: Sendable {
    func value(forKey key: String) -> Any?
}

/// Reads the real `~/Library/Preferences/<bundleID>.plist` domain.
public struct SystemPreferenceSource: LegacyPreferenceSource {
    let bundleIdentifier: String

    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }

    public func value(forKey key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, bundleIdentifier as CFString)
    }
}

/// One-time migration of local user data from the pre-rebrand identity
/// (MacCare Local) to the current one (CoreTend).
///
/// Design is spelled out in `Documentation/USER_DATA_RENAME_MIGRATION.md`.
/// The three properties that matter, and why:
///
/// - **Copy, never move.** The legacy directory is never modified, renamed,
///   or deleted. That single choice is what makes the whole migration
///   reversible: rolling back the rename means the old build finds its data
///   exactly where it left it. It also means the "backup" of this migration
///   is the untouched source itself.
/// - **Per-item, not transactional.** Each item (store, quarantine,
///   fingerprint cache) is copied independently and skipped if the
///   destination already exists. An interrupted run therefore resumes by
///   simply being run again, and a second run is a no-op rather than a
///   duplicate.
/// - **Never clobber an existing install.** If data already exists under the
///   new identity, it wins. Two rename attempts, or a reinstall over real
///   usage, must not silently overwrite live data.
///
/// Errors are reported, never swallowed: a partially-copied item is rolled
/// back and recorded as a failure, and the caller decides what to show.
/// Not `Sendable`: it holds a `FileManager` and a `UserDefaults`, neither of
/// which is. Construct and run it on whichever actor needs it — the work is
/// synchronous filesystem I/O with no concurrency of its own.
public struct LegacyDataMigration {

    // MARK: - Types

    public enum Status: String, Sendable, Codable {
        /// No legacy directory found — a fresh install, nothing to do.
        case noLegacyData
        /// Everything that could be copied was copied.
        case completed
        /// Some items were already present under the new identity and were
        /// left alone. Not an error.
        case completedWithSkips
        /// At least one item failed to copy. Partial copies were rolled back.
        case completedWithErrors
    }

    public struct Failure: Sendable, Equatable, Codable {
        public let item: String
        public let reason: String
    }

    public struct Report: Sendable, Equatable, Codable {
        public var status: Status
        public var legacySource: String?
        public var destination: String
        public var migrated: [String]
        public var skipped: [String]
        public var failures: [Failure]
        public var migratedPreferenceKeys: [String]
        public var date: Date

        public var didAnything: Bool { !migrated.isEmpty || !migratedPreferenceKeys.isEmpty }
    }

    // MARK: - Known legacy identities

    /// Directory names the product's data may live under from before the
    /// rename. Hardcoded constants, never guessed: a migration that goes
    /// looking for "something that looks like our data" is a migration that
    /// eventually copies someone else's.
    public static let legacyDirectoryNames = ["MacCareLocal", "MacCare Local"]

    /// The pre-rebrand bundle identifier, whose preference domain the OS
    /// keyed the old `UserDefaults` to.
    public static let legacyBundleIdentifier = "local.maccare.app"

    /// Current data directory name. Must match `Store.defaultPath()`.
    public static let currentDirectoryName = "CoreTend"

    /// Preference keys the app actually persists. Only these are copied —
    /// a blanket domain copy would drag along OS-managed junk (window
    /// frames, sandbox bookkeeping) keyed to the old identity.
    public static let preferenceKeys = ["menuBarEnabled", "onboardingDone", "onboardingStep"]

    /// Files and directories that make up the app's own data, in copy order.
    /// The SQLite sidecars must follow the main database file: copying a
    /// `-wal` without its database is worse than copying neither.
    static let itemNames = [
        "store.sqlite",
        "store.sqlite-wal",
        "store.sqlite-shm",
        "Quarantine",
        "watch-fingerprints.json",
    ]

    // MARK: - Stored properties

    let fileManager: FileManager
    let legacyRoots: [URL]
    let destination: URL
    let preferenceSource: LegacyPreferenceSource?
    let preferenceDestination: UserDefaults?

    // MARK: - Init

    /// Fully injectable initialiser — every test in
    /// `LegacyDataMigrationTests` drives this one against temp directories,
    /// so no test can ever touch the real `~/Library`.
    public init(
        fileManager: FileManager = .default,
        legacyRoots: [URL],
        destination: URL,
        preferenceSource: LegacyPreferenceSource? = nil,
        preferenceDestination: UserDefaults? = nil
    ) {
        self.fileManager = fileManager
        self.legacyRoots = legacyRoots
        self.destination = destination
        self.preferenceSource = preferenceSource
        self.preferenceDestination = preferenceDestination
    }

    /// The real-world configuration: legacy directories and destination under
    /// the user's Application Support, old preference domain, current defaults.
    public static func standard() throws -> LegacyDataMigration {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return LegacyDataMigration(
            legacyRoots: legacyDirectoryNames.map { support.appendingPathComponent($0, isDirectory: true) },
            destination: support.appendingPathComponent(currentDirectoryName, isDirectory: true),
            preferenceSource: SystemPreferenceSource(bundleIdentifier: legacyBundleIdentifier),
            preferenceDestination: .standard
        )
    }

    // MARK: - Running

    /// Runs the migration. Safe to call on every launch: with no legacy data
    /// it short-circuits, and with everything already migrated it reports
    /// skips and changes nothing.
    @discardableResult
    public func run() -> Report {
        var report = Report(
            status: .noLegacyData,
            legacySource: nil,
            destination: destination.path,
            migrated: [],
            skipped: [],
            failures: [],
            migratedPreferenceKeys: [],
            date: Date()
        )

        let prefKeys = migratePreferences()
        report.migratedPreferenceKeys = prefKeys

        guard let source = firstExistingLegacyRoot() else {
            // No legacy files. Preferences may still have moved (the two are
            // independent data classes keyed differently by the OS), so that
            // is reported rather than being lost to the early return.
            if !prefKeys.isEmpty { report.status = .completed }
            writeJournal(report)
            return report
        }
        report.legacySource = source.path

        // Created only now: an empty destination directory on a machine with
        // nothing to migrate would be litter.
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            report.status = .completedWithErrors
            report.failures.append(Failure(item: destination.lastPathComponent,
                                           reason: "could not create destination directory: \(error.localizedDescription)"))
            writeJournal(report)
            return report
        }

        for name in Self.itemNames {
            let from = source.appendingPathComponent(name)
            let to = destination.appendingPathComponent(name)

            guard fileManager.fileExists(atPath: from.path) else { continue }

            if fileManager.fileExists(atPath: to.path) {
                // Existing data under the new identity always wins.
                report.skipped.append(name)
                continue
            }

            do {
                try copyAtomically(from: from, to: to)
                report.migrated.append(name)
            } catch {
                report.failures.append(Failure(item: name, reason: error.localizedDescription))
            }
        }

        if !report.failures.isEmpty {
            report.status = .completedWithErrors
        } else if !report.skipped.isEmpty {
            report.status = .completedWithSkips
        } else {
            report.status = .completed
        }

        writeJournal(report)
        return report
    }

    // MARK: - Copying

    /// Copies via a temp name inside the destination directory, then renames
    /// into place. A crash mid-copy therefore leaves a stray temp file and an
    /// absent destination — which the next run treats as "not yet migrated"
    /// and redoes — rather than a truncated file that looks complete.
    func copyAtomically(from: URL, to: URL) throws {
        let temp = destination.appendingPathComponent(".migrating-\(UUID().uuidString)-\(to.lastPathComponent)")
        do {
            try fileManager.copyItem(at: from, to: temp)
            try fileManager.moveItem(at: temp, to: to)
        } catch {
            // Roll back this item's partial state. Never touches the source.
            try? fileManager.removeItem(at: temp)
            throw error
        }
    }

    func firstExistingLegacyRoot() -> URL? {
        legacyRoots.first { root in
            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: root.path, isDirectory: &isDir)
            return exists && isDir.boolValue
        }
    }

    // MARK: - Preferences

    /// Copies the app's own preference keys out of the old bundle identifier's
    /// domain. Existing values under the new identity are never overwritten,
    /// and the old domain's plist is never modified.
    func migratePreferences() -> [String] {
        guard let source = preferenceSource, let defaults = preferenceDestination else { return [] }
        var moved: [String] = []
        for key in Self.preferenceKeys {
            guard defaults.object(forKey: key) == nil else { continue }
            guard let value = source.value(forKey: key) else { continue }
            defaults.set(value, forKey: key)
            moved.append(key)
        }
        return moved
    }

    // MARK: - Journal

    /// Appends the run to a JSON journal beside the migrated data. A migration
    /// that leaves no trace of having run is a migration nobody can debug.
    func writeJournal(_ report: Report) {
        guard fileManager.fileExists(atPath: destination.path) else { return }
        let url = destination.appendingPathComponent("migration-log.json")
        var history: [Report] = []
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            history = (try? decoder.decode([Report].self, from: data)) ?? []
        }
        history.append(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(history) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Undoes what a *single* run created, for the case where a caller decides
    /// the migration should not have happened. Only removes items the given
    /// report lists as `migrated` — never items that were already there
    /// (`skipped`), and never anything in the legacy source.
    @discardableResult
    public func rollback(_ report: Report) -> [String] {
        var removed: [String] = []
        for name in report.migrated {
            let target = destination.appendingPathComponent(name)
            if fileManager.fileExists(atPath: target.path) {
                do {
                    try fileManager.removeItem(at: target)
                    removed.append(name)
                } catch {
                    continue
                }
            }
        }
        return removed
    }
}
