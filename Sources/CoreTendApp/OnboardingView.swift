// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
@preconcurrency import UserNotifications
import DesignSystem

/// Detects real permission state. Full Disk Access is probed by attempting to
/// read a TCC-protected location — never assumed from user actions.
enum PermissionProbe {
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Mail"),
        ]
        for probe in probes where FileManager.default.fileExists(atPath: probe.path) {
            if (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil {
                return true
            }
        }
        // Probe dirs missing entirely: cannot determine; report false (honest default).
        return false
    }

    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - View model

@MainActor
@Observable
final class OnboardingViewModel {
    // Security profile
    var profile: SecurityProfile = .recommended
    var config = SecurityConfig.safeDefaults

    // Live permission / capability state (queried, never simulated)
    var fdaGranted = PermissionProbe.hasFullDiskAccess()
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var notificationsOptIn = false

    // Folders & exclusions
    var scannableFolders: [URL] = []
    var exclusions: [URL] = []

    // System check
    var checkItems: [SystemCheck.Item] = []
    var checkOverall: SystemCheck.Status = .ok
    var checkRun = false

    // Launch location
    let launchLocation = LaunchLocation.detect(
        bundlePath: Bundle.main.bundlePath,
        home: NSHomeDirectory())
    var moveAttempted = false
    var moveResult: String?

