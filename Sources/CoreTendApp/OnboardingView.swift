// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// First run. Three steps, all skippable, reopenable from Help.
///
/// It was seven: welcome, a "security profile" choice, file access, the menu
/// bar, folders to scan and exclude, a system check, a summary. Most of that
/// asked the person to decide things the app should simply do right — there
/// is one safety behaviour (the Trash, always), the menu bar is a setting,
/// exclusions are a setting, and the system check is what Overview's
/// "Needs attention" list is for. What is left is what a first run genuinely
/// has to do: say what the app is, get the one permission that matters, and
/// start. See docs/INFORMATION_ARCHITECTURE.md § Onboarding.
@MainActor
@Observable
final class OnboardingViewModel {
    var fdaGranted = SystemAuthorization.probeLive().hasFullDiskAccess
    let launchLocation = LaunchLocation.detect(bundlePath: Bundle.main.bundlePath, home: NSHomeDirectory())
    var moveAttempted = false
    var moveResult: String?

    func refreshPermissions() async {
        fdaGranted = SystemAuthorization.probeLive().hasFullDiskAccess
    }

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
        moveResult = L("onboarding.move.manual")
        NSWorkspace.shared.activateFileViewerSelecting([src])
    }
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var step = 0
    @State private var model = OnboardingViewModel()

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: accessStep
                    default: startStep
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MCSpacing.xl)
                .padding(.vertical, MCSpacing.lg)
                // The step replaces itself rather than cutting. Opacity only,
                // and only 160 ms: a slide would imply a spatial relationship
                // between three unrelated screens, and anything longer turns
                // the second click of a three-click flow into a wait.
                .id(step)
                .transition(.opacity)
            }
            .mcAnimation(MCMotion.transition, value: step)
            Divider()
            footer
                .padding(.horizontal, MCSpacing.xl)
                .padding(.vertical, MCSpacing.md)
        }
        // Sized to its content, not to a fixed 480.
        //
        // The first step ends after the "move to Applications" notice, so a
        // fixed height left roughly two hundred points of nothing between the
        // last control and the footer — on the very first thing anyone sees.
        .frame(width: 640)
        .frame(minHeight: 380)
        .accessibilityIdentifier("onboarding.root")
        .onAppear { CaptureHarness.note(state: "onboarding") }
        .task { await model.refreshPermissions() }
    }

    // MARK: Step 1 — what this is

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            // The app's own icon, at the size the Finder shows it. The first
            // screen of a first run is the one place where saying "this is
            // the thing you just installed" is the content, not decoration —
            // and it is the real icon, not an illustration of one.
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(L("onboarding.step0.title")).font(MCFont.heroTitle)
            Text(L("onboarding.step0.subtitle"))
                .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                bullet("internaldrive", L("onboarding.welcome.local"))
                bullet("trash", L("onboarding.welcome.trash_only"))
                bullet("antenna.radiowaves.left.and.right.slash", L("onboarding.welcome.no_telemetry"))
                bullet("chevron.left.forwardslash.chevron.right", L("onboarding.welcome.open_source"))
            }
            Picker(L("onboarding.language.title"), selection: $appLanguageRaw) {
                Text(L("settings.language.system")).tag(AppLanguage.system.rawValue)
                Text("Français").tag(AppLanguage.fr.rawValue)
                Text("English").tag(AppLanguage.en.rawValue)
            }
            .pickerStyle(.menu).fixedSize()
            .accessibilityIdentifier("onboarding.language")
            if model.launchLocation.canOfferMove { moveBanner }
        }
    }

    /// Running from Downloads or a disk image is the one thing worth saying
    /// on the first screen: nothing else in the app works reliably from there.
    private var moveBanner: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            Divider()
            Text(L("onboarding.move.title")).font(MCFont.sectionTitle)
            Text(L("onboarding.move.body")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let result = model.moveResult {
                Text(result).font(MCFont.caption)
            } else {
                Button(L("onboarding.move.button")) { model.moveToApplications() }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Step 2 — the one permission that matters

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(L("onboarding.fileaccess.title")).font(MCFont.heroTitle)
            Text(L("onboarding.fileaccess.subtitle"))
                .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: MCSpacing.xs) {
                Image(systemName: model.fdaGranted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.fdaGranted ? MCTheme.success : MCColor.textTertiary)
                    .accessibilityHidden(true)
                Text(model.fdaGranted ? L("settings.granted") : L("settings.not_granted"))
                    .font(MCFont.rowTitle)
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                bullet("checkmark.circle", L("onboarding.fileaccess.can_scan"))
                if !model.fdaGranted { bullet("minus.circle", L("onboarding.fileaccess.limited")) }
            }
            if !model.fdaGranted {
                HStack(spacing: MCSpacing.sm) {
                    Button(L("settings.open_system_settings")) {
                        if let url = SystemAuthorization.fullDiskAccessSettingsURL { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button(L("settings.recheck")) { Task { await model.refreshPermissions() } }
                        .buttonStyle(.bordered)
                }
                Text(L("onboarding.fileaccess.no_autogrant"))
                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Step 3 — start

    private var startStep: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            Text(L("onboarding.start.title")).font(MCFont.heroTitle)
            Text(L("onboarding.start.subtitle"))
                .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                startRow(.cleanup, L("onboarding.start.cleanup"))
                startRow(.spaceLens, L("onboarding.start.explore"))
                startRow(.applications, L("onboarding.start.applications"))
            }
        }
    }

    private func startRow(_ module: ModuleID, _ detail: String) -> some View {
        HStack(spacing: MCSpacing.sm) {
            Image(systemName: module.systemImage).frame(width: 20)
                .foregroundStyle(MCColor.textSecondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(module.label).font(MCFont.rowTitle)
                Text(detail).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            }
            Spacer()
            Button(L("overview.open")) { finish(then: module) }
                .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(L("onboarding.skip")) { finish() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("onboarding.skip")
            Spacer()
            // Dots, not "2 of 3". Three of them are read at a glance as
            // "nearly done"; the sentence has to be read. The sentence stays
            // as the accessibility label, where it is the better form.
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? MCTheme.accent : MCColor.textTertiary.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .mcAnimation(MCMotion.response, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("onboarding.step_of", step + 1, stepCount))
            Spacer()
            if step > 0 {
                Button(L("onboarding.back")) { step -= 1 }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("[", modifiers: .command)
            }
            Button(step == stepCount - 1 ? L("onboarding.start") : L("onboarding.continue")) {
                if step == stepCount - 1 { finish() } else { step += 1 }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(step == stepCount - 1 ? "onboarding.start" : "onboarding.continue")
        }
    }

    private func finish(then module: ModuleID? = nil) {
        isPresented = false
        if let module { NotificationCenter.default.post(name: .mcNavigate, object: module) }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MCSpacing.xs) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(MCColor.textSecondary)
                .accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
