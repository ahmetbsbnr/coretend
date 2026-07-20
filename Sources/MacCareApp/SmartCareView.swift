import SwiftUI
import ScanCore
import SafetyCore
import FileRules
import DesignSystem
import Persistence

/// Smart Care orchestrates the available care modules. Only Cleanup is
/// implemented today; unavailable modules are shown honestly as such.
@MainActor
@Observable
final class SmartCareViewModel {
    enum ModuleState: Equatable {
        case pending, scanning(found: Int, bytes: Int64), done(found: Int, bytes: Int64)
        case unavailable(String)
    }

    struct CareModule: Identifiable {
        let id: String
        let name: String
        let icon: String
        var enabled: Bool
        var state: ModuleState
    }

    enum Phase: Equatable { case idle, running, review, executing, finished(freed: Int64, dryRun: Bool) }

    var phase: Phase = .idle
    var modules: [CareModule] = SmartCareViewModel.initialModules()
    var findings: [ScanFinding] = []
    var dryRun = true

    private var scanTask: Task<Void, Never>?

    static func initialModules() -> [CareModule] {
        [
            CareModule(id: "cleanup", name: "Cleanup", icon: "sparkles", enabled: true, state: .pending),
            CareModule(id: "protection", name: "Protection", icon: "shield", enabled: false,
                       state: .unavailable("Malware scanning not yet available")),
            CareModule(id: "performance", name: "Performance", icon: "gauge.with.needle", enabled: false,
                       state: .unavailable("Maintenance tasks not yet available")),
            CareModule(id: "applications", name: "Applications", icon: "square.grid.2x2", enabled: false,
                       state: .unavailable("App analysis not yet available")),
        ]
    }

    var totalFoundBytes: Int64 { findings.reduce(0) { $0 + $1.logicalSize } }
    var preselectedBytes: Int64 { findings.filter(\.preselected).reduce(0) { $0 + $1.logicalSize } }

    func start() {
        guard phase != .running else { return }
        phase = .running
        findings = []
        modules = Self.initialModules()
        scanTask = Task {
            guard let index = modules.firstIndex(where: { $0.id == "cleanup" }), modules[index].enabled else {
                phase = .review
                return
            }
            modules[index].state = .scanning(found: 0, bytes: 0)
            var found = 0
            var bytes: Int64 = 0
            let excluded = (try? await AppEnvironment.shared.store?.exclusions()) ?? []
            let engine = ScanEngine(configuration: ScanConfiguration(excludedPaths: excluded))
            for await event in engine.run(rules: UserCleanupRules.all) {
                switch event {
                case let .finding(finding):
                    if findings.count < 5000 { findings.append(finding) }
                    found += 1
                    bytes += finding.logicalSize
                    if found % 64 == 0 {
                        modules[index].state = .scanning(found: found, bytes: bytes)
                    }
                case .finished:
                    modules[index].state = .done(found: found, bytes: bytes)
                case .cancelled:
                    modules[index].state = .done(found: found, bytes: bytes)
                default: break
                }
            }
            phase = .review
            AppEnvironment.shared.record(ActivityRecord(
                kind: .scan, summary: "Smart Care scan: \(found) items",
                itemCount: found, bytes: bytes, dryRun: true))
        }
    }

    func cancel() {
        scanTask?.cancel()
        phase = .idle
    }

    /// Executes only reversible, preselected findings (low risk).
    func runCare() {
        guard phase == .review else { return }
        phase = .executing
        let selected = findings.filter { $0.preselected && $0.risk == .low }
        let isDryRun = dryRun
        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let validator = PathValidator(allowedRoots: UserCleanupRules.allowedRoots(home: home))
            let center = SafetyCenter(validator: validator, dryRun: isDryRun)
            var approved: [ApprovedFileOperation] = []
            for finding in selected {
                if let op = try? await center.approve(
                    url: finding.url, logicalSize: finding.logicalSize,
                    ruleID: finding.ruleID, risk: finding.risk
                ) {
                    approved.append(op)
                }
            }
            let result = await center.execute(approved)
            let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
            phase = .finished(freed: freed, dryRun: result.wasDryRun)
            AppEnvironment.shared.record(ActivityRecord(
                kind: .cleanup,
                summary: result.wasDryRun
                    ? "Smart Care dry run: \(result.executed.count) items"
                    : "Smart Care: moved \(result.executed.count) items to Trash",
                itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
        }
    }
}

struct SmartCareView: View {
    @State private var model = SmartCareViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: MCSpacing.lg) {
                hero
                footer
                MCSectionHeader("Care categories")
                moduleList
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Smart Care")
    }

