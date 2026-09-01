import SwiftUI
import AppKit
import SafetyCore
import DesignSystem
import Persistence
import ScanCore

/// Privacy Cleaner — browser data analysis and cache-only cleaning.
/// History/cookies/sessions removal is intentionally not implemented yet:
/// modifying live browser SQLite databases risks corruption and forced logouts.
/// Caches are plain files, rebuilt automatically, and go to the Trash.
@MainActor
@Observable
final class PrivacyCleanerViewModel {
    enum Phase: Equatable { case scanning, results, empty, finished(freed: Int64) }

    var phase: Phase = .scanning
    var profiles: [BrowserProfile] = []
    var selectedProfileIDs: Set<String> = []
    private var scanTask: Task<[BrowserProfile], Never>?
    private var pauseController: ScanPauseController?
    private(set) var isPaused = false

    func runningBrowsers() -> [String] {
        let ids = Set(profiles.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { app in app.bundleIdentifier.map { ids.contains($0) } ?? false }
            .compactMap(\.localizedName)
    }

    /// Per-profile check — a global "some browser is running" banner isn't
    /// enough: Chrome running must not block cleaning a Firefox profile.
    func isRunning(_ profile: BrowserProfile) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == profile.bundleID }
    }

    /// Quits the browser owning this profile (regular terminate, not
    /// force-kill — gives it a chance to save state/tabs) and rescans once
    /// it's confirmed gone, so the cache profile becomes cleanable.
    func closeBrowserAndRescan(_ profile: BrowserProfile) async {
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == profile.bundleID }
        guard !running.isEmpty else { await scan(); return }
        for app in running { app.terminate() }
        for _ in 0..<50 {  // up to ~5s
            if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == profile.bundleID }) {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        await scan()
    }

    func scan() async {
        cancelScan(resetPhase: false)
        phase = .scanning
        isPaused = false
        let home = FileManager.default.homeDirectoryForCurrentUser
        let pauseController = ScanPauseController()
        self.pauseController = pauseController
        let scanTask = Task.detached(priority: .utility) {
            await BrowserCatalog.detect(home: home, pauseController: pauseController)
        }
        self.scanTask = scanTask
        let found = await scanTask.value
        guard !Task.isCancelled else { return }
        profiles = found
        selectedProfileIDs = []
        self.scanTask = nil
        self.pauseController = nil
        isPaused = false
        phase = found.isEmpty ? .empty : .results
    }

    func pauseScan() {
        guard phase == .scanning, !isPaused else { return }
        isPaused = true
        Task { await pauseController?.pause() }
    }

    func resumeScan() {
        guard isPaused else { return }
        isPaused = false
        Task { await pauseController?.resume() }
    }

    func cancelScan(resetPhase: Bool = true) {
        scanTask?.cancel()
        scanTask = nil
        isPaused = false
        let pauseController = pauseController
        self.pauseController = nil
        Task { await pauseController?.resume() }
        if resetPhase, phase == .scanning {
            phase = profiles.isEmpty ? .empty : .results
        }
    }

    var selectedCacheBytes: Int64 {
        profiles.filter { selectedProfileIDs.contains($0.id) }.reduce(0) { $0 + $1.cacheBytes }
    }

    /// Moves selected profiles' cache directories to the Trash. Re-checks
    /// each profile's browser is still closed right before acting — the
    /// UI already disables selection for a running browser, but state can
    /// go stale between scan and the click (browser relaunched meanwhile).
    func cleanCaches() async {
        let selected = profiles.filter { selectedProfileIDs.contains($0.id) && !isRunning($0) }
        guard !selected.isEmpty else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library/Caches")]),
            sink: AppEnvironment.shared.store)
        var approved: [ApprovedFileOperation] = []
        for profile in selected {
            for url in profile.cacheURLs {
                if let op = try? await center.approve(url: url, logicalSize: profile.cacheBytes,
                                                      ruleID: "privacy.browsercache", risk: .low) {
                    approved.append(op)
                }
            }
        }
        let result = await center.execute(approved)
        let freed = result.executed.reduce(0) { $0 + $1.logicalSize }
        phase = .finished(freed: freed)
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: "Browser caches moved to Trash",
            itemCount: result.executed.count, bytes: freed))
    }
}

