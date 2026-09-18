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
