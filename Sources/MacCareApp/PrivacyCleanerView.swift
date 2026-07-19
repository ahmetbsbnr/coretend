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
    struct BrowserProfile: Identifiable {
        let id: String
        let browser: String
        let bundleID: String
        let profileName: String
        let cacheURLs: [URL]
        let cacheBytes: Int64
        let historyBytes: Int64
        let cookieBytes: Int64
    }

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

    func scan() async {
        phase = .scanning
        let home = FileManager.default.homeDirectoryForCurrentUser
        let found = await Task.detached(priority: .utility) { () -> [BrowserProfile] in
            var profiles: [BrowserProfile] = []
            let fm = FileManager.default

            func size(_ url: URL) -> Int64 {
                guard fm.fileExists(atPath: url.path) else { return 0 }
                if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                   values.isDirectory != true { return Int64(values.fileSize ?? 0) }
                guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
                var total: Int64 = 0
                for case let item as URL in enumerator {
                    total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                }
                return total
            }

            // Chrome (and Chromium-based profiles under the same layout).
            let chromeSupport = home.appendingPathComponent("Library/Application Support/Google/Chrome")
            let chromeCaches = home.appendingPathComponent("Library/Caches/Google/Chrome")
            if fm.fileExists(atPath: chromeSupport.path) {
                let entries = (try? fm.contentsOfDirectory(at: chromeSupport, includingPropertiesForKeys: nil)) ?? []
                for entry in entries where entry.lastPathComponent == "Default" || entry.lastPathComponent.hasPrefix("Profile ") {
                    let name = entry.lastPathComponent
                    let cacheDir = chromeCaches.appendingPathComponent(name)
                    profiles.append(BrowserProfile(
                        id: "chrome-\(name)", browser: "Google Chrome", bundleID: "com.google.Chrome",
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: size(cacheDir),
                        historyBytes: size(entry.appendingPathComponent("History")),
                        cookieBytes: size(entry.appendingPathComponent("Cookies"))))
                }
            }

            // Firefox.
            let firefoxProfiles = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
            let firefoxCaches = home.appendingPathComponent("Library/Caches/Firefox/Profiles")
            if fm.fileExists(atPath: firefoxProfiles.path) {
                let entries = (try? fm.contentsOfDirectory(at: firefoxProfiles, includingPropertiesForKeys: nil)) ?? []
                for entry in entries {
                    let name = entry.lastPathComponent
                    let cacheDir = firefoxCaches.appendingPathComponent(name)
                    profiles.append(BrowserProfile(
                        id: "firefox-\(name)", browser: "Firefox", bundleID: "org.mozilla.firefox",
                        profileName: name,
                        cacheURLs: [cacheDir].filter { fm.fileExists(atPath: $0.path) },
                        cacheBytes: size(cacheDir),
                        historyBytes: size(entry.appendingPathComponent("places.sqlite")),
                        cookieBytes: size(entry.appendingPathComponent("cookies.sqlite"))))
                }
            }

            // Safari: cache lives behind TCC (Full Disk Access) in ~/Library/Caches/com.apple.Safari.
            let safariCache = home.appendingPathComponent("Library/Caches/com.apple.Safari")
            if fm.fileExists(atPath: safariCache.path) {
                profiles.append(BrowserProfile(
                    id: "safari", browser: "Safari", bundleID: "com.apple.Safari",
                    profileName: "Default",
                    cacheURLs: [safariCache],
                    cacheBytes: size(safariCache),
                    historyBytes: size(home.appendingPathComponent("Library/Safari/History.db")),
                    cookieBytes: 0))
            }
            return profiles.sorted { $0.cacheBytes > $1.cacheBytes }
        }.value
        profiles = found
        selectedProfileIDs = []
        phase = found.isEmpty ? .empty : .results
    }

    var selectedCacheBytes: Int64 {
        profiles.filter { selectedProfileIDs.contains($0.id) }.reduce(0) { $0 + $1.cacheBytes }
    }

    /// Moves selected profiles' cache directories to the Trash.
    func cleanCaches() async {
        let selected = profiles.filter { selectedProfileIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [home.appendingPathComponent("Library/Caches")]),
            dryRun: dryRun)
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
                ProgressView("Detecting browser profiles…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("No browser data found").font(.title3.weight(.semibold))
                    Text("Safari data requires Full Disk Access; Chrome and Firefox profiles are detected automatically when present.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results:
                resultsView
            case let .finished(freed, dryRun):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 48)).foregroundStyle(MCTheme.success)
                    Text(dryRun ? "Dry run: \(mcFormatBytes(freed)) of caches would move to Trash"
                                : "\(mcFormatBytes(freed)) of caches moved to Trash")
                        .font(.title3.weight(.semibold))
                    Button("Scan Again") { Task { await model.scan() } }
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
                Label("\(running.joined(separator: ", ")) is running — cache files may be locked. Quit the browser first for a complete clean.",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(MCTheme.warning)
                    .padding(.horizontal).padding(.top, 12)
            }
            HStack {
                Text("Browser caches — \(mcFormatBytes(model.selectedCacheBytes)) selected")
                    .font(.headline)
                Spacer()
                Toggle("Dry run", isOn: $model.dryRun).toggleStyle(.switch)
                Button(model.dryRun ? "Simulate Clean" : "Clean Caches") {
                    Task { await model.cleanCaches() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedProfileIDs.isEmpty)
            }
            .padding()
            List(model.profiles) { profile in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { model.selectedProfileIDs.contains(profile.id) },
                        set: { on in
                            if on { model.selectedProfileIDs.insert(profile.id) }
                            else { model.selectedProfileIDs.remove(profile.id) }
                        }
                    ))
                    .labelsHidden()
                    .disabled(profile.cacheURLs.isEmpty)
                    VStack(alignment: .leading) {
                        Text("\(profile.browser) — \(profile.profileName)")
                        HStack(spacing: 12) {
                            Text("Cache \(mcFormatBytes(profile.cacheBytes))")
                            Text("History \(mcFormatBytes(profile.historyBytes))")
                            Text("Cookies \(mcFormatBytes(profile.cookieBytes))")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .listStyle(.inset)
            Text("Only caches are cleaned (rebuilt automatically, moved to Trash). History, cookies and sessions are shown for information; removing them is not yet supported to avoid corrupting browser databases or logging you out.")
                .font(.caption).foregroundStyle(.secondary)
                .padding()
        }
    }
}
