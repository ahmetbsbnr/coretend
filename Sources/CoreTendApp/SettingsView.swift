// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import Persistence
import DesignSystem
import IntegrityCore

@MainActor
@Observable
final class SettingsViewModel {
    var exclusions: [String] = []
    var loaded = false

    // Real, queried permission/availability states — never simulated.
    var authorization = SystemAuthorization.Report(statuses: [])
    var appSignature = CodeSignInspector.inspect(at: Bundle.main.bundleURL)

    func load() async {
        guard let store = AppEnvironment.shared.store else { return }
        exclusions = (try? await store.exclusions()) ?? []
        loaded = true
        await refreshPermissions()
    }

    func refreshPermissions() async {
        // Off the main actor: every probe is a real directory read, and on a
        // Mac with slow or sleeping external disks that is not instant.
        authorization = await Task.detached { SystemAuthorization.probeLive() }.value
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

    /// Erases the Record — both tables, the same action the Record itself
    /// offers. Settings used to clear only the activity table and call it
    /// "history", leaving the audit trail in place: half an erase.
    func eraseRecord() {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.purgeSafetyLog()
            try? await store.clearActivity()
        }
    }
}

struct MCSettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showClearConfirm = false
    @State private var showDiagnostic = false


    /// Tabs, not one scroll.
    ///
    /// Every section below existed already; they were stacked in a single
    /// Form, so a window opening on "Language" and "Show in the menu bar" hid
    /// permissions, exclusions, data and about beneath them. macOS Settings
    /// windows are tabbed, people look for the tabs, and declaring them costs
    /// nothing but the enum.
    var body: some View {
        // `.tabItem`, not the macOS 15 `Tab` type: the deployment target is
        // macOS 14, and this is the same tabbed Settings window either way.
        TabView {
            Form { generalSection }.formStyle(.grouped)
                .tabItem { Label(L("settings.general"), systemImage: "gearshape") }
            Form { permissionsSection }.formStyle(.grouped)
                .tabItem { Label(L("settings.permissions"), systemImage: "lock") }
            Form { exclusionsSection }.formStyle(.grouped)
                .tabItem { Label(L("settings.exclusions"), systemImage: "minus.circle") }
            Form { dataSection; UpdatesView() }.formStyle(.grouped)
                .tabItem { Label(L("settings.data"), systemImage: "externaldrive") }
            Form { aboutSection }.formStyle(.grouped)
                .tabItem { Label(L("settings.about"), systemImage: "info.circle") }
        }
        // No tall minimum. A Settings window sizes to the tab showing, and
        // General holds two preferences: forcing 520 points left two thirds of
        // it empty whatever was selected.
        //
        // A *width* minimum is the opposite case. macOS Settings windows keep
        // one width across their tabs — switching tab moves the content, not
        // the window — and without it this one jumped from the width of
        // "Language" to the width of the longest exclusion path and back on
        // every click. Height still follows the tab; width does not.
        .frame(minWidth: 540)
        .onAppear { CaptureHarness.note(window: "settings") }
        .navigationTitle(L("settings.nav_title"))
        .accessibilityIdentifier("settings.root")
        .task { await model.load() }
    }

    @ViewBuilder
    private var generalSection: some View {
        Group {
            // Shown first and unconditionally when the database failed to
            // open. Previously this state was completely invisible: the app
            // ran, the Safety Log rendered a normal empty state, and every
            // write went nowhere.
            if let reason = AppEnvironment.shared.storeState.failureReason {
                Section {
                    HStack(alignment: .top, spacing: MCSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(MCTheme.warning)
                            .accessibilityHidden(true)
                        Text(AppEnvironment.shared.storeState.store == nil
                             ? L("settings.store_unavailable", reason)
                             : L("settings.store_ephemeral", reason))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.store_failure")
                }
            }
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
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        Group {
            Section(L("settings.permissions")) {
                // One row per capability, with its real three-state grant.
                // The previous single "Full Disk Access: Not granted" row was
                // both incomplete and, on a Mac with nothing to probe, wrong.
                ForEach(model.authorization.statuses) { status in
                    LabeledContent(L(status.capability.titleKey)) {
                        Label(L(grantKey(status.grant)), systemImage: grantIcon(status.grant))
                            .foregroundStyle(grantColor(status.grant))
                    }
                    .accessibilityIdentifier("settings.authorization.\(status.capability.rawValue)")
                    // The consequence, shown only where there is one. A refusal
                    // the user cannot act on is worth less than knowing which
                    // scan will come back short.
                    if status.grant.needsAttention {
                        Text(L(status.capability.impactKey))
                            .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                }
                HStack {
                    // Offered only for the one grant a Settings pane can
                    // actually give. The per-folder grants have no such pane.
                    if model.authorization.grant(for: .fullDisk).needsAttention,
                       let url = SystemAuthorization.fullDiskAccessSettingsURL {
                        Button(L("settings.open_system_settings")) { NSWorkspace.shared.open(url) }
                            .accessibilityIdentifier("settings.full_disk.open")
                    }
                    Button(L("authorization.recheck")) { Task { await model.refreshPermissions() } }
                        .accessibilityIdentifier("settings.full_disk.recheck")
                }
                Text(model.authorization.isComplete
                     ? L("authorization.complete")
                     : L("authorization.incomplete", model.authorization.denied.count))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var exclusionsSection: some View {
        Group {
            Section {
                if model.exclusions.isEmpty {
                    Text(L("settings.exclusions_empty"))
                        .foregroundStyle(MCColor.textSecondary)
                }
                ForEach(model.exclusions, id: \.self) { path in
                    HStack {
                        // Abbreviated, with the literal path one hover away.
                        // A column of "/Users/<name>/Library/…" strings is a
                        // column whose first thirty characters are identical,
                        // so middle truncation was truncating the only part
                        // that told them apart.
                        Text(PathDisplay.abbreviate(URL(fileURLWithPath: path)))
                            .lineLimit(1).truncationMode(.middle)
                            .help(path)
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
                    // Exclusions are folders the app must be able to *see*
                    // in order to skip them, so they are granted like any other
                    // root — in the sandboxed build an unreadable exclusion is
                    // indistinguishable from no exclusion, which is the class
                    // of bug ExclusionsSnapshot exists to prevent.
                    if let url = FolderPicker.chooseFolderOrNil() {
                        model.addExclusion(url)
                    }
                }
                .accessibilityIdentifier("settings.exclusions.add")
            } header: {
                // The count belongs in the header of the thing it counts.
                // "Exclusions" alone made a list of eleven folders and a list
                // of none look like the same section until you read it.
                HStack {
                    Text(L("settings.exclusions"))
                    Spacer()
                    if !model.exclusions.isEmpty {
                        Text(L("settings.exclusions_count", model.exclusions.count))
                            .font(MCFont.caption).monospacedDigit()
                            .foregroundStyle(MCColor.textSecondary)
                    }
                }
            } footer: {
                Text(L("settings.exclusions_footer"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Group {
            Section(L("settings.data")) {
                // Build-aware because the sentence is not the same sentence in
                // both products. The Developer ID build checks for updates over
                // the network; the App Store build cannot. One string claiming
                // "no network calls" was false in one of the two, which is a
                // privacy claim, not a wording preference.
                Text(AppCapabilities.forCurrentBuild().canCheckForUpdates
                     ? L("settings.data_detail_updates")
                     : L("settings.data_detail_offline"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                // Shown only when the rename migration actually did something.
                // A migration that moved a user's history has to say so, and a
                // migration that failed must never look like one that worked.
                if let report = AppEnvironment.shared.migrationReport {
                    MigrationNoticeRow(report: report)
                }
                Button(L("record.purge"), role: .destructive) { showClearConfirm = true }
                    .accessibilityIdentifier("settings.activity.clear")
                    .confirmationDialog(L("record.purge_confirm_title"), isPresented: $showClearConfirm) {
                        Button(L("record.purge_confirm_action"), role: .destructive) { model.eraseRecord() }
                        Button(L("common.cancel"), role: .cancel) {}
                    } message: {
                        Text(L("settings.erase_record_message"))
                    }
                Button(L("settings.export_diagnostic")) { showDiagnostic = true }
                    .accessibilityIdentifier("settings.diagnostic.export")
                    .sheet(isPresented: $showDiagnostic) { DiagnosticReportView() }
                Text(L("settings.export_diagnostic_detail"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Group {
            // No version row here: the installed version is stated once, in
            // Updates, where it is the operand of the comparison against the
            // published release. Two rows showing the same number in one
            // window is not thoroughness, it is noise.
            Section(L("settings.about")) {
                LabeledContent(L("settings.this_copy_signature")) {
                    Label(model.appSignature.tier == .adHocOrUnsigned ? L("settings.not_installed") : L("settings.installed"),
                          systemImage: model.appSignature.tier == .adHocOrUnsigned ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(model.appSignature.tier == .adHocOrUnsigned ? .secondary : MCTheme.success)
                }
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
    }

    // MARK: - Grant presentation
    //
    // Three visual states, not two. `undetermined` and `notApplicable` are
    // deliberately neutral grey with a dash: neither is a problem, and
    // painting them as warnings is what made the old single Full Disk Access
    // row tell users to fix permissions that were never refused.

    private func grantKey(_ grant: SystemAuthorization.Grant) -> String {
        "authorization.\(grant.rawValue)"
    }

    private func grantIcon(_ grant: SystemAuthorization.Grant) -> String {
        switch grant {
        case .granted: "checkmark.circle.fill"
        case .denied: "exclamationmark.triangle.fill"
        case .undetermined, .notApplicable: "minus.circle"
        }
    }

    private func grantColor(_ grant: SystemAuthorization.Grant) -> Color {
        switch grant {
        case .granted: MCTheme.success
        case .denied: MCTheme.warning
        case .undetermined, .notApplicable: .secondary
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
                    .font(MCFont.rowTitle)
            }
            Text(detail)
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
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
