import SwiftUI
import UserNotifications
import Persistence
import DesignSystem
import MalwareEngine

@MainActor
@Observable
final class SettingsViewModel {
    var dryRunDefault = true
    var exclusions: [String] = []
    var loaded = false

    // Real, queried permission/availability states — never simulated.
    var fullDiskAccess = PermissionProbe.hasFullDiskAccess()
    let scanner = ClamAVScanner()
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    func load() async {
        guard let store = AppEnvironment.shared.store else { return }
        dryRunDefault = (try? await store.setting("dryRunDefault")) != "false"
        exclusions = (try? await store.exclusions()) ?? []
        loaded = true
        await refreshPermissions()
    }

    func refreshPermissions() async {
        fullDiskAccess = PermissionProbe.hasFullDiskAccess()
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func saveDryRun() {
        guard let store = AppEnvironment.shared.store else { return }
        let value = dryRunDefault ? "true" : "false"
        Task { try? await store.setSetting("dryRunDefault", value: value) }
    }

    func addExclusion(_ url: URL) {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.addExclusion(path: url.path)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }

    func removeExclusion(_ path: String) {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.removeExclusion(path: path)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }

    func clearActivityHistory() {
        guard let store = AppEnvironment.shared.store else { return }
        Task { try? await store.clearActivity() }
    }
}

/// Pure formatting so permission-state text is directly testable.
enum PermissionFormatting {
    static func notificationLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: "Authorized"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    static func notificationIcon(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        default: "questionmark.circle"
        }
    }
}

struct MCSettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @State private var showClearConfirm = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show MacCare in the menu bar", isOn: $menuBarEnabled)
                Text("The menu bar item samples system metrics only while its panel is open, or every 30s in the background just to show the attention indicator.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Text("MacCare Local follows the system light/dark appearance. There is no separate in-app theme.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Scans & Cleanup") {
                Toggle("Dry run by default", isOn: $model.dryRunDefault)
                    .onChange(of: model.dryRunDefault) { model.saveDryRun() }
                Text("When enabled, cleanups simulate their result instead of moving files to the Trash.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Deletion method", value: "System Trash (reversible)")
            }
            Section("Protection") {
                LabeledContent("ClamAV engine") {
                    Label(model.scanner.isAvailable ? "Installed" : "Not installed",
                          systemImage: model.scanner.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(model.scanner.isAvailable ? MCTheme.success : .secondary)
                }
                if !model.scanner.isAvailable {
                    Text("Install with `brew install clamav`, run `freshclam` once, then reopen Protection.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Privileged helper") {
                    Label("Unavailable", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                Text("Not implemented — this build has no signing identity to install a privileged helper. Every feature works unprivileged; this is a known, honest limitation, not a bug.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Monitoring & Permissions") {
                LabeledContent("Full Disk Access") {
                    Label(model.fullDiskAccess ? "Granted" : "Not granted",
                          systemImage: model.fullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.fullDiskAccess ? MCTheme.success : MCTheme.warning)
                }
                if !model.fullDiskAccess {
                    HStack {
                        Button("Open System Settings") { PermissionProbe.openFullDiskAccessSettings() }
                        Button("Re-check") { Task { await model.refreshPermissions() } }
                    }
                }
                LabeledContent("Notifications") {
                    Label(notificationStatusLabel, systemImage: notificationStatusIcon)
                        .foregroundStyle(notificationStatusColor)
                }
                if model.notificationStatus == .denied {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text("MacCare Local does not currently send notifications; this reflects the real system-level authorization state only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Exclusions") {
                if model.exclusions.isEmpty {
                    Text("No excluded folders. Excluded locations are never scanned or cleaned.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.exclusions, id: \.self) { path in
                    HStack {
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(role: .destructive) {
                            model.removeExclusion(path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.addExclusion(url)
                    }
                }
            }
            Section("Data") {
                Text("MacCare Local is fully offline. No telemetry, no accounts, no network calls. All data stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear Activity History…", role: .destructive) { showClearConfirm = true }
                    .confirmationDialog("Clear all Activity history?", isPresented: $showClearConfirm) {
                        Button("Clear History", role: .destructive) { model.clearActivityHistory() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes the local record of past scans and cleanups. It does not restore or delete any files.")
                    }
            }
            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await model.load() }
    }

    private var notificationStatusLabel: String { PermissionFormatting.notificationLabel(model.notificationStatus) }
    private var notificationStatusIcon: String { PermissionFormatting.notificationIcon(model.notificationStatus) }

    private var notificationStatusColor: Color {
        switch model.notificationStatus {
        case .authorized, .provisional, .ephemeral: MCTheme.success
        case .denied: MCTheme.warning
        default: .secondary
        }
    }
}
