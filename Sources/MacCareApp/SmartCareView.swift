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

    /// Real aggregates from the full stream — never derived from `findings`,
    /// which is capped for UI display. Keeps Smart Care and Cleanup in agreement.
    var totalFindingCount = 0
    var totalFoundBytes: Int64 = 0
    var isDisplayTruncated: Bool { totalFindingCount > findings.count }

    private var scanTask: Task<Void, Never>?

    static func initialModules() -> [CareModule] {
        [
            CareModule(id: "cleanup", name: "Cleanup", icon: "sparkles", enabled: true, state: .pending),
            CareModule(id: "protection", name: "Protection", icon: "shield", enabled: false,
                       state: .unavailable(L("smartcare.protection_unavailable"))),
            CareModule(id: "performance", name: "Performance", icon: "gauge.with.needle", enabled: false,
                       state: .unavailable(L("smartcare.performance_unavailable"))),
            CareModule(id: "applications", name: "Applications", icon: "square.grid.2x2", enabled: false,
                       state: .unavailable(L("smartcare.applications_unavailable"))),
        ]
    }

    var preselectedBytes: Int64 { findings.filter(\.preselected).reduce(0) { $0 + $1.logicalSize } }

    func start() {
        guard phase != .running else { return }
        phase = .running
        findings = []
        totalFindingCount = 0
        totalFoundBytes = 0
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
                    // ponytail: findings capped at 5000 for UI display only;
                    // found/bytes below are the real, uncapped totals.
                    if findings.count < 5000 { findings.append(finding) }
                    found += 1
                    bytes += finding.logicalSize
                    totalFindingCount = found
                    totalFoundBytes = bytes
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
            let center = SafetyCenter(validator: validator, dryRun: isDryRun, sink: AppEnvironment.shared.store)
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
                MCSectionHeader(L("smartcare.care_categories"))
                moduleList
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(L("smartcare.nav_title"))
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
            // Decorative — the state it represents is already spelled out
            // in heroTitle/heroSubtitle right below, which VoiceOver reads.
            MCHeroCoreView(state: heroState)
                .accessibilityHidden(true)
            Text(heroTitle)
                .font(MCFont.heroTitle)
            Text(heroSubtitle)
                .font(MCFont.secondaryBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MCSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private var heroTitle: String {
        switch model.phase {
        case .idle: L("smartcare.hero.idle_title")
        case .running: L("smartcare.hero.scanning_title")
        case .review: L("smartcare.hero.review_title", mcFormatBytes(model.preselectedBytes))
        case .executing: L("smartcare.hero.cleaning_title")
        case let .finished(freed, dryRun):
            dryRun ? L("smartcare.hero.finished_dryrun_title", mcFormatBytes(freed))
                   : L("smartcare.hero.finished_title", mcFormatBytes(freed))
        }
    }

    private var heroSubtitle: String {
        switch model.phase {
        case .idle: L("smartcare.hero.idle_subtitle")
        case .running: L("smartcare.hero.scanning_subtitle")
        case .review: model.isDisplayTruncated
            ? L("smartcare.hero.review_subtitle_truncated", mcFormatBytes(model.totalFoundBytes), model.findings.count, model.totalFindingCount)
            : L("smartcare.hero.review_subtitle", mcFormatBytes(model.totalFoundBytes))
        case .executing: L("smartcare.hero.executing_subtitle")
        case .finished: L("smartcare.hero.finished_subtitle")
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
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(module.name).font(.headline)
                            stateText(module.state)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        stateAccessory(module.state)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
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
        case .pending: Text(L("smartcare.module.waiting"))
        case let .scanning(found, bytes): Text(L("smartcare.module.scanning", found, mcFormatBytes(bytes)))
        case let .done(found, bytes): Text(L("smartcare.module.done", found, mcFormatBytes(bytes)))
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
            Button(L("smartcare.start_scan")) { model.start() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .running:
            Button(L("common.cancel")) { model.cancel() }
        case .review:
            VStack(spacing: MCSpacing.xs) {
                HStack {
                    Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                    Button(model.dryRun ? L("smartcare.simulate_care") : L("smartcare.run_care")) { model.runCare() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                Text(L("smartcare.review_details_hint"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }
        case .executing:
            ProgressView(L("common.running"))
        case let .finished(freed, dryRun):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40)).foregroundStyle(MCTheme.success)
                Text(dryRun ? L("smartcare.hero.finished_dryrun_title", mcFormatBytes(freed))
                            : L("smartcare.hero.finished_title", mcFormatBytes(freed)))
                    .font(.headline)
                Button(L("smartcare.scan_again")) { model.start() }
            }
        }
    }
}
