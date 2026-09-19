// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence
import SafetyCore

/// Deterministic scenarios that feed the real application.
///
/// ## The rule this is built to obey
///
/// There is **one** user interface. A fixture changes what the data source
/// returns; it never introduces a parallel "preview" view that production
/// never renders. A preview screen proves nothing about the app, because the
/// app is not what was photographed — and the two drift the moment anyone is
/// busy. Everything here therefore writes into the same isolated `Store` the
/// app opens normally, and hands the same view models the same types they get
/// from real hardware.
///
/// ## Safety
///
/// Gated behind the existing two-key marker: `CORETEND_TEST_MODE=1` **and** a
/// validated `CORETEND_TEST_STORE_DIR` under a temporary root. Both are
/// checked by `TestStoreOverride`, which refuses anything resolving into the
/// real home or a protected root. A normal launch cannot reach any of this,
/// and nothing here writes outside the throwaway directory it is given.
///
/// ## What a scenario is allowed to fake
///
/// Recorded history and the contents of a stand-in home directory: both are
/// things CoreTend genuinely reads, so seeding them exercises the real code
/// paths. Volume capacity is faked through an explicit seam
/// (`OverviewFacts.volumeProvider`) rather than by mounting disk images,
/// because "this Mac is 98% full" is a layout CoreTend must survive and no
/// developer's machine is going to be in that state on demand.
enum VisualBetaFixture: String, CaseIterable {
    /// A Mac that has been used and scanned. The default reading.
    case normal
    /// Enough history and findings to test density and scrolling.
    case dense
    /// A fresh install: nothing scanned, nothing recorded.
    case empty
    /// 98% full, which is the state the storage visualisation exists for.
    case diskFull
    /// An internal disk plus two externals, so the volume switcher is real.
    case multiVolume
    /// Many duplicate groups, for the comparison layout.
    case duplicates
    /// A large application inventory, for the dense table.
    case applications
    /// Operations that failed, so failure has a visual design.
    case errors
    /// Full Disk Access denied — the most common real-world degraded state.
    case permissionsDenied
    /// A scan in progress, captured mid-flight.
    case scanning
    /// A batch where some items moved and some were refused. The state the
    /// product's third interface principle says must never be flattened.
    case partial
    /// A long audit trail, for the Record module.
    case history

    static let environmentKey = "CORETEND_FIXTURE"

    /// The scenario this launch asked for, or nil for a normal launch.
    ///
    /// Requires the same validated marker the store override does, so a stray
    /// environment variable on a shipped build does nothing at all.
    static func requested(environment: [String: String] = ProcessInfo.processInfo.environment) -> VisualBetaFixture? {
        guard TestStoreOverride.isTestMarkerSet(environment: environment),
              TestStoreOverride.resolve(environment: environment).directory != nil,
              let raw = environment[environmentKey]?.lowercased(), !raw.isEmpty
        else { return nil }
        return VisualBetaFixture(rawValue: raw)
            ?? VisualBetaFixture.allCases.first { $0.rawValue.lowercased() == raw }
    }

    // MARK: - Volumes

    /// The volumes this scenario reports, or nil to read the real hardware.
    ///
    /// Sizes are stated in whole gigabytes so a capture's figures are stable
    /// and a reviewer can check the arithmetic by eye.
    var volumes: [OverviewFacts.FixtureVolume]? {
        func gb(_ n: Double) -> Int64 { Int64(n * 1_000_000_000) }
        switch self {
        case .diskFull:
            return [.init(name: "Macintosh HD", isInternal: true,
                          total: gb(494), free: gb(9.4))]
        case .multiVolume:
            return [
                .init(name: "Macintosh HD", isInternal: true, total: gb(994), free: gb(311)),
                .init(name: "Archive", isInternal: false, total: gb(4000), free: gb(612)),
                .init(name: "Scratch", isInternal: false, total: gb(2000), free: gb(1740)),
            ]
        case .empty:
            return [.init(name: "Macintosh HD", isInternal: true, total: gb(494), free: gb(470))]
        case .dense, .normal, .duplicates, .applications, .errors,
             .permissionsDenied, .scanning, .partial, .history:
            return [.init(name: "Macintosh HD", isInternal: true, total: gb(994), free: gb(214))]
        }
    }