struct PrivacyCleanerView: View {
    @State private var model = PrivacyCleanerViewModel()
    @State private var showMoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .scanning:
                VStack(spacing: MCSpacing.lg) {
                    MCScanStage(isScanning: !model.isPaused) {
                        Text(L("privacy.detecting"))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L("privacy.detecting"))
                    if model.isPaused {
                        Button(L("common.resume")) { model.resumeScan() }
                            .keyboardShortcut("r", modifiers: [])
                            .help(L("clutter.resume_hint"))
                            .accessibilityHint(L("clutter.resume_hint"))
                            .accessibilityIdentifier("privacy.scan.resume")
                    } else {
                        Button(L("common.pause")) { model.pauseScan() }
                            .keyboardShortcut("p", modifiers: [])
                            .help(L("clutter.pause_hint"))
                            .accessibilityHint(L("clutter.pause_hint"))
                            .accessibilityIdentifier("privacy.scan.pause")
                    }
                    Button(L("common.cancel")) { model.cancelScan() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("privacy.scan.cancel")
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                MCEmptyState(icon: "hand.raised", title: L("privacy.empty.title"), message: L("privacy.empty.subtitle"),
                             iconSize: MCIconSize.emptyState)
            case .results:
                resultsView
            case let .finished(freed):
                VStack(spacing: MCSpacing.sm) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.success)
                        .accessibilityHidden(true)
                    Text(L("privacy.finished.moved", mcFormatBytes(freed)))
                        .font(.title3.weight(.semibold))
                    Button(L("smartcare.scan_again")) { Task { await model.scan() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("privacy.root")
        .task { await model.scan() }
        .confirmationDialog(
            L("common.trash_confirm.title"),
            isPresented: $showMoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.trash_confirm.action"), role: .destructive) {
                Task { await model.cleanCaches() }
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("common.trash_confirm.message"))
        }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            let running = model.runningBrowsers()
            if !running.isEmpty {
                Label(L("privacy.running_warning", running.joined(separator: ", ")),
                      systemImage: "exclamationmark.triangle")
                    .font(MCFont.secondaryBody).foregroundStyle(MCTheme.warning)
                    .padding(.horizontal).padding(.top, MCSpacing.sm)
                    .accessibilityElement(children: .combine)
            }
            HStack {
                Text(L("privacy.caches_selected", mcFormatBytes(model.selectedCacheBytes)))
                    .font(MCFont.cardTitle)
                Spacer()
                Button(L("privacy.clean_caches")) {
                    showMoveConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("privacy.clean")
                .disabled(model.selectedProfileIDs.isEmpty)
            }
            .padding()
            List(model.profiles) { profile in
                let profileIsRunning = model.isRunning(profile)
                VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { model.selectedProfileIDs.contains(profile.id) },
                            set: { on in
                                if on { model.selectedProfileIDs.insert(profile.id) }
                                else { model.selectedProfileIDs.remove(profile.id) }
                            }
                        ))
                        .labelsHidden()
                        .accessibilityLabel(L("privacy.browser_profile", profile.browser, profile.profileName))
                        .disabled(profile.cacheURLs.isEmpty || profileIsRunning)
                        VStack(alignment: .leading) {
                            Text(L("privacy.browser_profile", profile.browser, profile.profileName))
                            HStack(spacing: MCSpacing.sm) {
                                Text(L("privacy.cache_size", mcFormatBytes(profile.cacheBytes)))
                                Text(L("privacy.history_size", mcFormatBytes(profile.historyBytes)))
                                Text(L("privacy.cookies_size", mcFormatBytes(profile.cookieBytes)))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if profileIsRunning {
                        HStack(spacing: MCSpacing.xs) {
                            Image(systemName: "lock.circle").foregroundStyle(MCTheme.warning)
                                .accessibilityHidden(true)
                            Text(L("privacy.profile_running_reason", profile.browser))
                                .font(.caption).foregroundStyle(MCTheme.warning)
                            Spacer()
                            Button(L("privacy.close_and_rescan")) {
                                Task { await model.closeBrowserAndRescan(profile) }
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                        .padding(.leading, 28)
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityElement(children: .contain)
            }
            .listStyle(.inset)
            Text(L("privacy.footer"))
                .font(.caption).foregroundStyle(.secondary)
                .padding()
        }
    }
}
