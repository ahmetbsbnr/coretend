// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Darwin

/// Distinguishes a real measurement from an absence of one. APFS Intelligence
/// never fabricates a value to fill a gap — every `.unavailable` carries a
/// human-readable reason, so the UI can say *why* rather than showing a
/// misleading zero. There is deliberately no `.estimated` case: nothing in
/// this vertical computes an estimate — every value here is either read
/// directly from a Foundation/Darwin API or reported as unavailable.
public enum APFSMetric<Value: Sendable & Equatable>: Sendable, Equatable {
    case measured(Value)
    case unavailable(reason: String)

    public var value: Value? {
        if case let .measured(value) = self { return value }
        return nil
    }

    public var isAvailable: Bool { value != nil }

    static func from(_ value: Value?, reason: @autoclosure () -> String) -> APFSMetric<Value> {
        if let value { return .measured(value) }
        return .unavailable(reason: reason())
    }
}

/// What CoreTend can determine about the volume containing a given path,
/// using only Foundation `URLResourceValues` and the Darwin `statfs` syscall
/// — no subprocess, no elevated privilege, no entitlement beyond what
/// CoreTend already has. See `Documentation/APFS_INTELLIGENCE.md` for the
/// exact meaning of each field and why some can be genuinely unavailable.
public struct APFSVolumeInfo: Sendable, Equatable {
    public let name: String
    /// The path this info was inspected for — not a resolved volume root
    /// (Foundation has no per-file resource key for "this volume's mount
    /// point"), so this is exactly the path `inspect(path:)` was called
    /// with, kept for display/debugging context only.
    public let inspectedPath: URL
    /// Raw filesystem type name from `statfs` (`"apfs"`, `"hfs"`, `"exfat"`,
    /// `"msdos"`, `"smbfs"`, `"nfs"`, …) — not localized, stable across macOS
    /// versions, safe to use for logic (unlike a human-facing format
    /// description string, which can vary by locale/OS version).
    public let filesystemTypeRaw: String
    public let isAPFS: Bool
    public let totalCapacity: APFSMetric<Int64>
    /// Raw available space (`volumeAvailableCapacityKey`) — what a normal
    /// write can use right now.
    public let availableCapacity: APFSMetric<Int64>
    /// `volumeAvailableCapacityForImportantUsageKey` verbatim — kept under
    /// its real Apple name and meaning ("space available if the system
    /// purges caches/snapshots for something the user cares about right
    /// now"), never renamed "Purgeable Space": that word implies a stable,
    /// user-actionable quantity this API does not promise.
    public let availableCapacityForImportantUsage: APFSMetric<Int64>
    /// `volumeAvailableCapacityForOpportunisticUsageKey` verbatim — space
    /// available for a lower-priority background task before it would need
    /// to purge anything important-usage would.
    public let availableCapacityForOpportunisticUsage: APFSMetric<Int64>

    /// Fraction of `totalCapacity` already used, only when both totals are
    /// real measurements — never a computed guess when either is missing.
    public var usedFraction: APFSMetric<Double> {
        guard let total = totalCapacity.value, total > 0, let available = availableCapacity.value else {
            return .unavailable(reason: "total or available capacity is unavailable")
        }
        return .measured(1 - Double(available) / Double(total))
    }
}

/// Reads real volume metrics for the volume containing a path. Every method
/// is a pure read — no filesystem mutation, no subprocess, no privileged
/// call — and takes an explicit path so tests target a disposable directory
/// instead of assuming the real boot volume's exact numbers.
public enum APFSVolumeInspector {
    public static func inspect(path: URL = FileManager.default.homeDirectoryForCurrentUser) -> APFSVolumeInfo {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityForOpportunisticUsageKey,
        ]
        let values = try? path.resourceValues(forKeys: keys)
        let fsType = filesystemTypeRaw(atPath: path.path)

        return APFSVolumeInfo(
            name: values?.volumeName ?? path.lastPathComponent,
            inspectedPath: path,
            filesystemTypeRaw: fsType ?? "unknown",
            isAPFS: fsType == "apfs",
            totalCapacity: .from(values?.volumeTotalCapacity.map(Int64.init),
                                  reason: "volumeTotalCapacityKey was not returned for this path"),
            availableCapacity: .from(values?.volumeAvailableCapacity.map(Int64.init),
                                      reason: "volumeAvailableCapacityKey was not returned for this path"),
            availableCapacityForImportantUsage: .from(
                values?.volumeAvailableCapacityForImportantUsage,
                reason: "volumeAvailableCapacityForImportantUsageKey was not returned for this path"),
            availableCapacityForOpportunisticUsage: .from(
                values?.volumeAvailableCapacityForOpportunisticUsage,
                reason: "volumeAvailableCapacityForOpportunisticUsageKey was not returned for this path"))
    }

    /// Raw `f_fstypename` from the Darwin `statfs` syscall — `nil` only if
    /// the syscall itself fails (e.g. the path doesn't exist). This is a
    /// plain libc call: no subprocess, no permission beyond reading the
    /// path's containing directory.
    static func filesystemTypeRaw(atPath path: String) -> String? {
        var buffer = statfs()
        guard statfs(path, &buffer) == 0 else { return nil }
        return withUnsafeBytes(of: &buffer.f_fstypename) { raw -> String? in
            guard let base = raw.baseAddress else { return nil }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
    }
}
