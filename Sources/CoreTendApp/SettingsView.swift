// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
@preconcurrency import UserNotifications
import Persistence
import DesignSystem
import IntegrityCore

@MainActor
@Observable
final class SettingsViewModel {
    var exclusions: [String] = []
    var loaded = false

    var appSignature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)

    /// All permission state comes from the one shared coordinator so Settings
    /// can never disagree with Deep Scan / Onboarding.
    var permissions: PermissionCoordinator { PermissionCoordinator.shared }

    func load() async {
        guard let store = AppEnvironment.shared.store else { return }
        exclusions = (try? await store.exclusions()) ?? []
        loaded = true
        await permissions.refreshNow(.settingsAppear)
    }

    func recheck() async { await permissions.refreshNow(.manual) }

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
    static func notificationLabel(_ status: UNAuthorizationStatus, language: AppLanguage? = nil) -> String {
        let key = switch status {
        case .authorized, .provisional, .ephemeral: "settings.notif.authorized"
        case .denied: "settings.notif.denied"
        case .notDetermined: "settings.notif.not_requested"
        @unknown default: "settings.notif.unknown"
        }
        return language.map { LocalizationManager.string(forKey: key, language: $0) } ?? L(key)
    }

    static func notificationIcon(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        default: "questionmark.circle"
        }
    }

    // Full Disk Access / general permission state.
    static func fdaLabel(_ s: PermissionState) -> String {
        L("perm.state." + s.rawValue)
    }
    static func fdaIcon(_ s: PermissionState) -> String {
        switch s {
        case .granted: "checkmark.circle.fill"
        case .partial: "exclamationmark.circle.fill"
        case .denied, .needsReauthorization: "lock.circle.fill"
        case .checking: "arrow.triangle.2.circlepath.circle"
        case .notRequested: "questionmark.circle"
        case .unavailable: "minus.circle"
        case .error: "exclamationmark.triangle.fill"
        }
    }
    static func fdaTintName(_ s: PermissionState) -> String {   // for a11y-safe mapping
        switch s {
        case .granted: "success"
        case .partial, .notRequested: "attention"
        case .denied, .needsReauthorization, .error: "warning"
        case .checking, .unavailable: "secondary"
        }
    }
    /// Relative "last checked" / "last verified" phrasing.
    static func relative(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return L("perm.never") }
        let s = Int(now.timeIntervalSince(date))
        if s < 5 { return L("perm.just_now") }
        if s < 60 { return L("perm.seconds_ago", "\(s)") }
        if s < 3600 { return L("perm.minutes_ago", "\(s / 60)") }
        if s < 86_400 { return L("perm.hours_ago", "\(s / 3600)") }
        return L("perm.days_ago", "\(s / 86_400)")
    }
}

