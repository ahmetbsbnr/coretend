import Foundation
import Persistence

public enum ActivityDateRange: String, CaseIterable, Hashable, Sendable {
    case all
    case last7Days
    case last30Days

    public func startDate(now: Date, calendar: Calendar = .current) -> Date? {
        let days: Int
        switch self {
        case .all: return nil
        case .last7Days: days = 6
        case .last30Days: days = 29
        }
        return calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))
    }
}

public struct ActivityDayGroup: Equatable, Sendable {
    public let day: Date
    public let events: [ActivityEvent]

    public init(day: Date, events: [ActivityEvent]) {
        self.day = day
        self.events = events
    }
}

public enum ActivityHistoryGrouping {
    public static func filteredEvents(
        _ events: [ActivityEvent],
        kind: ActivityKind? = nil,
        range: ActivityDateRange = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ActivityEvent] {
        let startDate = range.startDate(now: now, calendar: calendar)
        return events
            .filter { event in
                let matchesKind = kind == nil || event.kind == kind
                let matchesRange = startDate.map { event.occurredAt >= $0 && event.occurredAt <= now } ?? true
                return matchesKind && matchesRange
            }
            .sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    public static func groups(
        _ events: [ActivityEvent],
        kind: ActivityKind? = nil,
        range: ActivityDateRange = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ActivityDayGroup] {
        let filtered = filteredEvents(events, kind: kind, range: range, now: now, calendar: calendar)
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.occurredAt) }
            .map { ActivityDayGroup(day: $0.key, events: $0.value) }
            .sorted { $0.day > $1.day }
    }
}
