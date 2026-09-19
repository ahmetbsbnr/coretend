// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
import Persistence
import SafetyCore
@testable import CoreTendApp

private func record(_ id: Int64, _ operation: String, _ stage: SafetyAuditEvent.Stage,
                    size: Int64 = 0, at offset: TimeInterval = 0,
                    path: String = "<home>/…/file") -> SafetyLogRecord {
    SafetyLogRecord(id: id, operationID: operation, stage: stage, redactedPath: path,
                    ruleID: "rule", risk: "low", size: size,
                    date: Date(timeIntervalSince1970: 1_700_000_000 + offset), result: "ok")
}

@Suite("The record groups the audit trail into operations")
struct SafetyLedgerGroupingTests {

    /// The sink appends as events happen, and two operations can overlap, so
    /// an operation's rows are not necessarily adjacent. Grouping by adjacency
    /// would split one operation into several entries the user never performed.
    @Test func interleavedOperationsStayWhole() {
        let entries = SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 10, at: 0),
            record(2, "B", .executed, size: 20, at: 1),
            record(3, "A", .executed, size: 30, at: 2),
            record(4, "B", .skipped, at: 3),
        ])
        #expect(entries.count == 2)
        let a = try! #require(entries.first { $0.operationID == "A" })
        #expect(a.itemCount == 2)
        #expect(a.movedBytes == 40)
    }

    /// An operation is dated by when it finished, and the incoming order is
    /// not guaranteed, so the date must come from the maximum rather than
    /// from whichever row happened to arrive first.
    @Test func anEntryIsDatedByItsLastEvent() {
        let entries = SafetyLedger.entries(from: [
            record(1, "A", .executed, at: 500),
            record(2, "A", .executed, at: 100),
        ])
        #expect(entries[0].date == Date(timeIntervalSince1970: 1_700_000_500))
    }

    @Test func entriesAreMostRecentFirst() {
        let entries = SafetyLedger.entries(from: [
            record(1, "old", .executed, at: 0),
            record(2, "new", .executed, at: 900),
            record(3, "mid", .executed, at: 400),
        ])
        #expect(entries.map(\.operationID) == ["new", "mid", "old"])
    }

    /// Dictionary iteration has no defined order. Without a tiebreaker two
    /// reads of identical data could return different orders and the list
    /// would reshuffle under the user between refreshes.
    @Test func equalDatesStillProduceAStableOrder() {
        let rows = [record(1, "A", .executed, at: 0), record(2, "B", .executed, at: 0)]
        let first = SafetyLedger.entries(from: rows).map(\.operationID)
        for _ in 0..<50 {
            #expect(SafetyLedger.entries(from: rows).map(\.operationID) == first)
        }
        #expect(first == ["B", "A"])
    }

    @Test func anEmptyTrailHasNoEntries() {
        #expect(SafetyLedger.entries(from: []).isEmpty)
    }
}

@Suite("Refusals and failures stay distinct")
struct SafetyLedgerStageTests {

    /// The four stages mean four different things. A refusal is not a failed
    /// execution: flattening them makes "we declined to touch a protected
    /// file" and "we tried and could not" read identically.
    @Test func eachStageLandsInItsOwnBucket() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .approved),
            record(2, "A", .executed, size: 7),
            record(3, "A", .skipped),
            record(4, "A", .error),
        ])[0]
        #expect(entry.approved.count == 1)
        #expect(entry.moved.count == 1)
        #expect(entry.refused.count == 1)
        #expect(entry.failed.count == 1)
    }

    /// An operation whose entire content is what CoreTend declined to touch is
    /// an entry in its own right — direction B's whole point is that a refusal
    /// is a first-class record, not a footnote on somebody else's entry.
    @Test func anOperationThatOnlyRefusedIsStillAnEntry() {
        let entries = SafetyLedger.entries(from: [
            record(1, "A", .skipped), record(2, "A", .skipped),
        ])
        #expect(entries.count == 1)
        #expect(entries[0].isRefusalOnly)
        #expect(entries[0].movedBytes == 0)
        #expect(!entries[0].isReversible)
    }

    @Test func anOperationThatFailedIsNotCalledARefusal() {
        let entry = SafetyLedger.entries(from: [record(1, "A", .error)])[0]
        #expect(!entry.isRefusalOnly)
    }

    /// Only executed rows count towards the quantity. An approval is an
    /// intention and a refusal is an absence; counting either as moved bytes
    /// would inflate the one number the record puts in front of the user.
    @Test func onlyExecutedRowsCountTowardsBytes() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .approved, size: 1_000),
            record(2, "A", .skipped, size: 2_000),
            record(3, "A", .error, size: 4_000),
            record(4, "A", .executed, size: 8),
        ])[0]
        #expect(entry.movedBytes == 8)
        #expect(entry.itemCount == 1)
    }

    @Test func theLargestItemLeadsAnEntry() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 5, path: "small"),
            record(2, "A", .executed, size: 500, path: "big"),
        ])[0]
        #expect(entry.moved.first?.redactedPath == "big")
    }
}

