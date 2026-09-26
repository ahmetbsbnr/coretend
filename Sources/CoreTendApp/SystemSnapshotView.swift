import SwiftUI
import Domain
import ProductContract
import AppShell

struct SystemSnapshotView: View {
    let destination: Destination
    let french: Bool
    @State private var snapshot: SystemSnapshot?
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { refresh() } label: { Label(copy("metrics.refresh"), systemImage: "arrow.clockwise") }
                .disabled(loading)
            if loading { ProgressView() }
            if let snapshot {
                if destination == .overview { storage(snapshot) }
                else { performance(snapshot) }
                Text(copy("metrics.measured") + " " + snapshot.measuredAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US"))))
                    .font(.caption).foregroundStyle(.secondary)
            } else if !loading {
                ContentUnavailableView(copy("metrics.unavailable"), systemImage: "gauge.with.dots.needle.67percent")
            }
        }
        .task { refresh() }
    }

    @ViewBuilder private func storage(_ value: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy("metrics.freeSpace")).font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(value.availableBytes)).font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(copy("metrics.available")).foregroundStyle(.secondary)
            }
            Text(copy("metrics.trashNote")).font(.callout).foregroundStyle(.secondary)
            if case .known(let total) = value.totalBytes {
                Text(copy("metrics.volumeTotal") + " " + ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func performance(_ value: SystemSnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 16) {
            metric(copy("metrics.processors"), "\(value.activeProcessorCount)")
            metric(copy("metrics.memory"), ByteCountFormatter.string(fromByteCount: value.physicalMemoryBytes, countStyle: .memory))
            metric(copy("metrics.uptime"), uptime(value.uptimeSeconds))
            metric(copy("metrics.thermal"), thermal(value.thermalState))
            metric(copy("metrics.freeSpace"), format(value.availableBytes))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit()).accessibilityLabel("\(title): \(value)")
        }
    }

    private func format(_ value: ProductMeasurement<Int64>) -> String {
        switch value {
        case .known(let bytes): ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .unknown: copy("metrics.unknown")
        }
    }

    private func uptime(_ seconds: TimeInterval) -> String {
        let hours = max(0, Int(seconds / 3600))
        let days = hours / 24
        let remainder = hours % 24
        return french ? "\(days) j \(remainder) h" : "\(days)d \(remainder)h"
    }

    private func thermal(_ state: Domain.ThermalState) -> String {
        copy("thermal.\(state.rawValue)")
    }

    private func refresh() {
        loading = true
        Task {
            let service = SystemSnapshotService()
            let newSnapshot = await Task.detached(priority: .utility) { service.snapshot() }.value
            snapshot = newSnapshot
            loading = false
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
