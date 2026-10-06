import AppKit
import DesignSystem
import SwiftUI
import ScanCore
import AppShell
import Domain

/// The Home: one sentence about the Mac, the space CoreTend can give back with the button that
/// does it, Full Disk Access when it is missing, then the disk and the other spaces.
struct HomeView: View {
    let french: Bool
    @Environment(CoreTendNavigation.self) private var navigation
    @State private var access = FullDiskAccessStatus.unknown
    @State private var surveying = false
    @State private var showPerformance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if access == .denied { accessCard }
            recoverable
            SystemSnapshotView(destination: .overview, french: french)
            HStack {
                Spacer()
                Button(copy("home.performance")) { showPerformance = true }
                    .buttonStyle(.serre(.secondary))
            }
        }
        .task {
            refreshAccess()
            if navigation.cleanupReport == nil { await survey() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refreshAccess() }
        .sheet(isPresented: $showPerformance) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(copy("performance.title")).font(CoreTendTypography.pageTitle).foregroundStyle(Palette.ink.color)
                    Spacer()
                    Button(copy("common.close")) { showPerformance = false }.keyboardShortcut(.cancelAction)
                }
                ScrollView { SystemSnapshotView(destination: .performance, french: french) }
            }
            .padding(28).frame(width: 760, height: 640)
            .background(LivingBackdrop())
            .environment(navigation)
            .tint(Palette.accent.color).buttonStyle(.serre(.secondary))
        }
    }

    /// Full Disk Access, asked once and explained in one sentence.
    private var accessCard: some View {
        SerreBanner(.partial, title: copy("access.title"), message: copy("access.message")) {
            HStack(spacing: 8) {
                Button(copy("access.open")) { NSWorkspace.shared.open(FullDiskAccessProbe.settingsURL) }
                    .buttonStyle(.serre(.primary))
                Text(copy("access.hint")).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            }
            .padding(.top, 6)
        }
    }

    /// The figure first, and the one button that leads to it.
    private var recoverable: some View {
        SerreParcel {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    if let report = navigation.cleanupReport {
                        Text(ProductFormat.bytes(report.bytes, french: french))
                            .font(CoreTendTypography.hero).foregroundStyle(Palette.ink.color)
                            .contentTransition(.numericText())
                        Text(copy(report.bytes > 0 ? "home.recoverable" : "home.recoverable.none"))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                    } else {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(copy("clean.reading")).font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
                        }
                    }
                }
                Spacer(minLength: 12)
                Button { navigation.selection = .clean } label: { Text(copy("home.review")) }
                    .buttonStyle(.serre(.primary))
                    .disabled(navigation.cleanupReport == nil || navigation.cleanupReport?.bytes == 0)
            }
        }
    }

    private func refreshAccess() { access = FullDiskAccessProbe(home: HomeFolder.url).status() }

    @MainActor private func survey() async {
        guard !surveying else { return }
        surveying = true
        defer { surveying = false }
        let home = HomeFolder.url
        let exclusions = (try? await LocalStoreAccess.exclusions()) ?? []
        if let found = try? await Task.detached(priority: .userInitiated, operation: { try await CleanupSurvey(home: home).run(exclusions: exclusions) }).value {
            navigation.cleanupReport = found
            navigation.cleanupReportDate = .now
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