@Suite("The record's summary only claims what CoreTend owns")
struct SafetyLedgerSummaryTests {

    @Test func totalsAddUpAcrossEntries() {
        let summary = SafetyLedger.summary(of: SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 100),
            record(2, "A", .skipped),
            record(3, "B", .executed, size: 50, at: 10),
            record(4, "B", .error, at: 10),
        ]))
        #expect(summary.movedBytes == 150)
        #expect(summary.movedItems == 2)
        #expect(summary.refusedItems == 1)
        #expect(summary.failedItems == 1)
    }

    /// Guards the decision recorded in Documentation/Mockups/COMPARISON.md.
    /// `Summary` deliberately has no all-time "reclaimed" or "freed" figure:
    /// CoreTend moves items to the Trash and is never told when the user
    /// empties it, so no such number can be computed honestly. If one is ever
    /// added, this fails and the reasoning has to be revisited on purpose.
    @Test func thereIsNoReclaimedTotal() {
        let mirror = Mirror(reflecting: SafetyLedger.Summary())
        let names = mirror.children.compactMap(\.label).map { $0.lowercased() }
        #expect(names == ["movedbytes", "moveditems", "refuseditems", "faileditems"])
        for forbidden in ["freed", "reclaimed", "recovered", "saved"] {
            #expect(!names.contains { $0.contains(forbidden) },
                    "Summary gained a '\(forbidden)' total the app cannot compute")
        }
    }

    @Test func anEmptyRecordSummarisesToZero() {
        #expect(SafetyLedger.summary(of: []) == SafetyLedger.Summary())
    }
}

@Suite("How an entry reads")
struct RecordPhrasingTests {

    /// An operation that moved 1.24 GB and hit one permission error is a move
    /// with a failure in it, not a failure. Titling it by the failure buried
    /// the substance and contradicted its own subtitle — caught by capturing
    /// the module against a seeded store, not by looking at a mockup.
    @Test func amoveWithOneFailureIsStillTitledAsAMove() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 1_200_000_000),
            record(2, "A", .executed, size: 40_000_000),
            record(3, "A", .error),
        ])[0]
        let title = RecordPhrasing.title(entry)
        #expect(title.contains("2"))
        #expect(!title.lowercased().contains("could not"))
        // The failure is not lost — it is in the subtitle and its own section.
        #expect(RecordPhrasing.subtitle(entry).contains("1"))
        #expect(entry.failed.count == 1)
    }

    @Test func afailureOnlyOperationIsTitledAsAFailure() {
        let entry = SafetyLedger.entries(from: [record(1, "A", .error)])[0]
        #expect(RecordPhrasing.title(entry).lowercased().contains("could not"))
    }

    @Test func arefusalOnlyOperationIsTitledAsARefusal() {
        let entry = SafetyLedger.entries(from: [record(1, "A", .skipped)])[0]
        #expect(RecordPhrasing.title(entry).lowercased().contains("refused"))
    }

    /// "1 items could not be moved" shipped in the first capture. Counts of
    /// one take a singular form, in every language the app carries.
    @Test func aCountOfOneIsSingular() {
        let moved = SafetyLedger.entries(from: [record(1, "A", .executed, size: 10)])[0]
        #expect(RecordPhrasing.title(moved) == "Moved 1 item to the Trash")
        let failed = SafetyLedger.entries(from: [record(1, "B", .error)])[0]
        #expect(RecordPhrasing.title(failed) == "1 item could not be moved")
        let refused = SafetyLedger.entries(from: [record(1, "C", .skipped)])[0]
        #expect(RecordPhrasing.title(refused) == "Refused to touch 1 item")
    }

    @Test func aCountAboveOneIsPlural() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 10), record(2, "A", .executed, size: 20),
        ])[0]
        #expect(RecordPhrasing.title(entry) == "Moved 2 items to the Trash")
    }

    /// "0 refused" on an operation that refused nothing is noise dressed up as
    /// information. A component only appears when it has something to say.
    @Test func zeroCountsAreOmittedFromTheSubtitle() {
        let entry = SafetyLedger.entries(from: [record(1, "A", .executed, size: 1024)])[0]
        let subtitle = RecordPhrasing.subtitle(entry)
        #expect(!subtitle.contains("0"))
        #expect(!subtitle.contains("·"))
    }

    @Test func aSubtitleJoinsOnlyWhatItHas() {
        let entry = SafetyLedger.entries(from: [
            record(1, "A", .executed, size: 1024), record(2, "A", .skipped),
        ])[0]
        #expect(RecordPhrasing.subtitle(entry).contains("·"))
        #expect(RecordPhrasing.subtitle(entry).contains("1 refused"))
    }
}

