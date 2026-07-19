import SwiftUI
import Persistence
import DesignSystem

@MainActor
@Observable
final class MyActivityViewModel {
    enum Phase: Equatable { case loading, loaded, empty, failed(String) }

    var phase: Phase = .loading
    var records: [ActivityRecord] = []
    var filter: ActivityRecord.Kind?

    func load() async {
        guard let store = AppEnvironment.shared.store else {
            phase = .failed("Local database unavailable")
            return
        }
        do {
            records = try await store.activity(limit: 500, kind: filter)
            phase = records.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed("\(error)")
        }
    }

    func clear() async {
        guard let store = AppEnvironment.shared.store else { return }
        try? await store.clearActivity()
        await load()
    }
}

struct MyActivityView: View {
    @State private var model = MyActivityViewModel()

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.accent)
                    Text("No activity yet").font(.title3.weight(.semibold))
                    Text("Scans and cleanups will appear here. Everything stays on this Mac.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                List(model.records) { record in
                    HStack {
                        Image(systemName: icon(for: record.kind))
                            .foregroundStyle(color(for: record.kind))
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(record.summary)
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if record.dryRun {
                            Text("Dry run")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                        Text(mcFormatBytes(record.bytes))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            case let .failed(message):
                Text(message).foregroundStyle(MCTheme.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("My Activity")
        .toolbar {
            Picker("Filter", selection: $model.filter) {
                Text("All").tag(ActivityRecord.Kind?.none)
                ForEach(ActivityRecord.Kind.allCases, id: \.self) { kind in
                    Text(kind.rawValue.capitalized).tag(Optional(kind))
                }
            }
            .pickerStyle(.menu)
            Button("Clear History", role: .destructive) {
                Task { await model.clear() }
            }
            .disabled(model.records.isEmpty)
        }
        .task(id: model.filter) { await model.load() }
    }

    private func icon(for kind: ActivityRecord.Kind) -> String {
        switch kind {
        case .scan: "magnifyingglass"
        case .cleanup: "sparkles"
        case .restore: "arrow.uturn.backward"
        case .error: "exclamationmark.triangle"
        }
    }

    private func color(for kind: ActivityRecord.Kind) -> Color {
        switch kind {
        case .scan: MCTheme.accentSecondary
        case .cleanup: MCTheme.accent
        case .restore: MCTheme.warning
        case .error: MCTheme.danger
        }
    }
}
