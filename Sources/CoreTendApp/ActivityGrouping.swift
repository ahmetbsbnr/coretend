// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// Groups activity records by calendar day, most recent day first, records
/// within a day kept in their incoming (already date-descending) order.
/// Pure/testable — no view or persistence dependency.
struct ActivityDayGroup: Identifiable {
    let day: Date
    let records: [ActivityRecord]
    var id: Date { day }
}

enum ActivityGrouping {
    static func byDay(_ records: [ActivityRecord], calendar: Calendar = .current) -> [ActivityDayGroup] {
        var order: [Date] = []
        var buckets: [Date: [ActivityRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(record)
        }
        return order.map { ActivityDayGroup(day: $0, records: buckets[$0] ?? []) }
    }
}

enum ActivityDateRange: String, CaseIterable, Identifiable {
    case all = "All time"
    case last7 = "Last 7 days"
    case last30 = "Last 30 days"

    var id: String { rawValue }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all: return true
        case .last7: return date >= calendar.date(byAdding: .day, value: -7, to: now)!
        case .last30: return date >= calendar.date(byAdding: .day, value: -30, to: now)!
        }
    }
}

/// Bytes moved to the Trash across cleanup records.
///
/// Named for what it measures. It was `movedToTrashBytes`, shown as "Freed (real)",
/// and it is neither: CoreTend moves items to the Trash and is never told when
/// the user empties it, so nothing here has been verified as freed. The word
/// "real" claimed a check the app never performed. Same arithmetic, honest
/// label — see Documentation/Mockups/COMPARISON.md, where the same fabricated
/// total is why mockup B3 was rejected.
struct ActivityImpactSummary {
    let movedToTrashBytes: Int64
    let itemCount: Int

    init(_ records: [ActivityRecord]) {
        movedToTrashBytes = records.filter { $0.kind == .cleanup }.reduce(0) { $0 + $1.bytes }
        itemCount = records.reduce(0) { $0 + $1.itemCount }
    }
}