@Suite("Operations and events read as one history")
struct RecordItemMergeTests {
    private func event(_ id: Int64, _ kind: ActivityRecord.Kind, at offset: TimeInterval,
                       bytes: Int64 = 0) -> ActivityRecord {
        ActivityRecord(id: id, kind: kind, date: Date(timeIntervalSince1970: 1_700_000_000 + offset),
                       summary: "summary \(id)", itemCount: 3, bytes: bytes)
    }

    /// A cleanup is written to both tables by the same action. Showing the
    /// activity row as well as the operation would list the cleanup twice and,
    /// worse, count its bytes twice in the summary the person reads first.
    @Test func aCleanupIsNotListedTwice() {
        let ops = SafetyLedger.entries(from: [record(1, "A", .executed, size: 100)])
        let items = SafetyLedger.items(operations: ops, events: [event(9, .cleanup, at: 0, bytes: 100)])
        #expect(items.count == 1)
        if case .operation = items[0] {} else { Issue.record("the operation, with its evidence, is the one kept") }
    }

    @Test func scansRestoresAndErrorsAreKept() {
        let items = SafetyLedger.items(operations: [], events: [
            event(1, .scan, at: 0), event(2, .restore, at: 1), event(3, .error, at: 2),
        ])
        #expect(items.count == 3)
    }

    /// The two sources interleave by date. A scan from this morning sits
    /// above yesterday's cleanup, whichever table it came from.
    @Test func sourcesInterleaveByDate() {
        let ops = SafetyLedger.entries(from: [record(1, "old", .executed, size: 1, at: 0)])
        let items = SafetyLedger.items(operations: ops, events: [event(5, .scan, at: 500)])
        #expect(items.first?.id == "ev:5")
        #expect(items.last?.id == "op:old")
    }

    @Test func idsCannotCollideAcrossSources() {
        let ops = SafetyLedger.entries(from: [record(1, "7", .executed, size: 1)])
        let items = SafetyLedger.items(operations: ops, events: [event(7, .scan, at: 0)])
        #expect(Set(items.map(\.id)).count == 2)
    }

    @Test func dayGroupingWorksAcrossSources() {
        let ops = SafetyLedger.entries(from: [record(1, "A", .executed, size: 1, at: 0)])
        let items = SafetyLedger.items(operations: ops, events: [event(2, .scan, at: 60)])
        let days = SafetyLedger.byDay(items)
        #expect(days.count == 1)
        #expect(days[0].entries.count == 2)
    }
}

