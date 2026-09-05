// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Localized string lookup for the widget, from this module's own small
/// `Localizable.strings` (EN + FR). Deliberately a separate, tiny table
/// rather than a copy of the 1000-key app catalog — the widget shows a
/// handful of phrases.
public func WL(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

public func widgetFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

/// Everything the widget UI needs, already resolved to strings — so the
/// SwiftUI views stay trivial and the mapping is unit-tested without
/// rendering. Trend is carried as words (`headline`), never as an arrow or
/// colour alone.
public struct WidgetDisplayModel: Equatable, Sendable {
    /// True when there is nothing meaningful to show yet (CoreTend never
    /// opened, no snapshot, App Group missing, decode failure). The view
    /// shows a "open CoreTend" prompt.
    public let isPlaceholder: Bool
    /// Large line — free space, or a short "unavailable" phrase.
    public let primary: String
    /// One-line status: the storage trend in words, or an empty/stale note.
    public let headline: String
    /// Optional supporting line for the medium widget (last scan, reclaimable).
    public let detail: String?
    /// Optional third line for the medium widget (last activity).
    public let footnote: String?
    /// True when the data shown is from a stale snapshot.
    public let isStale: Bool
    /// A single combined string for `accessibilityLabel`.
    public let accessibilityLabel: String

    public static func from(_ result: WidgetSnapshotStore.ReadResult, now: Date = Date()) -> WidgetDisplayModel {
        switch result {
        case let .unavailable(reason):
            return unavailable(reason)
        case let .snapshot(snapshot):
            return present(snapshot, now: now)
        }
    }

    private static func unavailable(_ reason: WidgetSnapshotStore.ReadResult.Reason) -> WidgetDisplayModel {
        let headline: String
        switch reason {
        case .fileMissing:
            headline = WL("widget.empty.never_opened")
        case .appGroupUnavailable:
            headline = WL("widget.empty.unavailable")
        case .unreadable, .malformed, .unsupportedFutureVersion:
            headline = WL("widget.empty.unavailable")
        }
        return WidgetDisplayModel(
            isPlaceholder: true,
            primary: WL("widget.empty.primary"),
            headline: headline,
            detail: nil, footnote: nil, isStale: false,
            accessibilityLabel: "\(WL("widget.empty.primary")). \(headline)")
    }

    private static func present(_ s: WidgetSnapshot, now: Date) -> WidgetDisplayModel {
        let stale = s.isStale(now: now)
        let free = widgetFormatBytes(s.freeBytes)
        let primary = WL("widget.free_of_total", free, widgetFormatBytes(s.totalBytes))

        let headline: String
        if let delta = s.sinceLastScanDeltaBytes {
            if delta == 0 {
                headline = WL("widget.trend.no_change")
            } else if delta > 0 {
                headline = WL("widget.trend.increased", widgetFormatBytes(delta))
            } else {
                headline = WL("widget.trend.decreased", widgetFormatBytes(-delta))
            }
        } else {
            headline = WL("widget.trend.no_history")
        }

        var detailParts: [String] = []
        if let reclaimable = s.reclaimableBytes, reclaimable > 0 {
            detailParts.append(WL("widget.reclaimable", widgetFormatBytes(reclaimable)))
        }
        if let scanDate = s.lastScanDate {
            detailParts.append(WL("widget.last_scan", Self.relativeDate(scanDate, now: now)))
        }
        let detail = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")

        var footnote: String?
        if let kind = s.lastActivityKind, let localizedKind = Self.activityKindLabel(kind) {
            footnote = WL("widget.last_activity", localizedKind)
        }
        if stale {
            let asOf = WL("widget.as_of", Self.relativeDate(s.generatedAt, now: now))
            footnote = footnote.map { "\($0) · \(asOf)" } ?? asOf
        }

        let a11y = [primary, headline, detail, footnote].compactMap { $0 }.joined(separator: ". ")
        return WidgetDisplayModel(
            isPlaceholder: false, primary: primary, headline: headline,
            detail: detail, footnote: footnote, isStale: stale, accessibilityLabel: a11y)
    }

    private static func relativeDate(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func activityKindLabel(_ raw: String) -> String? {
        switch raw {
        case "scan": return WL("widget.activity.scan")
        case "cleanup": return WL("widget.activity.cleanup")
        case "restore": return WL("widget.activity.restore")
        case "error": return WL("widget.activity.error")
        default: return nil
        }
    }
}
