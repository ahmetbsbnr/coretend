import SwiftUI
import AppShell
import Domain
import Persistence
import ProductContract
import DesignSystem

struct MenuBarMetricsView: View {
    let french: Bool
    @State private var snapshot: SystemSnapshot?
    @State private var latestActivity: ActivitySummary?
    @State private var activityUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy("menubar.metrics.title")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
            Text(copy("menubar.metrics.help"))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            if let snapshot {
                metric(copy("metrics.loadAverage"), load(snapshot.loadAverage1m), source: copy("metrics.source.load"))
                metric(copy("metrics.memory"), ProductFormat.memory(snapshot.physicalMemoryBytes, french: french), source: copy("metrics.source.memory"))
                metric(copy("metrics.freeSpace"), bytes(snapshot.availableBytes), source: copy("metrics.source.volume"))
                Text(copy("menubar.metrics.updated") + " " + timestamp(snapshot.measuredAt))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else {
                HStack(spacing: 8) {
                    Text(copy("metrics.refresh"))
                        .font(CoreTendTypography.secondary)
                        .foregroundStyle(Palette.secondaryInk.color)
                }
                .accessibilityElement(children: .combine)
            }
            Palette.separator.color.frame(height: 1)
            Text(copy("menubar.activity.title")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
            if activityUnavailable {
                Label(copy("menubar.activity.unavailable"), systemImage: "exclamationmark.circle")
                    .font(CoreTendTypography.secondary)
                    .foregroundStyle(Palette.secondaryInk.color)
            } else if let latestActivity {
                Text(copy("activity.\(latestActivity.kind.rawValue)"))
                    .font(CoreTendTypography.body)
                Text(timestamp(latestActivity.occurredAt))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            } else {
                Text(copy("menubar.activity.empty"))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
        }
        .accessibilityElement(children: .contain)
        .task {
            await refresh()
            await VisibleSamplingLoop.run(interval: .seconds(30)) {
                await refresh()
            }
        }
    }

    private func metric(_ title: String, _ value: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                Spacer(minLength: 8)
                Text(value).font(CoreTendTypography.figure).foregroundStyle(Palette.ink.color)
            }
            Text(source).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(source)")
    }

    @MainActor private func refresh() async {
        let service = SystemSnapshotService()
        snapshot = await Task.detached(priority: .utility) { service.snapshot() }.value
        do {
            let store = try await LocalStoreAccess.open()
            latestActivity = try await store.latestActivity()
            activityUnavailable = false
        } catch {
            latestActivity = nil
            activityUnavailable = true
        }
    }

    private func bytes(_ value: ProductMeasurement<Int64>) -> String {
        switch value {
        case .known(let amount): ProductFormat.bytes(amount, french: french)
        case .unknown: copy("metrics.unknown")
        }
    }

    private func load(_ value: ProductMeasurement<Double>) -> String {
        switch value {
        case .known(let amount): amount.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: french ? "fr_FR" : "en_US")))
        case .unknown: copy("metrics.unknown")
        }
    }

    private func timestamp(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }

    private func copy(_ key: String) -> String {
        ProductCopy.value(for: key, french: french)
    }
}
