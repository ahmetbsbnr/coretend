// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Reads and writes the single `WidgetSnapshot` JSON file in the CoreTend
/// App Group container. The host writes atomically; the widget only reads,
/// and every failure mode resolves to `.unavailable(reason:)` — never a
/// fabricated zero.
public struct WidgetSnapshotStore: Sendable {
    /// The App Group both the host and the widget declare in their
    /// entitlements. macOS App Group identifiers are used verbatim (no team
    /// prefix, unlike iOS). See `Documentation/MACOS_INTEGRATIONS.md`.
    public static let appGroupIdentifier = "group.com.ahmetbsbnr.coretend"

    /// File name inside the container. `v1` in the name so a future
    /// incompatible format can ship alongside without a migration.
    public static let fileName = "widget-snapshot.v1.json"

    public enum ReadResult: Equatable, Sendable {
        case snapshot(WidgetSnapshot)
        case unavailable(reason: Reason)

        public enum Reason: String, Equatable, Sendable {
            case appGroupUnavailable
            case fileMissing
            case unreadable
            case malformed
            case unsupportedFutureVersion
        }
    }

    private let containerURL: URL?

    /// Default: resolve the real App Group container. Tests inject an
    /// explicit directory so no entitlement is needed.
    public init(containerURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)) {
        self.containerURL = containerURL
    }

    public init(directory: URL) {
        self.containerURL = directory
    }

    public var fileURL: URL? {
        containerURL?.appendingPathComponent(Self.fileName)
    }

    // MARK: - Write (host only)

    /// Atomically publishes `snapshot`. Foundation's `.atomic` write is a
    /// temp-file-plus-rename, so a reader never sees a half-written file.
    @discardableResult
    public func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let fileURL else { return false }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Read (widget)

    public func read(now: Date = Date()) -> ReadResult {
        guard let fileURL else { return .unavailable(reason: .appGroupUnavailable) }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .unavailable(reason: .fileMissing)
        }
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return .unavailable(reason: .unreadable)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return .unavailable(reason: .malformed)
        }
        guard snapshot.schemaVersion <= WidgetSnapshot.currentSchemaVersion else {
            return .unavailable(reason: .unsupportedFutureVersion)
        }
        return .snapshot(snapshot)
    }
}
