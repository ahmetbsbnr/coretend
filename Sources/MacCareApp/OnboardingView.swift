import SwiftUI
import UserNotifications
import DesignSystem
import MalwareEngine

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
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
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

    // Protection
    private let scanner = ClamAVScanner()
    var clamAVAvailable = false
    var clamAVPathRedacted: String?
    var clamAVVersion: ClamAVVersionInfo?

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
        clamAVAvailable = scanner.isAvailable
        clamAVPathRedacted = scanner.binaryURL.map { DiagnosticReport.redactPath($0.path) }
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

    /// Best-effort ClamAV version via `clamscan --version`. Never fabricated:
    /// on any failure the fields stay nil and the UI shows "unknown".
    func probeClamAVVersion() async {
        guard let bin = scanner.binaryURL else { return }
        let out = await Self.runVersion(bin)
        if let out { clamAVVersion = ClamAVVersionInfo.parse(out) }
    }

    private static func runVersion(_ binary: URL) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = binary
                process.arguments = ["--version"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    cont.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
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
        let inputs = await Self.gatherCheckInputs(
            fda: fdaGranted, clamAV: clamAVAvailable)
        checkItems = SystemCheck.items(inputs)
        checkOverall = SystemCheck.overall(checkItems)
        checkRun = true
    }

    private static func gatherCheckInputs(fda: Bool, clamAV: Bool) async -> SystemCheck.Inputs {
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
            clamAVAvailable: clamAV,
            freeSpaceBytes: Int64(freeSpace),
            configuredLocationAccessible: homeReadable,
            safetyCoreReady: AppEnvironment.shared.store != nil)
    }

    /// Persist the chosen configuration. Only `dryRunDefault` is a live knob;
    /// the profile choice and exclusions are recorded too.
    func persist() {
        guard let store = AppEnvironment.shared.store else { return }
        let dryRun = config.dryRun ? "true" : "false"
        let paths = exclusions.map(\.path)
        let profileRaw = profile.rawValue
        Task {
            try? await store.setSetting("dryRunDefault", value: dryRun)
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

/// Short, skippable, resumable first-run wizard. Eight steps, no forced
/// permission, keyboard-operable, FR/EN, light/dark, Reduce-Motion aware.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("onboardingStep") private var step = 0
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @State private var model = OnboardingViewModel()

    private let stepCount = 8

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(MCSpacing.xl)
            }
            Divider()
            footer
                .padding(.horizontal, MCSpacing.xl)
                .padding(.vertical, MCSpacing.md)
        }
        .frame(width: 600, height: 540)
        .onAppear {
            model.onAppear()
            Task { await model.refreshPermissions(); await model.probeClamAVVersion() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: securityStep
        case 2: fileAccessStep
        case 3: protectionStep
        case 4: menuBarStep
        case 5: foldersStep
        case 6: systemCheckStep
        default: summaryStep
        }
    }

    // MARK: Step 0 — Welcome

    private var welcomeStep: some View {
        page {
            CoreBloomMark(tint: [MCColor.storage, MCColor.protection, MCColor.performance])
                .frame(width: 88, height: 88)
            Text("MacCare Local").font(MCFont.heroTitle)
            Text(L("onboarding.step0.subtitle"))
                .font(MCFont.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 440)
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                bullet("internaldrive", L("onboarding.welcome.local"))
                bullet("person.crop.circle.badge.xmark", L("onboarding.welcome.no_account"))
                bullet("antenna.radiowaves.left.and.right.slash", L("onboarding.welcome.no_telemetry"))
                bullet("chevron.left.forwardslash.chevron.right", L("onboarding.welcome.open_source"))
            }
            .frame(maxWidth: 440)
            HStack(spacing: MCSpacing.sm) {
                MCStatusBadge(L("onboarding.welcome.version", appVersion), status: .neutral)
                MCStatusBadge(L("onboarding.welcome.unsigned"), status: .attention)
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
                configLine(L("onboarding.security.dry_run"), on: model.config.dryRun,
                           binding: model.profile == .custom
                               ? Binding(get: { model.config.dryRun }, set: { model.config.dryRun = $0 })
                               : nil)
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
                    .foregroundStyle(model.profile == p ? MCColor.coreMint : .secondary)
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
            .background(model.profile == p ? MCColor.coreMint.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: MCRadius.small))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.profile == p ? [.isSelected] : [])
    }

    private func configLine(_ label: String, on: Bool, binding: Binding<Bool>?) -> some View {
        Group {
            if let binding {
                Toggle(label, isOn: binding).font(MCFont.caption)
            } else {
                configFixed(label, on: on)
            }
        }
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

    // MARK: Step 3 — Optional protection

    private var protectionStep: some View {
        page {
            stepHeader("shield.lefthalf.filled", L("onboarding.protection.title"),
                       L("onboarding.protection.subtitle"))
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                HStack {
                    Label(L("onboarding.protection.clamav"), systemImage: "checkmark.shield")
                    Spacer()
                    MCStatusBadge(model.clamAVAvailable ? L("settings.installed") : L("settings.not_installed"),
                                  status: model.clamAVAvailable ? .success : .neutral)
                }
                if model.clamAVAvailable {
                    if let path = model.clamAVPathRedacted {
                        detailRow(L("onboarding.protection.path"), path)
                    }
                    detailRow(L("onboarding.protection.version"),
                              model.clamAVVersion?.engine ?? L("onboarding.protection.unknown"))
                    detailRow(L("onboarding.protection.signatures"),
                              model.clamAVVersion?.signatures ?? L("onboarding.protection.unknown"))
                } else {
                    Text(L("onboarding.protection.no_install"))
                        .font(MCFont.caption).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Label(L("onboarding.protection.fsevents"), systemImage: "eye")
                    Spacer()
                    MCStatusBadge(L("onboarding.protection.available"), status: .success)
                }
            }
            .frame(maxWidth: 460)
        }
    }

    // MARK: Step 4 — Menu bar & notifications

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

    // MARK: Step 5 — Folders & exclusions

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

    // MARK: Step 6 — System check

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
        .task(id: step) { if step == 6 { await model.runSystemCheck() } }
    }

    // MARK: Step 7 — Summary

    private var summaryStep: some View {
        page {
            stepHeader("checkmark.seal", L("onboarding.summary.title"), L("onboarding.summary.subtitle"))
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                summaryRow(L("onboarding.summary.profile"), L("onboarding.security.\(model.profile.rawValue)"))
                summaryRow(L("onboarding.summary.dry_run"), yesNo(model.config.dryRun))
                summaryRow(L("onboarding.summary.fda"),
                           model.fdaGranted ? L("settings.granted") : L("settings.not_granted"))
                summaryRow(L("onboarding.summary.clamav"),
                           model.clamAVAvailable ? L("settings.installed") : L("settings.not_installed"))
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
            Link(L("onboarding.summary.docs"), destination: URL(string: "https://github.com")!)
                .font(MCFont.caption)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(L("onboarding.skip")) { finish() }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            Text(L("onboarding.step_of", step + 1, stepCount))
                .font(MCFont.caption).foregroundStyle(.secondary)
                .accessibilityLabel(L("onboarding.step_a11y", step + 1, stepCount))
            Spacer()
            if step > 0 { Button(L("onboarding.back")) { step -= 1 } }
            Button(step == stepCount - 1 ? L("onboarding.start") : L("onboarding.continue")) {
                if step == stepCount - 1 { model.persist(); finish() } else { step += 1 }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func finish() {
        step = 0
        isPresented = false
    }

    // MARK: Shared building blocks

    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: MCSpacing.md) { content() }
            .frame(maxWidth: .infinity)
    }

    private func stepHeader(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: MCIconSize.emptyStateProminent, weight: .light))
                .foregroundStyle(MCColor.coreMint)
                .accessibilityHidden(true)
            Text(title).font(MCFont.heroTitle)
            Text(subtitle).font(MCFont.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 460)
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.xs) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(MCColor.coreMint)
                .accessibilityHidden(true)
            Text(text).font(MCFont.secondaryBody)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(MCFont.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(MCFont.caption).lineLimit(1).truncationMode(.middle)
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
