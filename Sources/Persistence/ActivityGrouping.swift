import Foundation

/// Pure, data-only helpers for presenting `ActivityRecord`s as a timeline.
/// No UI dependencies — safe to unit test directly.
public enum ActivityGrouping {

    /// Records grouped by calendar day, newest day first. Within a day, records
    /// keep the order they were given (callers pass newest-first from the store).
    public static func groupByDay(_ records: [ActivityRecord], calendar: Calendar = .current) -> [(day: Date, records: [ActivityRecord])] {
        var order: [Date] = []
        var buckets: [Date: [ActivityRecord]] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if buckets[day] == nil {
                buckets[day] = []
                order.append(day)
            }
            buckets[day]!.append(record)
        }
        return order.map { (day: $0, records: buckets[$0] ?? []) }
    }

    /// Total bytes freed by real (non-dry-run) operations vs. bytes that would
    /// have been freed by simulated (dry-run) operations. Kept separate so a
    /// dry run is never presented as an actual cleanup.
    public static func byteSummary(_ records: [ActivityRecord]) -> (real: Int64, simulated: Int64) {
        var real: Int64 = 0
        var simulated: Int64 = 0
        for record in records {
            if record.dryRun {
                simulated += record.bytes
            } else {
                real += record.bytes
            }
        }
        return (real, simulated)
    }

    /// Success/fail counts across a set of records. A record is a "failure" if
    /// its kind is `.error`; everything else counts as a success.
    public static func successFailCounts(_ records: [ActivityRecord]) -> (success: Int, fail: Int) {
        let fail = records.filter { $0.kind == .error }.count
        return (records.count - fail, fail)
    }

    /// Renders records as CSV text (header + one row per record), for export.
    public static func csv(_ records: [ActivityRecord]) -> String {
        var lines = ["date,kind,summary,itemCount,bytes,dryRun"]
        let formatter = ISO8601DateFormatter()
        for record in records {
            let summary = record.summary
                .replacingOccurrences(of: "\"", with: "\"\"")
            lines.append(
                "\(formatter.string(from: record.date)),\(record.kind.rawValue),\"\(summary)\","
                + "\(record.itemCount),\(record.bytes),\(record.dryRun)")
        }
        return lines.joined(separator: "\n")
    }
}
