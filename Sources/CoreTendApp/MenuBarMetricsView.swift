import SwiftUI
import AppShell
import Domain
import Persistence
import ProductContract

struct MenuBarMetricsView: View {
    let french: Bool
    @State private var snapshot: SystemSnapshot?
    @State private var latestActivity: ActivitySummary?
    @State private var activityUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy("menubar.metrics.title")).font(.headline)
            Text(copy("menubar.metrics.help"))
                .font(.caption).foregroundStyle(.secondary)
            if let snapshot {
                metric(copy("metrics.loadAverage"), load(snapshot.loadAverage1m), source: copy("metrics.source.load"))
                metric(copy("metrics.memory"), ByteCountFormatter.string(fromByteCount: snapshot.physicalMemoryBytes, countStyle: .memory), source: copy("metrics.source.memory"))
                metric(copy("metrics.freeSpace"), bytes(snapshot.availableBytes), source: copy("metrics.source.volume"))
                Text(copy("menubar.metrics.updated") + " " + timestamp(snapshot.measuredAt))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
            Divider()
            Text(copy("menubar.activity.title")).font(.headline)
            if activityUnavailable {
                Text(copy("menubar.activity.unavailable")).foregroundStyle(.secondary)
            } else if let latestActivity {
                Text(copy("activity.\(latestActivity.kind.rawValue)"))
                    .font(.callout)
                Text(timestamp(latestActivity.occurredAt))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(copy("menubar.activity.empty")).foregroundStyle(.secondary)
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
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value).font(.body.monospacedDigit())
            }
            Text(source).font(.caption2).foregroundStyle(.tertiary)
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
        case .known(let amount): ByteCountFormatter.string(fromByteCount: amount, countStyle: .file)
        case .unknown: copy("metrics.unknown")
        }
    }

    private func load(_ value: ProductMeasurement<Double>) -> String {
        switch value {
        case .known(let amount): amount.formatted(.number.precision(.fractionLength(2)))
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