    /// Whether this scenario reports Full Disk Access as missing.
    var fullDiskAccessDenied: Bool {
        self == .permissionsDenied
    }

    // MARK: - Seeding

    /// Writes this scenario's history into the isolated store.
    ///
    /// Dates are computed backwards from a fixed instant rather than from
    /// `Date()`, so two captures taken a minute apart produce the same
    /// relative phrasing and the gallery does not churn.
    func seed(into store: Store) async {
        let now = Self.anchorDate
        for record in activityRecords(now: now) {
            _ = try? await store.recordActivity(record)
        }
        for event in safetyEvents(now: now) {
            await store.recordSafetyEvent(event)
        }
    }

    /// A fixed instant, so fixtures are reproducible. Chosen rather than
    /// derived: `Date()` would make every capture differ from the last.
    static let anchorDate = Date(timeIntervalSince1970: 1_789_000_000)

    private func activityRecords(now: Date) -> [ActivityRecord] {
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        switch self {
        case .empty:
            return []

        case .scanning:
            return [ActivityRecord(kind: .scan, date: ago(72),
                                   summary: "Cleanup scan: 2,140 items found",
                                   itemCount: 2_140, bytes: 4_120_000_000)]

        case .permissionsDenied:
            return [ActivityRecord(kind: .scan, date: ago(30),
                                   summary: "Cleanup scan: 214 items found",
                                   itemCount: 214, bytes: 310_000_000)]

        case .errors:
            return [
                ActivityRecord(kind: .scan, date: ago(2),
                               summary: "Cleanup scan: 1,806 items found",
                               itemCount: 1_806, bytes: 7_400_000_000),
                ActivityRecord(kind: .error, date: ago(1.5),
                               summary: "3 items could not be moved",
                               itemCount: 3, bytes: 96_000_000),
                ActivityRecord(kind: .error, date: ago(1.2),
                               summary: "Volume became unavailable during the operation",
                               itemCount: 0, bytes: 0),
            ]

        case .partial:
            return [
                ActivityRecord(kind: .scan, date: ago(5),
                               summary: "Cleanup scan: 942 items found",
                               itemCount: 942, bytes: 2_300_000_000),
                ActivityRecord(kind: .cleanup, date: ago(4),
                               summary: "Moved 811 of 942 items; 131 refused",
                               itemCount: 811, bytes: 1_980_000_000),
            ]

        case .duplicates:
            return [
                ActivityRecord(kind: .scan, date: ago(6),
                               summary: "Duplicates scan: 1,284 items in 317 groups",
                               itemCount: 1_284, bytes: 22_600_000_000),
                ActivityRecord(kind: .scan, date: ago(48),
                               summary: "Cleanup scan: 3,006 items found",
                               itemCount: 3_006, bytes: 5_100_000_000),
            ]

        case .applications:
            return [
                ActivityRecord(kind: .scan, date: ago(9),
                               summary: "Applications inventory: 214 applications",
                               itemCount: 214, bytes: 96_400_000_000),
            ]

        case .dense, .history:
            var records: [ActivityRecord] = []
            // A trail with texture: scans of varying size, cleanups between
            // them, the occasional failure and restore. A history of one
            // repeated row proves nothing about a list.
            for day in 0..<34 {
                let base = Double(day) * 19.5
                records.append(ActivityRecord(
                    kind: .scan, date: ago(base + 1),
                    summary: "Cleanup scan: \(1_200 + day * 137) items found",
                    itemCount: 1_200 + day * 137,
                    bytes: Int64(900_000_000 + day * 121_000_000)))
                if day % 3 == 0 {
                    records.append(ActivityRecord(
                        kind: .cleanup, date: ago(base + 0.6),
                        summary: "Moved \(18 + day * 3) items to the Trash",
                        itemCount: 18 + day * 3,
                        bytes: Int64(24_000_000 + day * 9_400_000)))
                }
                if day % 7 == 4 {
                    records.append(ActivityRecord(
                        kind: .error, date: ago(base + 0.4),
                        summary: "1 item could not be moved",
                        itemCount: 1, bytes: 4_100_000))
                }
                if day % 11 == 5 {
                    records.append(ActivityRecord(
                        kind: .restore, date: ago(base + 0.2),
                        summary: "Restored \(2 + day % 4) items from the Trash",
                        itemCount: 2 + day % 4,
                        bytes: Int64(11_000_000 + day * 800_000)))
                }
            }
            return records

        case .normal, .diskFull, .multiVolume:
            return [
                ActivityRecord(kind: .scan, date: ago(20),
                               summary: "Cleanup scan: 2,418 items found",
                               itemCount: 2_418, bytes: 3_850_000_000),
                ActivityRecord(kind: .cleanup, date: ago(19),
                               summary: "Moved 64 items to the Trash",
                               itemCount: 64, bytes: 412_000_000),
                ActivityRecord(kind: .scan, date: ago(96),
                               summary: "Duplicates scan: 208 items in 47 groups",
                               itemCount: 208, bytes: 1_640_000_000),
                ActivityRecord(kind: .restore, date: ago(94),
                               summary: "Restored 2 items from the Trash",
                               itemCount: 2, bytes: 18_400_000),
            ]
        }
    }

