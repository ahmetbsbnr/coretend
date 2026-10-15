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
    @State private var snapshot: SystemSnapshot?
    /// The hero figure, counted up from zero to the measured value.
    @State private var shownBytes: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if access == .denied { accessCard }
            hero.cascade(0)
            SystemSnapshotView(destination: .overview, french: french)
            HStack {
                Spacer()
                Button(copy("home.performance")) { showPerformance = true }
                    .buttonStyle(.serre(.secondary))
            }
        }
        .task {
            refreshAccess()
            snapshot = await Task.detached(priority: .userInitiated) { MacOSSystemSnapshotReader().read() }.value
            if navigation.cleanupReport == nil { await survey() } else { countUp() }
        }
        .onChange(of: navigation.cleanupReport?.bytes) { _, _ in countUp() }
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

    /// The greenhouse in full: it grows with the free space and carries a glowing seed for each
    /// share that can be given back; the figure counts up to what the last read measured.
    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack(alignment: .bottomLeading) {
            ImmersiveGreenhouse(freeFraction: freeFraction, recoverableFraction: recoverableFraction)
            LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    if let report = navigation.cleanupReport {
                        CountingText(value: shownBytes) { [french] value in ProductFormat.bytes(Int64(value), french: french) }
                            .font(.custom("IowanOldStyle-Bold", size: 76, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                        Text(copy(report.bytes > 0 ? "home.recoverable" : "home.recoverable.none"))
                            .font(.custom("AvenirNext-Medium", size: 17, relativeTo: .title3))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    } else {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small).tint(.white)
                            Text(copy("clean.reading")).font(CoreTendTypography.lede).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                Spacer(minLength: 12)
                Button { navigation.selection = .clean } label: {
                    HStack(spacing: 8) { Text(copy("home.review")); Image(systemName: "arrow.right") }
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(navigation.cleanupReport == nil || navigation.cleanupReport?.bytes == 0)
            }
            .padding(28)
            VStack {
                HStack(spacing: 8) {
                    Spacer()
                    if let snapshot, case .known(let free) = snapshot.availableBytes {
                        chip(ProductCopy.inline("%1$@ libres", "%1$@ free", french: french, ProductFormat.bytes(free, french: french)))
                    }
                    if let snapshot, case .known(let purgeable) = snapshot.purgeableBytes, purgeable > 0 {
                        chip(ProductCopy.inline("+ %1$@ purgeables", "+ %1$@ purgeable", french: french, ProductFormat.bytes(purgeable, french: french)))
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .frame(height: 380)
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: Palette.accent.color.opacity(0.25), radius: 30, y: 16)
        .accessibilityElement(children: .contain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(CoreTendTypography.secondary.weight(.semibold).monospacedDigit())
            .foregroundStyle(Palette.ink.color)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
    }

    private var freeFraction: Double? {
        guard let snapshot, case .known(let free) = snapshot.availableBytes, case .known(let total) = snapshot.totalBytes, total > 0 else { return nil }
        return Double(free) / Double(total)
    }

    private var recoverableFraction: Double? {
        guard let report = navigation.cleanupReport, let snapshot, case .known(let total) = snapshot.totalBytes, total > 0 else { return nil }
        return Double(report.bytes) / Double(total)
    }

    private func countUp() {
        guard let bytes = navigation.cleanupReport?.bytes else { return }
        shownBytes = 0
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.8).delay(0.3)) { shownBytes = Double(bytes) }
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
            countUp()
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
