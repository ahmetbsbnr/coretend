import SwiftUI
import AppKit
import SafetyCore
import DesignSystem
import Persistence

/// Privacy Cleaner — browser data analysis and cache-only cleaning.
/// History/cookies/sessions removal is intentionally not implemented yet:
/// modifying live browser SQLite databases risks corruption and forced logouts.
/// Caches are plain files, rebuilt automatically, and go to the Trash.
@MainActor
@Observable
final class PrivacyCleanerViewModel {
    enum Phase: Equatable { case scanning, results, empty, finished(freed: Int64, dryRun: Bool) }

    var phase: Phase = .scanning
    var profiles: [BrowserProfile] = []
    var selectedProfileIDs: Set<String> = []
    var dryRun = true

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
        phase = .scanning
        let home = FileManager.default.homeDirectoryForCurrentUser
        let found = await Task.detached(priority: .utility) {
            BrowserCatalog.detect(home: home)
        }.value
        profiles = found
        selectedProfileIDs = []
        phase = found.isEmpty ? .empty : .results
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
            dryRun: dryRun, sink: AppEnvironment.shared.store)
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
        phase = .finished(freed: freed, dryRun: result.wasDryRun)
        AppEnvironment.shared.record(ActivityRecord(
            kind: .cleanup,
            summary: result.wasDryRun ? "Browser cache dry run" : "Browser caches moved to Trash",
            itemCount: result.executed.count, bytes: freed, dryRun: result.wasDryRun))
    }
}

struct PrivacyCleanerView: View {
    @State private var model = PrivacyCleanerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .scanning:
                ProgressView(L("privacy.detecting"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                MCEmptyState(icon: "hand.raised", title: L("privacy.empty.title"), message: L("privacy.empty.subtitle"),
                             iconSize: MCIconSize.emptyState)
            case .results:
                resultsView
            case let .finished(freed, dryRun):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: MCIconSize.emptyState)).foregroundStyle(MCTheme.success)
                        .accessibilityHidden(true)
                    Text(dryRun ? L("privacy.finished.dryrun", mcFormatBytes(freed))
                                : L("privacy.finished.moved", mcFormatBytes(freed)))
                        .font(.title3.weight(.semibold))
                    Button(L("smartcare.scan_again")) { Task { await model.scan() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await model.scan() }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            let running = model.runningBrowsers()
            if !running.isEmpty {
                Label(L("privacy.running_warning", running.joined(separator: ", ")),
                      systemImage: "exclamationmark.triangle")
                    .font(MCFont.secondaryBody).foregroundStyle(MCTheme.warning)
                    .padding(.horizontal).padding(.top, 12)
                    .accessibilityElement(children: .combine)
            }
            HStack {
                Text(L("privacy.caches_selected", mcFormatBytes(model.selectedCacheBytes)))
                    .font(MCFont.cardTitle)
                Spacer()
                Toggle(L("common.dry_run"), isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? L("privacy.simulate_clean") : L("privacy.clean_caches")) {
                    Task { await model.cleanCaches() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedProfileIDs.isEmpty)
            }
            .padding()
            List(model.profiles) { profile in
                let profileIsRunning = model.isRunning(profile)
                VStack(alignment: .leading, spacing: 4) {
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
                            HStack(spacing: 12) {
                                Text(L("privacy.cache_size", mcFormatBytes(profile.cacheBytes)))
                                Text(L("privacy.history_size", mcFormatBytes(profile.historyBytes)))
                                Text(L("privacy.cookies_size", mcFormatBytes(profile.cookieBytes)))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if profileIsRunning {
                        HStack(spacing: 8) {
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
