import Testing
import Foundation
@testable import Persistence

@Suite("ActivityGrouping")
struct ActivityGroupingTests {
    private func record(day: Int, kind: ActivityRecord.Kind = .scan, bytes: Int64 = 100, dryRun: Bool = true) -> ActivityRecord {
        let date = Calendar.current.date(byAdding: .day, value: -day, to: Date())!
        return ActivityRecord(kind: kind, date: date, summary: "r\(day)", itemCount: 1, bytes: bytes, dryRun: dryRun)
    }

    @Test func groupsByCalendarDay() {
        let records = [record(day: 0), record(day: 0), record(day: 1)]
        let groups = ActivityGrouping.groupByDay(records)
        #expect(groups.count == 2)
        #expect(groups[0].records.count == 2)
        #expect(groups[1].records.count == 1)
    }

    @Test func byteSummarySeparatesRealFromSimulated() {
        let records = [
            record(day: 0, bytes: 100, dryRun: true),
            record(day: 0, bytes: 50, dryRun: false),
            record(day: 0, bytes: 25, dryRun: false),
        ]
        let summary = ActivityGrouping.byteSummary(records)
        #expect(summary.real == 75)
        #expect(summary.simulated == 100)
    }

    @Test func successFailCountsUsesErrorKind() {
        let records = [
            record(day: 0, kind: .scan),
            record(day: 0, kind: .error),
            record(day: 0, kind: .cleanup),
        ]
        let counts = ActivityGrouping.successFailCounts(records)
        #expect(counts.success == 2)
        #expect(counts.fail == 1)
    }

    @Test func csvIncludesHeaderAndEscapesQuotes() {
        let records = [record(day: 0)]
        let csv = ActivityGrouping.csv(records)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "date,kind,summary,itemCount,bytes,dryRun")
    }

    @Test func emptyInputProducesEmptyOutputs() {
        #expect(ActivityGrouping.groupByDay([]).isEmpty)
        let summary = ActivityGrouping.byteSummary([])
        #expect(summary.real == 0 && summary.simulated == 0)
        let csv = ActivityGrouping.csv([])
        #expect(csv == "date,kind,summary,itemCount,bytes,dryRun")
    }
}
