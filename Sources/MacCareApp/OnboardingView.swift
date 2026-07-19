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

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var fdaGranted = PermissionProbe.hasFullDiskAccess()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 40)).foregroundStyle(MCTheme.accent)
                Text("Welcome to MacCare Local").font(.title.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 12) {
                bullet("magnifyingglass", "Scans never delete anything. Cleaning is always a separate, reviewed step.")
                bullet("trash", "Removal uses the system Trash — you can always restore.")
                bullet("lock.shield", "Everything stays on this Mac. No accounts, no telemetry, no network calls.")
                bullet("hand.raised", "Dry-run mode is on by default: actions are simulated until you turn it off.")
                bullet("xmark.shield", "MacCare is not an antivirus replacement and never claims otherwise.")
            }
            MCCard {
                HStack {
                    Image(systemName: fdaGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(fdaGranted ? MCTheme.success : MCTheme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access").font(.headline)
                        Text(fdaGranted
                             ? "Granted — all cleanup categories are available."
                             : "Not granted. Some folders (Mail, Safari data…) can't be scanned. You can grant it in System Settings, then click Re-check.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !fdaGranted {
                        Button("Open Settings") { PermissionProbe.openFullDiskAccessSettings() }
                        Button("Re-check") { fdaGranted = PermissionProbe.hasFullDiskAccess() }
                    }
                }
            }
            Text("To uninstall completely: quit the app, delete it from Applications, and remove ~/Library/Application Support/MacCareLocal. Details in Settings.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Get Started") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(MCTheme.accent)
            Text(text)
        }
    }
}