@Suite("Reversible means the Trash can give it back")
struct LedgerReversibilityTests {
    private func executed(_ id: Int64, _ operation: String, result: String) -> SafetyLogRecord {
        SafetyLogRecord(id: id, operationID: operation, stage: .executed, redactedPath: "<home>/…/f",
                        ruleID: "rule", risk: "low", size: 10,
                        date: Date(timeIntervalSince1970: 1_700_000_000), result: result)
    }

    /// A file on a volume with no Trash is removed outright. Calling that
    /// entry reversible sends someone looking in the Trash for something that
    /// is not there.
    @Test func anOperationThatRemovedOutrightIsNotReversible() {
        let entry = SafetyLedger.entries(from: [
            executed(1, "A", result: SafetyCenter.removedResult),
        ])[0]
        #expect(!entry.isReversible)
        #expect(entry.removedOutright.count == 1)
    }

    /// One removed row is enough: the entry cannot promise the Trash can
    /// return everything it lists.
    @Test func aMixedOperationIsNotReversible() {
        let entry = SafetyLedger.entries(from: [
            executed(1, "A", result: SafetyCenter.trashedResult),
            executed(2, "A", result: SafetyCenter.removedResult),
        ])[0]
        #expect(!entry.isReversible)
        #expect(entry.removedOutright.count == 1)
    }

    @Test func anOperationThatOnlyTrashedIsReversible() {
        let entry = SafetyLedger.entries(from: [
            executed(1, "A", result: SafetyCenter.trashedResult),
            executed(2, "A", result: SafetyCenter.trashedResult),
        ])[0]
        #expect(entry.isReversible)
        #expect(entry.removedOutright.isEmpty)
    }
}

/// Every interpolated key family actually resolves.
///
/// The Record's filter labels are built as `L("record.filter_\(rawValue)")`.
/// A tidy-up that removed "unused" keys deleted all five, and nothing failed:
/// `L` returns the key itself, so the toolbar shipped a picker reading
/// "record.filter_all". Enumerating the family is the only check that can
/// catch it, because the whole key is never a literal anywhere.
@Suite("Interpolated key families resolve")
@MainActor
struct InterpolatedKeyTests {
    @Test func everyRecordFilterHasALabel() {
        for filter in RecordViewModel.Filter.allCases {
            #expect(filter.label != "record.filter_\(filter.rawValue)",
                    "missing string for record.filter_\(filter.rawValue)")
            #expect(!filter.label.contains("record."), "\(filter.label) looks like a key")
        }
    }

    @Test func everyRecordEventKindHasATitle() {
        for kind in ActivityRecord.Kind.allCases {
            let title = RecordPhrasing.eventTitle(
                ActivityRecord(kind: kind, summary: "", itemCount: 0, bytes: 0))
            #expect(!title.hasPrefix("record."), "missing string for event kind \(kind)")
        }
    }
}

/// The plural families, enumerated.
///
/// `RecordPhrasing.plural` builds `base + "_one"` / `"_other"`. Neither whole
/// key is ever a literal, so the same sweep that silently deleted the filter
/// labels could take these. Every count that reaches a title is checked at
/// one and at more than one.
@Suite("Plural families resolve at both counts")
struct PluralKeyTests {
    private func record(_ stage: SafetyAuditEvent.Stage, _ n: Int) -> [SafetyLogRecord] {
        (0..<n).map { i in
            SafetyLogRecord(id: Int64(i), operationID: "A", stage: stage, redactedPath: "<home>/…/f",
                            ruleID: "r", risk: "low", size: 1,
                            date: Date(timeIntervalSince1970: 1_700_000_000), result: SafetyCenter.trashedResult)
        }
    }

    @Test(arguments: [1, 3])
    func titlesResolveAtEveryCount(_ n: Int) {
        for stage in [SafetyAuditEvent.Stage.executed, .skipped, .error, .approved] {
            let entry = SafetyLedger.entries(from: record(stage, n))[0]
            let title = RecordPhrasing.title(entry)
            #expect(!title.hasPrefix("record."), "missing plural string: \(title)")
            let subtitle = RecordPhrasing.subtitle(entry)
            #expect(!subtitle.contains("record."), "missing plural string: \(subtitle)")
        }
    }
}
