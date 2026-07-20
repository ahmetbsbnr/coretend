import SwiftUI
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
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

/// Short, skippable, resumable onboarding. Four steps, no forced permission.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("onboardingStep") private var step = 0
    @State private var fdaGranted = PermissionProbe.hasFullDiskAccess()

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(MCSpacing.xl)
            Divider()
            footer
                .padding(.horizontal, MCSpacing.xl)
                .padding(.vertical, MCSpacing.md)
        }
        .frame(width: 560, height: 460)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            page {
                CoreBloomMark(tint: [MCColor.storage, MCColor.protection, MCColor.performance])
                    .frame(width: 96, height: 96)
                    .padding(.bottom, MCSpacing.sm)
                Text("MacCare Local").font(MCFont.heroTitle)
                Text(L("onboarding.step0.subtitle"))
                    .font(MCFont.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        case 1:
            page {
                Image(systemName: "lock.laptopcomputer")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.protection)
                Text(L("onboarding.step1.title")).font(MCFont.heroTitle)
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    bullet("internaldrive", L("onboarding.step1.bullet1"))
                    bullet("clock.arrow.circlepath", L("onboarding.step1.bullet2"))
                    bullet("xmark.shield", L("onboarding.step1.bullet3"))
                }
                .frame(maxWidth: 420)
            }
        case 2:
            page {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.storage)
                Text(L("onboarding.step2.title")).font(MCFont.heroTitle)
                Text(L("onboarding.step2.subtitle"))
                    .font(MCFont.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                HStack(spacing: MCSpacing.sm) {
                    MCStatusBadge(fdaGranted ? L("settings.granted") : L("settings.not_granted"),
                                  status: fdaGranted ? .success : .neutral)
                    if !fdaGranted {
                        Button(L("settings.open_system_settings")) { PermissionProbe.openFullDiskAccessSettings() }
                        Button(L("settings.recheck")) { fdaGranted = PermissionProbe.hasFullDiskAccess() }
                    }
                }
            }
        default:
            page {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.success)
                Text(L("onboarding.step3.title")).font(MCFont.heroTitle)
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    bullet("magnifyingglass", L("onboarding.step3.bullet1"))
                    bullet("trash", L("onboarding.step3.bullet2"))
                    bullet("hand.raised", L("onboarding.step3.bullet3"))
                }
                .frame(maxWidth: 420)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(L("onboarding.skip")) { finish() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            // Step indicator: position + text, not color alone.
            Text(L("onboarding.step_of", step + 1, stepCount))
                .font(MCFont.caption).foregroundStyle(.secondary)
                .accessibilityLabel(L("onboarding.step_a11y", step + 1, stepCount))
            Spacer()
            if step > 0 {
                Button(L("onboarding.back")) { step -= 1 }
            }
            Button(step == stepCount - 1 ? L("onboarding.get_started") : L("onboarding.continue")) {
                if step == stepCount - 1 { finish() } else { step += 1 }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func finish() {
        step = 0
        isPresented = false
    }

    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: MCSpacing.md) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: MCSpacing.xs) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(MCColor.coreMint)
            Text(text).font(MCFont.secondaryBody)
        }
    }
}
