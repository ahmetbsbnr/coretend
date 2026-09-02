// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppDiscovery
import SafetyCore
import DesignSystem
import Persistence

@MainActor
@Observable
final class LeftoversViewModel {
    enum Phase: Equatable { case idle, scanning, results, empty, finished(freed: Int64) }

    var phase: Phase = .idle
    var leftovers: [AssociatedItem] = []
    var selectedPaths: Set<String> = []

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
        let discovery = ApplicationInventoryLocations.resolve(
            environment: ProcessInfo.processInfo.environment
        ).discovery
        let found = await Task.detached(priority: .utility) {
            let installed = Set(discovery.discoverApps().compactMap(\.bundleIdentifier))
            return discovery.leftovers(installedBundleIDs: installed)
        }.value
        leftovers = found
        // Nothing preselected: leftover matching is heuristic, the user reviews.
        phase = found.isEmpty ? .empty : .results
        AppEnvironment.shared.record(ActivityRecord(
            kind: .scan, summary: "Leftover scan: \(found.count) candidates",
            itemCount: found.count, bytes: totalBytes))
    }

    func removeSelected() async {
        let items = leftovers.filter { selectedPaths.contains($0.url.path) }
        guard !items.isEmpty else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library")]),
            sink: AppEnvironment.shared.store)
        var approved: [ApprovedFileOperation] = []
        for item in items {
            if let op = try? await center.approve(url: item.url, logicalSize: item.sizeBytes,
                                                  ruleID: "apps.leftovers", risk: .medium) {
                approved.append(op)
            }
        }
        let result = await center.execute(approved)
        let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
        phase = .finished(freed: freed)
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: "Removed \(result.executed.count) leftover items",
            itemCount: result.executed.count, bytes: freed))
    }
}

struct LeftoversView: View {
    @State private var model = LeftoversViewModel()
    @State private var showMoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .idle:
                MCEmptyState(
                    icon: "trash.slash", title: L("leftovers.idle.title"), message: L("leftovers.idle.subtitle"),
                    iconColor: MCTheme.accent, iconSize: MCIconSize.emptyStateProminent,
                    actionTitle: L("leftovers.scan")) { Task { await model.scan() } }
            case .scanning:
                ProgressView(L("leftovers.scanning")).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                MCEmptyState(
                    icon: "checkmark.circle", title: L("leftovers.none_found"), message: "",
                    iconColor: MCTheme.success,
                    actionTitle: L("smartcare.scan_again")) { Task { await model.scan() } }
            case .results:
                resultsView
            case let .finished(freed):
                MCSuccessState(
                    title: L("leftovers.finished.moved", mcFormatBytes(freed)),
                    actionTitle: L("smartcare.scan_again")) { Task { await model.scan() } }
            }
        }
        .confirmationDialog(
            L("common.trash_confirm.title"),
            isPresented: $showMoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.trash_confirm.action"), role: .destructive) {
                Task { await model.removeSelected() }
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("common.trash_confirm.message"))
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("leftovers.results.summary", model.leftovers.count, mcFormatBytes(model.selectedBytes), mcFormatBytes(model.totalBytes)))
                    .font(MCFont.cardTitle)
                Spacer()
                Button(L("cleanup.move_to_trash")) {
                    showMoveConfirmation = true
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
                    .accessibilityLabel("\(L("leftovers.select_item", item.url.lastPathComponent))\(model.isAmbiguous(item) ? ", \(L("leftovers.shared_ambiguous_a11y"))" : "")")
                    VStack(alignment: .leading) {
                        HStack(spacing: MCSpacing.xxs) {
                            Text(item.url.lastPathComponent)
                            if model.isAmbiguous(item) {
                                Text(L("leftovers.shared_review"))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, MCSpacing.xxs).padding(.vertical, 1)
                                    .background(MCColor.attention.opacity(0.18), in: Capsule())
                                    .foregroundStyle(MCColor.attention)
                            }
                        }
                        Text(L("leftovers.not_installed", item.kind.rawValue))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(mcFormatBytes(item.sizeBytes))
                        .monospacedDigit().foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(L("common.reveal_in_finder"))
                }
            }
            .listStyle(.inset)
        }
    }
}