    private var heroState: MCHeroState {
        switch model.phase {
        case .idle: .idle
        case .running:
            .scanning(storage: scanFraction, protection: nil, performance: nil)
        case .review: .review
        case .executing: .running
        case .finished: .success
        }
    }

    /// Real progress proxy: cleanup module state (only implemented category).
    private var scanFraction: Double? {
        if case .scanning = model.modules.first?.state { return nil }
        return nil
    }

    private var hero: some View {
        VStack(spacing: MCSpacing.sm) {
            MCHeroCoreView(state: heroState)
            Text(heroTitle)
                .font(MCFont.heroTitle)
            Text(heroSubtitle)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MCSpacing.md)
    }

    private var heroTitle: String {
        switch model.phase {
        case .idle: "Ready to look after this Mac"
        case .running: "Scanning…"
        case .review: "\(mcFormatBytes(model.preselectedBytes)) safe to clean"
        case .executing: "Cleaning…"
        case let .finished(freed, dryRun):
            dryRun ? "Dry run: \(mcFormatBytes(freed)) would be freed"
                   : "\(mcFormatBytes(freed)) moved to Trash"
        }
    }

    private var heroSubtitle: String {
        switch model.phase {
        case .idle: "A scan looks at storage first. Nothing is deleted during a scan."
        case .running: "Reading caches, logs and build data. You can cancel at any time."
        case .review: "\(mcFormatBytes(model.totalFoundBytes)) found in total. Only low-risk, reversible items are preselected."
        case .executing: "Items go to the Trash — you can put them back."
        case .finished: "Details are in My Activity."
        }
    }

    private var moduleList: some View {
        VStack(spacing: 12) {
            ForEach(model.modules) { module in
                MCCard {
                    HStack {
                        Image(systemName: module.icon)
                            .font(.title2)
                            .foregroundStyle(module.enabled ? moduleColor(module.id) : .secondary)
                            .frame(width: 36)
                        VStack(alignment: .leading) {
                            Text(module.name).font(.headline)
                            stateText(module.state)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        stateAccessory(module.state)
                    }
                }
            }
        }
    }

    private func moduleColor(_ id: String) -> Color {
        switch id {
        case "cleanup": MCColor.storage
        case "protection": MCColor.protection
        case "performance": MCColor.performance
        default: MCColor.protection
        }
    }

    @ViewBuilder
    private func stateText(_ state: SmartCareViewModel.ModuleState) -> some View {
        switch state {
        case .pending: Text("Waiting to scan")
        case let .scanning(found, bytes): Text("Scanning… \(found) items, \(mcFormatBytes(bytes))")
        case let .done(found, bytes): Text("\(found) items — \(mcFormatBytes(bytes))")
        case let .unavailable(reason): Text(reason)
        }
    }

    @ViewBuilder
    private func stateAccessory(_ state: SmartCareViewModel.ModuleState) -> some View {
        switch state {
        case .scanning: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(MCTheme.success)
        case .unavailable: Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        case .pending: EmptyView()
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch model.phase {
        case .idle:
            Button("Start Smart Care Scan") { model.start() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .running:
            Button("Cancel") { model.cancel() }
        case .review:
            VStack(spacing: MCSpacing.xs) {
                HStack {
                    Toggle("Dry run", isOn: $model.dryRun).toggleStyle(.switch)
                    Button(model.dryRun ? "Simulate Care" : "Run Care") { model.runCare() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                Text("Review details in the Cleanup module.")
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }
        case .executing:
            ProgressView("Running…")
        case let .finished(freed, dryRun):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40)).foregroundStyle(MCTheme.success)
                Text(dryRun ? "Dry run: \(mcFormatBytes(freed)) would be freed"
                            : "\(mcFormatBytes(freed)) moved to Trash")
                    .font(.headline)
                Button("Scan Again") { model.start() }
            }
        }
    }
}
