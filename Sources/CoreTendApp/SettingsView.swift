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
        dryRunDefault = AppEnvironment.dryRunEnabled(fromSetting: try? await store.setting("dryRunDefault"))
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
        case .authorized, .provisional, .ephemeral: L("settings.notif.authorized")
        case .denied: L("settings.notif.denied")
        case .notDetermined: L("settings.notif.not_requested")
        @unknown default: L("settings.notif.unknown")
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
    @State private var showDiagnostic = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section(L("settings.general")) {
                Toggle(L("settings.show_menu_bar"), isOn: $menuBarEnabled)
                Text(L("settings.menu_bar_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.appearance")) {
                Text(L("settings.appearance_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.scans_cleanup")) {
                Toggle(L("settings.dry_run_default"), isOn: $model.dryRunDefault)
                    .onChange(of: model.dryRunDefault) { model.saveDryRun() }
                Text(L("settings.dry_run_detail"))
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent(L("settings.deletion_method"), value: L("settings.deletion_method_value"))
            }
            Section(L("settings.protection")) {
                LabeledContent(L("settings.clamav_engine")) {
                    Label(model.scanner.isAvailable ? L("settings.installed") : L("settings.not_installed"),
                          systemImage: model.scanner.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(model.scanner.isAvailable ? MCTheme.success : .secondary)
                }
                if !model.scanner.isAvailable {
                    Text(L("settings.clamav_install_hint"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent(L("settings.privileged_helper")) {
                    Label(L("settings.unavailable"), systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                Text(L("settings.privileged_helper_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.monitoring_permissions")) {
                LabeledContent(L("settings.full_disk_access")) {
                    Label(model.fullDiskAccess ? L("settings.granted") : L("settings.not_granted"),
                          systemImage: model.fullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.fullDiskAccess ? MCTheme.success : MCTheme.warning)
                }
                if !model.fullDiskAccess {
                    HStack {
                        Button(L("settings.open_system_settings")) { PermissionProbe.openFullDiskAccessSettings() }
                        Button(L("settings.recheck")) { Task { await model.refreshPermissions() } }
                    }
                }
                LabeledContent(L("settings.notifications")) {
                    Label(notificationStatusLabel, systemImage: notificationStatusIcon)
                        .foregroundStyle(notificationStatusColor)
                }
                if model.notificationStatus == .denied {
                    Button(L("settings.open_system_settings")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text(L("settings.notifications_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.exclusions")) {
                if model.exclusions.isEmpty {
                    Text(L("settings.exclusions_empty"))
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
                        .accessibilityLabel(L("settings.remove_exclusion", path))
                    }
                }
                Button(L("settings.add_folder")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.addExclusion(url)
                    }
                }
            }
            Section(L("settings.data")) {
                Text(L("settings.data_detail"))
                    .font(.caption).foregroundStyle(.secondary)
                // Shown only when the rename migration actually did something.
                // A migration that moved a user's history has to say so, and a
                // migration that failed must never look like one that worked.
                if let report = AppEnvironment.shared.migrationReport {
                    MigrationNoticeRow(report: report)
                }
                Button(L("settings.clear_activity"), role: .destructive) { showClearConfirm = true }
                    .confirmationDialog(L("settings.clear_activity_confirm"), isPresented: $showClearConfirm) {
                        Button(L("settings.clear_history"), role: .destructive) { model.clearActivityHistory() }
                        Button(L("common.cancel"), role: .cancel) {}
                    } message: {
                        Text(L("settings.clear_activity_message"))
                    }
                Button(L("settings.export_diagnostic")) { showDiagnostic = true }
                    .sheet(isPresented: $showDiagnostic) { DiagnosticReportView() }
                Text(L("settings.export_diagnostic_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.about")) {
                LabeledContent(L("settings.version"), value: appVersion)
                Button(L("settings.rerun_setup")) {
                    NotificationCenter.default.post(name: .mcShowOnboarding, object: nil)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("settings.nav_title"))
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

/// Reports the outcome of the one-time MacCare Local -> CoreTend data
/// migration. Deliberately plain: it states what moved, what was left alone,
/// and — most importantly — that the old data is still on disk, because the
/// first question a user has after an app renames itself is whether their
/// history survived.
struct MigrationNoticeRow: View {
    let report: LegacyDataMigration.Report

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(failed ? MCTheme.warning : MCTheme.success)
                    .accessibilityHidden(true)
                Text(failed ? L("settings.migration_failed") : L("settings.migration_done"))
                    .font(.callout.weight(.medium))
            }
            Text(detail)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var failed: Bool { !report.failures.isEmpty }

    private var detail: String {
        if failed {
            let items = report.failures.map { "\($0.item): \($0.reason)" }.joined(separator: "; ")
            return L("settings.migration_failed_detail", items)
        }
        var parts: [String] = []
        if !report.migrated.isEmpty {
            parts.append(L("settings.migration_items", report.migrated.joined(separator: ", ")))
        }
        if !report.migratedPreferenceKeys.isEmpty {
            parts.append(L("settings.migration_prefs"))
        }
        parts.append(L("settings.migration_source_kept"))
        return parts.joined(separator: " ")
    }
}
