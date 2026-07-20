import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence

@MainActor
@Observable
final class LeftoversViewModel {
    enum Phase: Equatable { case idle, scanning, results, empty, finished(freed: Int64, dryRun: Bool) }

    var phase: Phase = .idle
    var leftovers: [AssociatedItem] = []
    var selectedPaths: Set<String> = []
    var dryRun = true

    var totalBytes: Int64 { leftovers.reduce(0) { $0 + $1.sizeBytes } }
    var selectedBytes: Int64 {
        leftovers.filter { selectedPaths.contains($0.url.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Ambiguous/shared items: an explicit `group.` container id (Apple's own
    /// convention for data shared across an app family), or a bundle-id
    /// vendor prefix that appears on more than one leftover — either signal
    /// means deleting it could affect more than the one app it looks tied to.
    /// Derived from the real scanned leftovers, never a guess.
    func isAmbiguous(_ item: AssociatedItem) -> Bool {
        let name = item.url.deletingPathExtension().lastPathComponent
        if name.hasPrefix("group.") { return true }
        let vendorPrefix = name.split(separator: ".").prefix(2).joined(separator: ".")
        guard !vendorPrefix.isEmpty else { return false }
        let sharedCount = leftovers.filter {
            $0.url.deletingPathExtension().lastPathComponent.split(separator: ".").prefix(2).joined(separator: ".") == vendorPrefix
        }.count
        return sharedCount > 1
    }

    func scan() async {
        phase = .scanning
        leftovers = []
        selectedPaths = []
        let discovery = AppDiscovery()
        let found = await Task.detached(priority: .utility) {
            let installed = Set(discovery.discoverApps().compactMap(\.bundleIdentifier))
            return discovery.leftovers(installedBundleIDs: installed)
        }.value
        leftovers = found
        // Nothing preselected: leftover matching is heuristic, the user reviews.
        phase = found.isEmpty ? .empty : .results
        AppEnvironment.shared.record(ActivityRecord(
            kind: .scan, summary: "Leftover scan: \(found.count) candidates",
            itemCount: found.count, bytes: totalBytes, dryRun: true))
    }

    func removeSelected() async {
        let items = leftovers.filter { selectedPaths.contains($0.url.path) }
        guard !items.isEmpty else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library")]),
            dryRun: dryRun)
        var approved: [ApprovedFileOperation] = []
        for item in items {
            if let op = try? await center.approve(url: item.url, logicalSize: item.sizeBytes,
                                                  ruleID: "apps.leftovers", risk: .medium) {
                approved.append(op)
            }
        }
        let result = await center.execute(approved)
        let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
        phase = .finished(freed: freed, dryRun: result.wasDryRun)
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: result.wasDryRun
                ? "Leftovers dry run: \(result.executed.count) items"
                : "Removed \(result.executed.count) leftover items",
            itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
    }
}

struct LeftoversView: View {
    @State private var model = LeftoversViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle:
                VStack(spacing: 16) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 56)).foregroundStyle(MCTheme.accent)
                    Text("Find leftovers from removed apps").font(.title2.weight(.semibold))
                    Text("Looks for support data whose application is no longer installed.\nMatching is conservative; nothing is preselected.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Scan for Leftovers") { Task { await model.scan() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .scanning:
                ProgressView("Scanning…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.success)
                    Text("No leftovers found").font(.title3.weight(.semibold))
                    Button("Scan Again") { Task { await model.scan() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                resultsView
            case let .finished(freed, dryRun):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.success)
                    Text(dryRun ? "Dry run: \(mcFormatBytes(freed)) would be reclaimed"
                                : "\(mcFormatBytes(freed)) moved to Trash")
                        .font(.title3.weight(.semibold))
                    Button("Scan Again") { Task { await model.scan() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(model.leftovers.count) candidates — \(mcFormatBytes(model.selectedBytes)) selected of \(mcFormatBytes(model.totalBytes))")
                    .font(.headline)
                Spacer()
                Toggle("Dry run", isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? "Simulate Removal" : "Move to Trash") {
                    Task { await model.removeSelected() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedPaths.isEmpty)
            }
            .padding()
            List(model.leftovers) { item in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { model.selectedPaths.contains(item.url.path) },
                        set: { on in
                            if on { model.selectedPaths.insert(item.url.path) }
                            else { model.selectedPaths.remove(item.url.path) }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel("Select \(item.url.lastPathComponent)\(model.isAmbiguous(item) ? ", shared or ambiguous" : "")")
                    VStack(alignment: .leading) {
                        HStack(spacing: MCSpacing.xxs) {
                            Text(item.url.lastPathComponent)
                            if model.isAmbiguous(item) {
                                Text("Shared / review")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, MCSpacing.xxs).padding(.vertical, 1)
                                    .background(MCColor.attention.opacity(0.18), in: Capsule())
                                    .foregroundStyle(MCColor.attention)
                            }
                        }
                        Text("\(item.kind.rawValue) — app with this identifier is not installed")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(mcFormatBytes(item.sizeBytes))
                        .monospacedDigit().foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                }
            }
            .listStyle(.inset)
        }
    }
}
