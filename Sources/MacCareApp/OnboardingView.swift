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
                Text("Storage, protection and performance care for this Mac — nothing more, nothing hidden.")
                    .font(MCFont.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        case 1:
            page {
                Image(systemName: "lock.laptopcomputer")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.protection)
                Text("Everything stays here").font(MCFont.heroTitle)
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    bullet("internaldrive", "All analysis runs on this Mac. No accounts, no telemetry, no network calls.")
                    bullet("clock.arrow.circlepath", "Your history lives in a local database you can clear at any time.")
                    bullet("xmark.shield", "MacCare is not an antivirus replacement and never claims otherwise.")
                }
                .frame(maxWidth: 420)
            }
        case 2:
            page {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.storage)
                Text("Full Disk Access — optional").font(MCFont.heroTitle)
                Text("Without it, some folders (Mail, Safari data…) can't be scanned. The app works either way. You can grant or revoke it any time in System Settings.")
                    .font(MCFont.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                HStack(spacing: MCSpacing.sm) {
                    MCStatusBadge(fdaGranted ? "Granted" : "Not granted",
                                  status: fdaGranted ? .success : .neutral)
                    if !fdaGranted {
                        Button("Open System Settings") { PermissionProbe.openFullDiskAccessSettings() }
                        Button("Re-check") { fdaGranted = PermissionProbe.hasFullDiskAccess() }
                    }
                }
            }
        default:
            page {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(MCColor.success)
                Text("Reversible by design").font(MCFont.heroTitle)
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    bullet("magnifyingglass", "Scans never delete anything. Cleaning is a separate, reviewed step.")
                    bullet("trash", "Removal uses the system Trash — you can always restore.")
                    bullet("hand.raised", "Dry-run is on by default: actions are simulated until you turn it off.")
                }
                .frame(maxWidth: 420)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip") { finish() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            // Step indicator: position + text, not color alone.
            Text("\(step + 1) of \(stepCount)")
                .font(MCFont.caption).foregroundStyle(.secondary)
                .accessibilityLabel("Step \(step + 1) of \(stepCount)")
            Spacer()
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            Button(step == stepCount - 1 ? "Get Started" : "Continue") {
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