struct MCSettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showClearConfirm = false
    @State private var showDiagnostic = false

    private var appVersion: String {
        AppMetadata.marketingVersion
    }

    var body: some View {
        Form {
            Section(L("settings.general")) {
                Picker(L("settings.language"), selection: $appLanguageRaw) {
                    Text(L("settings.language.system")).tag(AppLanguage.system.rawValue)
                    Text("Français").tag(AppLanguage.fr.rawValue)
                    Text("English").tag(AppLanguage.en.rawValue)
                }
                .accessibilityIdentifier("settings.language")
                Toggle(L("settings.show_menu_bar"), isOn: $menuBarEnabled)
                    .accessibilityIdentifier("settings.menu_bar")
                Text(L("settings.menu_bar_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.appearance")) {
                Text(L("settings.appearance_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.scans_cleanup")) {
                LabeledContent(L("settings.deletion_method"), value: L("settings.deletion_method_value"))
            }
            Section(L("settings.protection")) {
                LabeledContent(L("settings.this_copy_signature")) {
                    Label(model.appSignature.tier == .adHocOrUnsigned ? L("settings.not_installed") : L("settings.installed"),
                          systemImage: model.appSignature.tier == .adHocOrUnsigned ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(model.appSignature.tier == .adHocOrUnsigned ? .secondary : MCTheme.success)
                }
                LabeledContent(L("settings.privileged_helper")) {
                    Label(L("settings.unavailable"), systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                Text(L("settings.privileged_helper_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            PermissionsSection(model: model)
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
                .accessibilityIdentifier("settings.exclusions.add")
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
                    .accessibilityIdentifier("settings.activity.clear")
                    .confirmationDialog(L("settings.clear_activity_confirm"), isPresented: $showClearConfirm) {
                        Button(L("settings.clear_history"), role: .destructive) { model.clearActivityHistory() }
                        Button(L("common.cancel"), role: .cancel) {}
                    } message: {
                        Text(L("settings.clear_activity_message"))
                    }
                Button(L("settings.export_diagnostic")) { showDiagnostic = true }
                    .accessibilityIdentifier("settings.diagnostic.export")
                    .sheet(isPresented: $showDiagnostic) { DiagnosticReportView() }
                Text(L("settings.export_diagnostic_detail"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            UpdatesView()
            Section(L("settings.about")) {
                LabeledContent(L("settings.version"), value: appVersion)
                Link(L("settings.about.privacy"),
                     destination: URL(string: "https://coretend.ahmetbsbnr.com/privacy")!)
                Link(L("settings.about.license"),
                     destination: URL(string: "https://coretend.ahmetbsbnr.com/licenses")!)
                Link(L("settings.about.source"),
                     destination: URL(string: "https://github.com/ahmetbsbnr/coretend")!)
                Link(L("settings.about.support"),
                     destination: URL(string: "https://coretend.ahmetbsbnr.com/support")!)
                Button(L("settings.rerun_setup")) {
                    NotificationCenter.default.post(name: .mcShowOnboarding, object: nil)
                }
                .accessibilityIdentifier("settings.onboarding.rerun")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("settings.nav_title"))
        .accessibilityIdentifier("settings.root")
        .task { await model.load() }
    }

}

// MARK: - Permissions Center (first-class Settings surface)

/// Everything permission-related in one place, all reading from the single
/// `PermissionCoordinator`. When healthy it is quiet; when something needs
/// attention it says so specifically — never a generic "Unverified".
struct PermissionsSection: View {
    @Bindable var model: SettingsViewModel
    @State private var showDiag = false
    @Environment(\.openURL) private var openURL

    private var coord: PermissionCoordinator { model.permissions }

    var body: some View {
        Section(L("perm.section")) {
            healthSummary

            // --- Full Disk Access ---
            LabeledContent(L("settings.full_disk_access")) {
                Label(PermissionFormatting.fdaLabel(coord.fullDiskAccess),
                      systemImage: PermissionFormatting.fdaIcon(coord.fullDiskAccess))
                    .foregroundStyle(tint(coord.fullDiskAccess))
                    .accessibilityLabel(L("settings.full_disk_access") + ": " + PermissionFormatting.fdaLabel(coord.fullDiskAccess))
            }
            Text(L("perm.fda.why"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if coord.fullDiskAccess == .partial, let p = coord.lastProbe {
                Text(L("perm.fda.partial_detail", "\(p.permissionDenied)"))
                    .font(.caption).foregroundStyle(MCTheme.warning)
            }
            LabeledContent(L("perm.last_checked"), value: PermissionFormatting.relative(coord.lastCheckedAt))
                .font(.caption)
            if coord.lastSuccessfulCheckAt != nil {
                LabeledContent(L("perm.last_verified"),
                               value: PermissionFormatting.relative(coord.lastSuccessfulCheckAt))
                    .font(.caption)
            }
            HStack {
                Button(L("perm.check_again")) { Task { await model.recheck() } }
                    .accessibilityIdentifier("settings.full_disk.recheck")
                Button(L("settings.open_system_settings")) { coord.openFullDiskAccessSettings() }
                    .accessibilityIdentifier("settings.full_disk.open")
                if coord.fullDiskAccess == .partial || coord.fullDiskAccess == .denied {
                    Button(L("perm.relaunch")) { coord.relaunchApp() }
                        .accessibilityIdentifier("settings.full_disk.relaunch")
                }
            }

            // --- Notifications (kept separate from disk access) ---
            LabeledContent(L("settings.notifications")) {
                Label(L("perm.notif." + coord.notifications.rawValue),
                      systemImage: coord.notifications == .allowed ? "checkmark.circle.fill"
                                 : coord.notifications == .denied ? "xmark.circle.fill" : "questionmark.circle")
                    .foregroundStyle(coord.notifications == .allowed ? MCTheme.success
                                   : coord.notifications == .denied ? MCTheme.warning : .secondary)
            }
            if coord.notifications == .denied {
                Button(L("settings.open_system_settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Text(L("settings.notifications_detail")).font(.caption).foregroundStyle(.secondary)

            // --- Diagnostics ---
            Button(L("perm.copy_diagnostics")) {
                let text = coord.diagnosticsText(
                    appVersion: AppMetadata.marketingVersion,
                    buildNumber: AppMetadata.buildNumber,
                    channel: AppMetadata.releaseChannel,
                    bundleID: Bundle.main.bundleIdentifier ?? "—",
                    signingMode: model.appSignature.tier == .adHocOrUnsigned ? "ad-hoc/unsigned" : "signed",
                    teamID: model.appSignature.teamIdentifier)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            .accessibilityIdentifier("settings.permissions.copy_diagnostics")
        }
    }

    @ViewBuilder private var healthSummary: some View {
        let s = coord.fullDiskAccess
        let (text, icon, color): (String, String, Color) = {
            switch s {
            case .granted: return (L("perm.health.ready"), "checkmark.seal.fill", MCTheme.success)
            case .partial: return (L("perm.health.partial"), "exclamationmark.triangle.fill", MCTheme.warning)
            case .checking: return (L("perm.health.checking"), "arrow.triangle.2.circlepath", .secondary)
            case .unavailable, .error: return (L("perm.health.unknown"), "questionmark.circle", .secondary)
            default: return (L("perm.health.needs_attention"), "exclamationmark.circle.fill", MCTheme.warning)
            }
        }()
        Label(text, systemImage: icon)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)
    }

    private func tint(_ s: PermissionState) -> Color {
        switch PermissionFormatting.fdaTintName(s) {
        case "success": MCTheme.success
        case "attention": MCTheme.warning
        case "warning": MCTheme.warning
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
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            HStack(spacing: MCSpacing.xxs) {
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