    func onAppear() {
        config = SecurityConfig.forProfile(profile)
        // Default scannable folders: the user's Downloads (safe, common target).
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) { scannableFolders = [downloads] }
    }

    func selectProfile(_ p: SecurityProfile) {
        profile = p
        if p != .custom { config = SecurityConfig.forProfile(p) }
    }

    func refreshPermissions() async {
        fdaGranted = PermissionProbe.hasFullDiskAccess()
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Toggles notification opt-in. Enabling requests real authorization; we
    /// never claim it was granted — we re-read the actual status afterwards.
    func setNotifications(_ on: Bool) async {
        notificationsOptIn = on
        if on {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        await refreshPermissions()
    }

    func addScannable(_ url: URL) {
        if !scannableFolders.contains(url) { scannableFolders.append(url) }
    }
    func removeScannable(_ url: URL) { scannableFolders.removeAll { $0 == url } }
    func addExclusion(_ url: URL) {
        if !exclusions.contains(url) { exclusions.append(url) }
    }
    func removeExclusion(_ url: URL) { exclusions.removeAll { $0 == url } }

    func runSystemCheck() async {
        await refreshPermissions()
        let inputs = await Self.gatherCheckInputs(fda: fdaGranted)
        checkItems = SystemCheck.items(inputs)
        checkOverall = SystemCheck.overall(checkItems)
        checkRun = true
    }

    private static func gatherCheckInputs(fda: Bool) async -> SystemCheck.Inputs {
        var isARM = false
        #if arch(arm64)
        isARM = true
        #endif
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let freeSpace = (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let homeReadable = (try? FileManager.default.contentsOfDirectory(atPath: home.path)) != nil
        // Resources present iff a known localized string resolves.
        let resourcesPresent = L("onboarding.step0.subtitle") != "onboarding.step0.subtitle"
        var schemaOK = false
        if let store = AppEnvironment.shared.store {
            schemaOK = ((try? await store.schemaVersion()) ?? 0) > 0
        }
        return SystemCheck.Inputs(
            isARM64: isARM,
            macOSMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            bundleValid: Bundle.main.bundleIdentifier != nil,
            resourcesPresent: resourcesPresent,
            sqliteAvailable: schemaOK,
            fullDiskAccess: fda,
            freeSpaceBytes: Int64(freeSpace),
            configuredLocationAccessible: homeReadable,
            safetyCoreReady: AppEnvironment.shared.store != nil)
    }

    /// Persist the profile choice and exclusions.
    func persist() {
        guard let store = AppEnvironment.shared.store else { return }
        let paths = exclusions.map(\.path)
        let profileRaw = profile.rawValue
        Task {
            try? await store.setSetting("securityProfile", value: profileRaw)
            for p in paths { try? await store.addExclusion(path: p) }
        }
    }

    /// Copy the bundle into /Applications (fallback ~/Applications). No sudo,
    /// no privilege escalation: a plain user-space copy. On failure we reveal
    /// the bundle so the user can drag it in themselves.
    func moveToApplications() {
        moveAttempted = true
        let fm = FileManager.default
        let src = URL(fileURLWithPath: Bundle.main.bundlePath)
        let name = src.lastPathComponent
        let candidates = [
            URL(fileURLWithPath: "/Applications").appendingPathComponent(name),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").appendingPathComponent(name),
        ]
        for dest in candidates {
            do {
                try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: dest.path) {
                    moveResult = L("onboarding.move.already", dest.deletingLastPathComponent().path)
                    return
                }
                try fm.copyItem(at: src, to: dest)
                moveResult = L("onboarding.move.done", dest.deletingLastPathComponent().path)
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                return
            } catch { continue }
        }
        // Could not copy anywhere writable: fall back to drag-in-Finder.
        moveResult = L("onboarding.move.manual")
        NSWorkspace.shared.activateFileViewerSelecting([src])
    }
}

// MARK: - View

/// Short, skippable, resumable first-run wizard. Seven steps, no forced
/// permission, keyboard-operable, FR/EN, light/dark, Reduce-Motion aware.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("onboardingStep") private var step = 0
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var model = OnboardingViewModel()

    private let stepCount = 7

    private var appVersion: String {
        AppMetadata.marketingVersion
    }

    var body: some View {
        HStack(spacing: 0) {
            railView
            VStack(spacing: 0) {
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MCSpacing.xl)
                        .padding(.vertical, MCSpacing.lg)
                }
                Divider()
                footer
                    .padding(.horizontal, MCSpacing.xl)
                    .padding(.vertical, MCSpacing.md)
            }
        }
        .frame(width: 780, height: 560)
        .accessibilityIdentifier("onboarding.root")
        .onAppear {
            model.onAppear()
            Task { await model.refreshPermissions() }
        }
    }

    // MARK: Brand rail — identity + vertical progress, one frame for every step

    private var railView: some View {
        VStack(alignment: .leading, spacing: MCSpacing.lg) {
            HStack(spacing: MCSpacing.xs) {
                CoreBloomMark(tint: [MCColor.teal], lineWidthFraction: 0.1)
                    .frame(width: 30, height: 30)
                Text(verbatim: "CoreTend").font(MCFont.cardTitle)
            }
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                ForEach(0..<stepCount, id: \.self) { railStepRow($0) }
            }
            Spacer(minLength: 0)
            Text(L("onboarding.welcome.version", appVersion))
                .font(MCFont.badge).foregroundStyle(.tertiary)
        }
        .padding(MCSpacing.lg)
        .frame(width: 236)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [MCColor.teal.opacity(0.10), MCColor.elevatedBackground],
                           startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .trailing) {
            Rectangle().fill(MCColor.separator.opacity(0.6)).frame(width: 1)
        }
        .animation(.smooth(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("onboarding.step_a11y", step + 1, stepCount))
        .accessibilityIdentifier("onboarding.step")
    }

    private func railStepRow(_ i: Int) -> some View {
        let done = i < step
        let current = i == step
        return HStack(alignment: .top, spacing: MCSpacing.xs) {
            Image(systemName: done ? "checkmark.circle.fill" : (current ? "circle.inset.filled" : "circle"))
                .font(.system(size: 13))
                .foregroundStyle(done || current ? AnyShapeStyle(MCColor.teal) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
            Text(stepTitle(i))
                .font(MCFont.caption)
                .fontWeight(current ? .semibold : .regular)
                .foregroundStyle(current ? AnyShapeStyle(.primary)
                                 : (done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func stepTitle(_ i: Int) -> String {
        switch i {
        case 0: L("onboarding.step0.title")
        case 1: L("onboarding.security.title")
        case 2: L("onboarding.fileaccess.title")
        case 3: L("onboarding.menubar.title")
        case 4: L("onboarding.folders.title")
        case 5: L("onboarding.check.title")
        default: L("onboarding.summary.title")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: securityStep
        case 2: fileAccessStep
        case 3: menuBarStep
        case 4: foldersStep
        case 5: systemCheckStep
        default: summaryStep
        }
    }

    // MARK: Step 0 — Welcome

    private var welcomeStep: some View {
        page {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(L("onboarding.step0.title")).font(MCFont.heroTitle)
                // The product signature — identical here, on the site, in the
                // DMG and in the README. A product that introduces itself
                // differently in each place reads as several products.
                Text(L("onboarding.step0.signature"))
                    .font(MCFont.pageTitle).foregroundStyle(MCColor.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L("onboarding.step0.subtitle"))
                .font(MCFont.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                bullet("internaldrive", L("onboarding.welcome.local"))
                bullet("person.crop.circle.badge.xmark", L("onboarding.welcome.no_account"))
                bullet("antenna.radiowaves.left.and.right.slash", L("onboarding.welcome.no_telemetry"))
                bullet("chevron.left.forwardslash.chevron.right", L("onboarding.welcome.open_source"))
            }
            Divider().padding(.vertical, MCSpacing.xxs)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("onboarding.language.title")).font(MCFont.sectionTitle).foregroundStyle(.secondary)
                Picker(L("onboarding.language.title"), selection: $appLanguageRaw) {
                    Text(L("settings.language.system")).tag(AppLanguage.system.rawValue)
                    Text("Français").tag(AppLanguage.fr.rawValue)
                    Text("English").tag(AppLanguage.en.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .accessibilityIdentifier("onboarding.language")
                Text(L("onboarding.language.subtitle"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.launchLocation.canOfferMove { moveBanner }
        }
    }

    private var moveBanner: some View {
        VStack(spacing: MCSpacing.xs) {
            Text(L("onboarding.move.prompt")).font(MCFont.secondaryBody)
                .multilineTextAlignment(.center)
            if let result = model.moveResult {
                Text(result).font(MCFont.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button(L("onboarding.move.button")) { model.moveToApplications() }
            }
        }
        .padding(MCSpacing.md)
        .frame(maxWidth: 440)
        .background(MCColor.storage.opacity(0.08), in: RoundedRectangle(cornerRadius: MCRadius.card))
    }

    // MARK: Step 1 — Security profile

    private var securityStep: some View {
        page {
            stepHeader("lock.shield", L("onboarding.security.title"), L("onboarding.security.subtitle"))
            VStack(spacing: MCSpacing.sm) {
                ForEach(SecurityProfile.allCases) { p in profileRow(p) }
            }
            .frame(maxWidth: 460)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                configFixed(L("onboarding.security.trash"), on: model.config.useTrash)
                configFixed(L("onboarding.security.medium_risk"), on: model.config.mediumRiskRules)
                configFixed(L("onboarding.security.empty_trash"), on: model.config.emptyTrash)
                configFixed(L("onboarding.security.auto_quarantine"), on: model.config.autoQuarantine)
            }
            .frame(maxWidth: 460)
        }
    }

    private func profileRow(_ p: SecurityProfile) -> some View {
        Button {
            model.selectProfile(p)
        } label: {
            HStack(alignment: .top, spacing: MCSpacing.sm) {
                Image(systemName: model.profile == p ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.profile == p ? MCColor.teal : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("onboarding.security.\(p.rawValue)")).font(MCFont.secondaryBody).bold()
                    Text(L("onboarding.security.\(p.rawValue)_detail"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(MCSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(model.profile == p ? MCColor.teal.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: MCRadius.small))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.profile == p ? [.isSelected] : [])
    }

    private func configFixed(_ label: String, on: Bool) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(on ? MCTheme.success : .secondary)
            Text(label).font(MCFont.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Step 2 — File access

    private var fileAccessStep: some View {
        page {
            stepHeader("folder.badge.questionmark", L("onboarding.fileaccess.title"),
                       L("onboarding.fileaccess.subtitle"))
            MCStatusBadge(model.fdaGranted ? L("settings.granted") : L("settings.not_granted"),
                          status: model.fdaGranted ? .success : .neutral)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                bullet("checkmark.circle", L("onboarding.fileaccess.can_scan"))
                if !model.fdaGranted {
                    bullet("minus.circle", L("onboarding.fileaccess.limited"))
                }
            }
            .frame(maxWidth: 460)
            if !model.fdaGranted {
                HStack(spacing: MCSpacing.sm) {
                    Button(L("settings.open_system_settings")) { PermissionProbe.openFullDiskAccessSettings() }
                    Button(L("settings.recheck")) { Task { await model.refreshPermissions() } }
                }
                Text(L("onboarding.fileaccess.no_autogrant"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 460)
            }
        }
    }


    // MARK: Step 3 — Menu bar & notifications

    private var menuBarStep: some View {
        page {
            stepHeader("menubar.arrow.up.rectangle", L("onboarding.menubar.title"),
                       L("onboarding.menubar.subtitle"))
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                Toggle(L("onboarding.menubar.show"), isOn: $menuBarEnabled)
                Toggle(L("onboarding.menubar.notifications"),
                       isOn: Binding(get: { model.notificationsOptIn },
                                     set: { on in Task { await model.setNotifications(on) } }))
                if model.notificationStatus == .denied {
                    Text(L("onboarding.menubar.denied"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                    Button(L("settings.open_system_settings")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text(L("onboarding.menubar.optin_detail"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 460)
        }
    }

    // MARK: Step 4 — Folders & exclusions

    private var foldersStep: some View {
        page {
            stepHeader("folder.badge.gearshape", L("onboarding.folders.title"),
                       L("onboarding.folders.subtitle"))
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                folderSection(L("onboarding.folders.scannable"), model.scannableFolders,
                              add: { model.addScannable($0) }, remove: { model.removeScannable($0) })
                Text(L("onboarding.folders.protected"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                Divider()
                folderSection(L("onboarding.folders.exclusions"), model.exclusions,
                              add: { model.addExclusion($0) }, remove: { model.removeExclusion($0) })
            }
            .frame(maxWidth: 460)
        }
    }

    private func folderSection(_ title: String, _ folders: [URL],
                               add: @escaping (URL) -> Void, remove: @escaping (URL) -> Void) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            HStack {
                Text(title).font(MCFont.secondaryBody).bold()
                Spacer()
                Button(L("onboarding.folders.add")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url { add(url) }
                }
            }
            ForEach(folders, id: \.self) { url in
                HStack {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text(url.path).lineLimit(1).truncationMode(.middle).font(MCFont.caption)
                    Spacer()
                    Button {
                        remove(url)
                    } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L("settings.remove_exclusion", url.lastPathComponent))
                }
            }
        }
    }

    // MARK: Step 5 — System check

    private var systemCheckStep: some View {
        page {
            stepHeader("stethoscope", L("onboarding.check.title"), L("onboarding.check.subtitle"))
            if model.checkRun {
                MCStatusBadge(overallLabel(model.checkOverall), status: overallBadge(model.checkOverall))
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    ForEach(model.checkItems, id: \.id) { item in
                        HStack(spacing: MCSpacing.sm) {
                            Image(systemName: itemIcon(item.status))
                                .foregroundStyle(itemColor(item.status))
                            Text(L("onboarding.check.\(item.id)")).font(MCFont.caption)
                            Spacer()
                            Text(statusLabel(item.status)).font(MCFont.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 460)
            } else {
                ProgressView().controlSize(.large)
                Text(L("onboarding.check.running")).font(MCFont.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: step) { if step == 5 { await model.runSystemCheck() } }
    }

    // MARK: Step 6 — Summary

    private var summaryStep: some View {
        page {
            stepHeader("checkmark.seal", L("onboarding.summary.title"), L("onboarding.summary.subtitle"))
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                summaryRow(L("onboarding.summary.profile"), L("onboarding.security.\(model.profile.rawValue)"))
                summaryRow(L("onboarding.summary.fda"),
                           model.fdaGranted ? L("settings.granted") : L("settings.not_granted"))
                summaryRow(L("onboarding.summary.menu_bar"), yesNo(menuBarEnabled))
                summaryRow(L("onboarding.summary.notifications"), yesNo(model.notificationsOptIn))
                summaryRow(L("onboarding.summary.exclusions"), "\(model.exclusions.count)")
            }
            .frame(maxWidth: 460)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                bullet("lock", L("onboarding.summary.privacy"))
                bullet("arrow.uturn.backward", L("onboarding.summary.restore"))
            }
            .frame(maxWidth: 460)
            Link(L("onboarding.summary.docs"),
                 destination: URL(string: "https://github.com/ahmetbsbnr/coretend")!)
                .font(MCFont.caption)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(L("onboarding.skip")) { model.persist(); finish() }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding.skip")
            Spacer()
            if step > 0 {
                Button(L("onboarding.back")) { step -= 1 }
                    .accessibilityIdentifier("onboarding.back")
            }
            Button(step == stepCount - 1 ? L("onboarding.start") : L("onboarding.continue")) {
                if step == stepCount - 1 { model.persist(); finish() } else { step += 1 }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(step == stepCount - 1 ? "onboarding.start" : "onboarding.continue")
        }
    }

    private func finish() {
        step = 0
        isPresented = false
    }

    // MARK: Shared building blocks

    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.lg) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepHeader(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(MCColor.teal)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(title).font(MCFont.pageTitle)
                Text(subtitle).font(MCFont.secondaryBody).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.xs) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(MCColor.teal)
                .accessibilityHidden(true)
            Text(text).font(MCFont.secondaryBody)
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(MCFont.secondaryBody)
            Spacer()
            Text(value).font(MCFont.secondaryBody).foregroundStyle(.secondary)
        }
    }

    private func yesNo(_ v: Bool) -> String { v ? L("common.yes") : L("common.no") }

    // System-check presentation helpers
    private func itemIcon(_ s: SystemCheck.Status) -> String {
        switch s {
        case .ok: "checkmark.circle.fill"
        case .limited: "exclamationmark.circle"
        case .actionRequired: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.octagon.fill"
        }
    }
    private func itemColor(_ s: SystemCheck.Status) -> Color {
        switch s {
        case .ok: MCTheme.success
        case .limited: MCTheme.warning
        case .actionRequired: MCTheme.warning
        case .unavailable: MCTheme.danger
        }
    }
    private func statusLabel(_ s: SystemCheck.Status) -> String {
        switch s {
        case .ok: L("onboarding.check.status.ok")
        case .limited: L("onboarding.check.status.limited")
        case .actionRequired: L("onboarding.check.status.action")
        case .unavailable: L("onboarding.check.status.unavailable")
        }
    }
    private func overallLabel(_ s: SystemCheck.Status) -> String {
        switch s {
        case .ok: L("onboarding.check.overall.ready")
        case .limited: L("onboarding.check.overall.limits")
        case .actionRequired: L("onboarding.check.overall.action")
        case .unavailable: L("onboarding.check.overall.unavailable")
        }
    }
    private func overallBadge(_ s: SystemCheck.Status) -> MCStatus {
        switch s {
        case .ok: .success
        case .limited, .actionRequired: .attention
        case .unavailable: .error
        }
    }
}
