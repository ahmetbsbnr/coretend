// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

//
// CoreTend WidgetKit extension — READ-ONLY.
//
// This target links only `WidgetShared` — a Foundation value + file-IO
// layer. It does NOT link `ScanCore`, `SafetyCore`, `FileRules`,
// `Persistence`, `AppDiscovery`, `IntegrityCore`, `SystemMetrics`, or
// `CoreTendApp`. It therefore has no symbol for `ScanEngine`,
// `SafetyCenter`, `RecoveryPlanService`, `RestoreService`,
// `DeveloperCenterService`, `DuplicateEngine`, or any filesystem-cleanup
// path — the "a widget can never scan or delete" guarantee is a dependency
// fact, not a runtime check. The widget reads one small snapshot the host
// published to the App Group and renders it.
//

import WidgetKit
import SwiftUI
import WidgetShared

// MARK: - Timeline

struct StatusEntry: TimelineEntry {
    let date: Date
    let model: WidgetDisplayModel
}

/// Lightweight: reads exactly one snapshot file, builds one entry, and asks
/// the system to refresh in an hour. A widget is a summary, not Activity
/// Monitor — it does not chase real-time disk-free bytes.
struct StatusProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), model: .from(.unavailable(reason: .fileMissing)))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
    }

    private func currentEntry() -> StatusEntry {
        StatusEntry(date: Date(), model: .from(store.read()))
    }
}

// MARK: - Views

struct CoreTendStatusView: View {
    @Environment(\.widgetFamily) private var family
    let model: WidgetDisplayModel

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            default: small
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.accessibilityLabel))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text(model.primary)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(model.headline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(model.primary)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(model.headline)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let detail = model.detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if let footnote = model.footnote {
                Text(footnote).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
                .imageScale(.small)
                .foregroundStyle(.tint)
            Text(verbatim: "CoreTend")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if model.isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Widget

struct CoreTendStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.status, provider: StatusProvider()) { entry in
            CoreTendStatusView(model: entry.model)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text(WL("widget.display_name")))
        .description(Text(WL("widget.description")))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CoreTendWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoreTendStatusWidget()
    }
}
