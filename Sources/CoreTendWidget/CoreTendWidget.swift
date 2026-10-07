import AppShell
import DesignSystem
import SwiftUI
import WidgetKit

// The disk at a glance (plan: « Performances » leaves the sidebar for the menu bar and a widget).
// Reads the volume's free space itself and the last Clean survey from the app group; moves nothing.

struct DiskEntry: TimelineEntry {
    let date: Date
    let freeBytes: Int64
    let totalBytes: Int64
    let snapshot: SharedSnapshot?

    static func now() -> DiskEntry {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return DiskEntry(date: .now, freeBytes: values?.volumeAvailableCapacityForImportantUsage ?? 0,
                         totalBytes: Int64(values?.volumeTotalCapacity ?? 0), snapshot: SharedSnapshot.load())
    }

    static let placeholder = DiskEntry(date: .now, freeBytes: 182_000_000_000, totalBytes: 494_000_000_000,
                                       snapshot: SharedSnapshot(reclaimableBytes: 7_100_000_000, surveyedAt: .now))
}

struct DiskProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiskEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (DiskEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .now())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DiskEntry>) -> Void) {
        completion(Timeline(entries: [.now()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct DiskWidgetView: View {
    let entry: DiskEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    private var french: Bool { AppLanguage.usesFrench("system") }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(french ? "Libre" : "Free")
                .font(.caption).foregroundStyle(Palette.secondaryInk.color(for: scheme))
            Text(bytes(entry.freeBytes))
                .font(.system(size: family == .systemSmall ? 26 : 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.color(for: scheme))
                .minimumScaleFactor(0.6).lineLimit(1)
            usageBar
            Text(french ? "sur \(bytes(entry.totalBytes))" : "of \(bytes(entry.totalBytes))")
                .font(.caption2).foregroundStyle(Palette.secondaryInk.color(for: scheme))
            Spacer(minLength: 0)
            if family != .systemSmall || entry.snapshot != nil {
                reclaimable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Palette.surface.color(for: scheme) }
        .widgetURL(URL(string: "coretend://open/clean"))
    }

    private var usageBar: some View {
        GeometryReader { proxy in
            let used = entry.totalBytes > 0 ? Double(entry.totalBytes - entry.freeBytes) / Double(entry.totalBytes) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.deep.color(for: scheme))
                Capsule().fill(Palette.accent.color(for: scheme)).frame(width: max(6, proxy.size.width * used))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var reclaimable: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text(french ? "À libérer : \(bytes(snapshot.reclaimableBytes))" : "To clear: \(bytes(snapshot.reclaimableBytes))")
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent.color(for: scheme))
                Text(snapshot.surveyedAt, format: .relative(presentation: .named))
                    .font(.caption2).foregroundStyle(Palette.tertiaryInk.color(for: scheme))
            }
        } else {
            Text(french ? "Ouvrez Nettoyer pour voir ce qui peut partir." : "Open Clean to see what can go.")
                .font(.caption2).foregroundStyle(Palette.secondaryInk.color(for: scheme))
        }
    }

    private func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useTB, .useMB]
        return formatter.string(fromByteCount: value)
    }
}

struct DiskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.ahmetbsbnr.coretend.disk", provider: DiskProvider()) { entry in
            DiskWidgetView(entry: entry)
        }
        .configurationDisplayName("CoreTend")
        .description(AppLanguage.usesFrench("system") ? "L’espace libre du Mac et ce que CoreTend peut libérer." : "Your Mac’s free space and what CoreTend can clear.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CoreTendWidgets: WidgetBundle {
    var body: some Widget { DiskWidget() }
}
