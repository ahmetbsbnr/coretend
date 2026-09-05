// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// The `kind` identifier the widget's `Widget` declares and the host passes
/// to `WidgetCenter.reloadTimelines`. Shared so the two can never drift.
public enum WidgetKind {
    public static let status = "CoreTendStatusWidget"
}

/// The small, intentionally low-sensitivity value the CoreTend host publishes
/// for its WidgetKit extension to read. It carries **aggregate numbers only**
/// — never a path, filename, restore-item name, image-metadata value, GPS
/// coordinate, security finding, or browser profile. A widget renders on the
/// desktop where anyone can see it; nothing here is more sensitive than
/// "how full is this disk".
///
/// Shared between the host (`CoreTendApp`, writer) and the widget extension
/// (reader) via a tiny SwiftPM library so there is exactly one definition and
/// the widget target links nothing that could scan or delete.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Bumped whenever the meaning of a field changes. A reader that sees a
    /// higher version than it understands treats the snapshot as
    /// unavailable rather than guessing.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var freeBytes: Int64
    public var totalBytes: Int64
    /// What the last completed Cleanup scan reported as potentially
    /// recoverable. `nil` when no Cleanup scan has ever completed.
    public var reclaimableBytes: Int64?
    /// Total change vs the previous comparable scan. Positive = grew.
    /// `nil` when there is not enough scan history to compare.
    public var sinceLastScanDeltaBytes: Int64?
    /// When the most recent scan of any kind completed. `nil` if none has.
    public var lastScanDate: Date?
    /// The kind of the most recent recorded activity — one of
    /// `scan` / `cleanup` / `restore` / `error`. Just the enum name, never
    /// a summary string. `nil` when there is no activity yet.
    public var lastActivityKind: String?

    public init(schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
                generatedAt: Date,
                freeBytes: Int64,
                totalBytes: Int64,
                reclaimableBytes: Int64? = nil,
                sinceLastScanDeltaBytes: Int64? = nil,
                lastScanDate: Date? = nil,
                lastActivityKind: String? = nil) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
        self.reclaimableBytes = reclaimableBytes
        self.sinceLastScanDeltaBytes = sinceLastScanDeltaBytes
        self.lastScanDate = lastScanDate
        self.lastActivityKind = lastActivityKind
    }

    /// A snapshot is stale once it is older than this. The widget still
    /// shows a stale snapshot (old data beats no data) but labels it as of
    /// its date so a glance is never misleading.
    public static let staleAfter: TimeInterval = 7 * 24 * 3600

    public func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(generatedAt) > Self.staleAfter
    }
}