    /// The safety trail. Refusals and failures are separate stages here for
    /// the same reason the product keeps them separate on screen: what
    /// CoreTend declined to touch is evidence, not a footnote on a failure.
    private func safetyEvents(now: Date) -> [SafetyAuditEvent] {
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        func event(_ stage: SafetyAuditEvent.Stage, _ path: String, _ rule: String,
                   _ risk: RiskLevel, _ size: Int64, _ date: Date,
                   _ result: String) -> SafetyAuditEvent {
            SafetyAuditEvent(operationID: UUID(), stage: stage, path: path, ruleID: rule,
                             risk: risk, size: size, date: date, result: result)
        }

        switch self {
        case .empty, .scanning:
            return []

        case .errors:
            return [
                event(.executed, "~/Library/Caches/com.example.app/Cache.db", "cache.application",
                      .low, 184_000_000, ago(1.6), "ok"),
                event(.error, "~/Library/Caches/com.vendor.tool/blobs", "cache.application",
                      .low, 62_000_000, ago(1.5), "posixError"),
                event(.error, "/Volumes/Archive/renders/frame_8841.exr", "media.large",
                      .medium, 34_000_000, ago(1.4), "volumeUnavailable"),
                event(.skipped, "~/Documents/Taxes 2025/receipts.zip", "archive.old",
                      .high, 91_000_000, ago(1.3), "pathChangedSinceApproval"),
            ]

        case .partial:
            return [
                event(.executed, "~/Library/Caches/com.example.app/Cache.db", "cache.application",
                      .low, 184_000_000, ago(4.2), "ok"),
                event(.executed, "~/Downloads/installer-2024.dmg", "download.installer",
                      .low, 1_400_000_000, ago(4.1), "ok"),
                event(.skipped, "~/Documents/Contracts/signed.pdf", "document.recent",
                      .high, 2_100_000, ago(4.0), "protectedLocation"),
                event(.skipped, "~/Desktop/thesis-final.docx", "document.recent",
                      .high, 8_400_000, ago(3.9), "recentlyModified"),
                event(.error, "~/Library/Containers/com.vendor.app/Data/tmp", "cache.container",
                      .medium, 46_000_000, ago(3.8), "permissionDenied"),
            ]

        default:
            var events: [SafetyAuditEvent] = []
            let paths = [
                ("~/Library/Caches/com.example.browser/Code Cache", "cache.application", RiskLevel.low, Int64(412_000_000)),
                ("~/Downloads/Xcode_16.2.xip", "download.installer", .low, 9_100_000_000),
                ("~/Library/Logs/DiagnosticReports/crash-2026.ips", "log.diagnostic", .low, 2_400_000),
                ("~/Movies/screen-recording-04.mov", "media.large", .medium, 1_840_000_000),
                ("~/Library/Developer/Xcode/DerivedData/App-abcdef", "developer.derived", .low, 6_200_000_000),
                ("~/Documents/Archive/2019.zip", "archive.old", .high, 740_000_000),
            ]
            let count = (self == .dense || self == .history) ? 42 : 9
            for index in 0..<count {
                let (path, rule, risk, size) = paths[index % paths.count]
                let stage: SafetyAuditEvent.Stage = index % 9 == 7 ? .skipped : .executed
                events.append(event(stage, path, rule, risk,
                                    size / Int64(index % 5 + 1),
                                    ago(Double(index) * 5.5 + 2),
                                    stage == .skipped ? "protectedLocation" : "ok"))
            }
            return events
        }
    }
}
