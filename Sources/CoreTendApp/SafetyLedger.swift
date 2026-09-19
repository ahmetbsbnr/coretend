// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence
import SafetyCore

/// One operation, as the record shows it.
///
/// The audit trail stores one row per *file*; the record reads back one entry
/// per *operation*. `operation_id` already carried that grouping, so this is a
/// reading of what the database has always held, not a new schema.
///
/// An entry keeps the four stages apart rather than reducing them to a single
/// outcome. A refusal is not a failed execution and a failure is not a refusal:
/// flattening them is how "we declined to touch a protected file" and "we tried
/// and could not" end up looking identical to the person reading back.
struct LedgerEntry: Identifiable, Equatable {
    let operationID: String
    /// The latest event in the operation — when it finished, which is the time
    /// the user remembers doing it.
    let date: Date
    let moved: [SafetyLogRecord]
    let refused: [SafetyLogRecord]
    let failed: [SafetyLogRecord]
    let approved: [SafetyLogRecord]

    var id: String { operationID }

    /// Bytes of everything this operation successfully moved to the Trash.
    ///
    /// Deliberately *not* called "freed" or "reclaimed". CoreTend moves items
    /// to the Trash; whether the space comes back depends on the user emptying
    /// it, outside the app, at a time the app is never told about. This is a
    /// true statement about what CoreTend did, which is the only kind of
    /// quantity the record is allowed to print.
    var movedBytes: Int64 { moved.reduce(0) { $0 + $1.size } }

    var itemCount: Int { moved.count }

    /// True when every executed row went to the Trash, where macOS's own Put
    /// Back can return it.
    ///
    /// Not simply "something was moved": a file on a volume with no Trash is
    /// removed outright, and SafetyCore records that as a different result.
    /// Offering those as reversible would be the app inventing a way back
    /// that does not exist.
    var isReversible: Bool {
        !moved.isEmpty && moved.allSatisfy { $0.result == SafetyCenter.trashedResult }
    }

    /// Executed rows that did not go to the Trash. Shown as such.
    var removedOutright: [SafetyLogRecord] {
        moved.filter { $0.result == SafetyCenter.removedResult }
    }

    /// True when nothing was executed: the operation's whole content is what
    /// CoreTend declined to touch. These are entries in their own right, not
    /// footnotes on somebody else's.
    var isRefusalOnly: Bool { moved.isEmpty && failed.isEmpty && !refused.isEmpty }

    static func == (a: LedgerEntry, b: LedgerEntry) -> Bool {
        a.operationID == b.operationID && a.date == b.date
            && a.moved.map(\.id) == b.moved.map(\.id)
            && a.refused.map(\.id) == b.refused.map(\.id)
            && a.failed.map(\.id) == b.failed.map(\.id)
            && a.approved.map(\.id) == b.approved.map(\.id)
    }
}

/// One line of the record: either an operation with per-file evidence, or an
/// event the app noted without touching a file — a scan, a restore, an error.
///
/// Both come from the store, from two tables that grew separately: the audit
/// trail (`safety_log`, one row per file, grouped by operation) and the
/// activity table (one row per thing the app did, with a sentence). The
/// record reads them as one history. A cleanup appears in *both* tables, so
/// cleanup activity rows are dropped here — the operation, with its evidence,
/// is the one that is kept.
enum RecordItem: Identifiable, Equatable {
    case operation(LedgerEntry)
    case event(ActivityRecord)

    var id: String {
        switch self {
        case let .operation(entry): "op:\(entry.operationID)"
        case let .event(record): "ev:\(record.id)"
        }
    }

    var date: Date {
        switch self {
        case let .operation(entry): entry.date
        case let .event(record): record.date
        }
    }

    static func == (a: RecordItem, b: RecordItem) -> Bool { a.id == b.id && a.date == b.date }
}

/// Groups the flat, append-only audit trail into the entries the record shows.
/// Pure and free of persistence so it is directly testable.
enum SafetyLedger {

    /// Operations and events as one history, most recent first.
    ///
    /// Activity rows of kind `.cleanup` are excluded: the same cleanup is in
    /// the audit trail as an operation with per-file evidence, and showing it
    /// twice would double both the entry and the bytes in the summary.
    static func items(operations: [LedgerEntry], events: [ActivityRecord]) -> [RecordItem] {
        let kept = events.filter { $0.kind != .cleanup }.map(RecordItem.event)
        return (operations.map(RecordItem.operation) + kept)
            .sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
    }

    /// Entries, most recent first.
    ///
    /// Rows may arrive in any order and an operation's rows may be interleaved
    /// with another's — the sink appends as events happen, and two operations
    /// can overlap. Grouping is therefore by identity, never by adjacency.
    static func entries(from records: [SafetyLogRecord]) -> [LedgerEntry] {
        var buckets: [String: [SafetyLogRecord]] = [:]
        for record in records {
            buckets[record.operationID, default: []].append(record)
        }
        return buckets.map { operationID, rows in
            LedgerEntry(
                operationID: operationID,
                // Latest, not earliest: an operation is dated by when it
                // finished. `max` rather than `first` because the incoming
                // order is not guaranteed.
                date: rows.map(\.date).max() ?? .distantPast,
                moved: rows.filter { $0.stage == .executed }.sorted { $0.size > $1.size },
                refused: rows.filter { $0.stage == .skipped },
                failed: rows.filter { $0.stage == .error },
                approved: rows.filter { $0.stage == .approved })
        }
        // Ties broken by operation id so the order is total and the list does
        // not reshuffle between two reads of the same data.
        .sorted { $0.date == $1.date ? $0.operationID > $1.operationID : $0.date > $1.date }
    }

    /// What the record can say about itself across every entry.
    ///
    /// Two numbers, both of which CoreTend owns: how much it moved, and how
    /// many things it declined to touch. There is no all-time "reclaimed"
    /// total here, because there is no honest way to compute one.
    struct Summary: Equatable {
        var movedBytes: Int64 = 0
        var movedItems: Int = 0
        var refusedItems: Int = 0
        var failedItems: Int = 0
    }

    /// One day's items, most recent day first.
    struct DayGroup: Identifiable {
        let day: Date
        let entries: [RecordItem]
        var id: Date { day }
    }

    /// Groups entries by calendar day so a row can show only its time.
    ///
    /// The day heading is what makes a bare "14:32" unambiguous; without the
    /// grouping the list would be a column of times with no dates on it.
    /// Input order is preserved within a day, which for `entries(from:)` is
    /// already most-recent-first.
    static func byDay(_ entries: [RecordItem], calendar: Calendar = .current) -> [DayGroup] {
        var order: [Date] = []
        var buckets: [Date: [RecordItem]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(entry)
        }
        return order.map { DayGroup(day: $0, entries: buckets[$0] ?? []) }
    }

    static func summary(of entries: [LedgerEntry]) -> Summary {
        entries.reduce(into: Summary()) { total, entry in
            total.movedBytes += entry.movedBytes
            total.movedItems += entry.itemCount
            total.refusedItems += entry.refused.count
            total.failedItems += entry.failed.count
        }
    }
}
