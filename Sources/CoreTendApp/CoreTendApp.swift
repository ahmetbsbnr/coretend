import SwiftUI
import AppShell
import DesignSystem
import Observation

@main
struct CoreTendApp: App {
    @State private var navigation: CoreTendNavigation
    @State private var menuBarEnabled: Bool
    @State private var appearance: AppearancePreference

    private var effectiveColorScheme: ColorScheme? {
        let preferences = CoreTendPreferences()
        if let fixture = preferences.fixtureAppearance { return fixture == .dark ? .dark : .light }
        return appearance.colorScheme
    }

    init() {
        let preferences = CoreTendPreferences()
        _navigation = State(initialValue: CoreTendNavigation(language: preferences.resolvedLanguage(storedValue: nil)))
        _menuBarEnabled = State(initialValue: preferences.menuBarEnabled)
        _appearance = State(initialValue: preferences.appearance)
    }

    var body: some Scene {
        Window("CoreTend", id: "coretend.main") {
            CoreTendRootView(navigation: navigation, menuBarEnabled: $menuBarEnabled, appearance: $appearance)
                .frame(minWidth: 640, minHeight: 520)
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(ProductCopy.value(for: "settings.title", french: navigation.usesFrench) + "…") {
                    navigation.activeSheet = .settings
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            CoreTendMenuBar(navigation: navigation)
                .preferredColorScheme(effectiveColorScheme)
        } label: {
            Image(systemName: "externaldrive")
                .accessibilityLabel("CoreTend")
        }
        .menuBarExtraStyle(.window)
    }
}

private extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor @Observable
final class CoreTendNavigation {
    var selection: Destination?
    var activeSheet: RootSheet?
    /// The command palette, drawn over the window (not a sheet: a click outside closes it).
    var searchOpen = false
    var language: String

    init(language: String) {
        self.language = language
        selection = Destination.restored(from: CoreTendPreferences().lastDestination)
    }

    var usesFrench: Bool {
        language == "fr" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("fr") == true)
    }
}

private struct CoreTendRootView: View {
    private let preferences: CoreTendPreferences
    @Bindable private var navigation: CoreTendNavigation
    @Binding private var menuBarEnabled: Bool
    @State private var language: String
    @Binding private var appearance: AppearancePreference
    @State private var onboardingCompleted: Bool
    @State private var recentFilesEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rowFrames: [Destination: CGRect] = [:]
    @Namespace private var searchSpace
    private var french: Bool { language == "fr" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("fr") == true) }

    private var effectiveColorScheme: ColorScheme? {
        if let fixture = preferences.fixtureAppearance { return fixture == .dark ? .dark : .light }
        return appearance.colorScheme
    }

    init(navigation: CoreTendNavigation, menuBarEnabled: Binding<Bool>, appearance: Binding<AppearancePreference>) {
        let preferences = CoreTendPreferences()
        self.preferences = preferences
        self.navigation = navigation
        _menuBarEnabled = menuBarEnabled
        _appearance = appearance
        _language = State(initialValue: preferences.resolvedLanguage(storedValue: nil))
        _onboardingCompleted = State(initialValue: preferences.onboardingCompleted)
        _recentFilesEnabled = State(initialValue: preferences.recentFilesEnabled)
    }

    var body: some View {
        NavigationSplitView {
            SerreSidebar(selection: $navigation.selection, french: french, searchNamespace: searchSpace,
                         openSearch: toggleSearch,
                         openSettings: { navigation.activeSheet = .settings })
                .navigationSplitViewColumnWidth(min: 200, ideal: 232)
                .navigationTitle("CoreTend")
        } detail: {
            GeometryReader { detail in
            ZStack {
                if let selection = navigation.selection {
                    DestinationView(destination: selection, french: french, recentFilesEnabled: $recentFilesEnabled)
                        .id(selection)
                        // The view grows from the height of the sidebar row that was chosen.
                        .transition(.grow(from: growOrigin(for: selection, in: detail.frame(in: .global)), reduceMotion: reduceMotion))
                } else {
                    ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french), systemImage: "square.grid.2x2")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Palette.canvas.color)
            // Every button in the content is a Serre button unless it says otherwise.
            .buttonStyle(.serre(.secondary))
        }
        .onPreferenceChange(SidebarRowFrames.self) { rowFrames = $0 }
        // Views such as the Overview's shortcuts change destination through the navigation.
        .environment(navigation)
        .tint(Palette.accent.color)
        .preferredColorScheme(effectiveColorScheme)
        .toolbarBackground(Palette.canvas.color, for: .windowToolbar)
        .modifier(HiddenWindowTitle())
        .overlay {
            if navigation.searchOpen {
                SearchLayer(french: french, namespace: searchSpace, select: { target in
                    switch target {
                    case .destination(let destination): navigation.selection = destination
                    case .settings: navigation.activeSheet = .settings
                    }
                }, close: closeSearch)
                .transition(.opacity.animation(MotionCurve.retreat.animation(duration: reduceMotion ? 0.01 : 0.18)))
            }
        }
        .sheet(item: $navigation.activeSheet) { sheet in
            // Sheets are separate presentations and do not inherit the window's tint.
            sheetContent(sheet).tint(Palette.accent.color).buttonStyle(.serre(.secondary))
        }
        .onChange(of: navigation.selection) { _, destination in
            if let destination { preferences.saveLastDestination(destination.rawValue) }
        }
        .onChange(of: language) { _, value in preferences.saveLanguage(value); navigation.language = value }
        .onChange(of: appearance) { _, value in preferences.saveAppearance(value) }
        .onChange(of: onboardingCompleted) { _, value in preferences.saveOnboardingCompleted(value) }
        .onChange(of: recentFilesEnabled) { _, value in preferences.saveRecentFilesEnabled(value) }
        .onChange(of: menuBarEnabled) { _, value in preferences.saveMenuBarEnabled(value) }
        .task {
            if let store = try? await LocalStoreAccess.open(), preferences.usesPersistentStorage,
               let saved = try? await store.languagePreference() {
                language = preferences.resolvedLanguage(storedValue: saved)
            }
            if !onboardingCompleted { navigation.activeSheet = .onboarding }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: RootSheet) -> some View {
        switch sheet {
        case .settings: SettingsView(french: french, language: $language, appearance: $appearance, recentFilesEnabled: $recentFilesEnabled, menuBarEnabled: $menuBarEnabled) {
            navigation.activeSheet = nil
        }
        case .onboarding: OnboardingView(french: french) { onboardingCompleted = true; navigation.activeSheet = nil }
        }
    }

    private func toggleSearch() {
        if navigation.searchOpen { closeSearch() } else { navigation.searchOpen = true }
    }

    private func closeSearch() {
        withAnimation(MotionCurve.retreat.animation(duration: reduceMotion ? 0.01 : 0.18)) { navigation.searchOpen = false }
    }

    /// The point, in the content, level with the chosen sidebar row; the leading edge if unknown.
    private func growOrigin(for destination: Destination, in detail: CGRect) -> CGPoint {
        guard let row = rowFrames[destination], row != .zero else { return CGPoint(x: 0, y: 0) }
        return CGPoint(x: 0, y: min(max(row.midY - detail.minY, 0), detail.height))
    }
}

/// The sidebar shows the name beside the logo, so the title bar does not repeat it (macOS 15 and
/// later; macOS 14 keeps the title). The window keeps its title for the system either way.
private struct HiddenWindowTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) { content.toolbar(removing: .title) } else { content }
    }
}

enum RootSheet: String, Identifiable { case settings, onboarding; var id: String { rawValue } }

private struct CoreTendMenuBar: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var navigation: CoreTendNavigation

    private var french: Bool { navigation.usesFrench }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MenuBarMetricsView(french: french)
            Divider()
            Text(ProductCopy.value(for: "menubar.open", french: french))
                .font(CoreTendTypography.sectionTitle)
            ForEach(Destination.allCases) { destination in
                Button(ProductCopy.value(for: destination.titleKey, french: french)) {
                    navigation.selection = destination
                    navigation.activeSheet = nil
                    openWindow(id: "coretend.main")
                }
            }
            Divider()
            Button(ProductCopy.value(for: "settings.title", french: french)) {
                navigation.activeSheet = .settings
                openWindow(id: "coretend.main")
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .tint(Palette.accent.color)
        .background(Palette.surface.color)
    }
}

private struct OnboardingView: View {
    let french: Bool
    let finish: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SerreLogo(size: 64, germinates: true)
            Text(ProductCopy.value(for: "onboarding.title", french: french)).font(CoreTendTypography.pageTitle)
            Text(ProductCopy.value(for: "onboarding.scope", french: french))
                .font(CoreTendTypography.body).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(1...3, id: \.self) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step)")
                            .font(.custom("IowanOldStyle-Bold", size: 16, relativeTo: .headline))
                            .foregroundStyle(Palette.onAccent.color)
                            .frame(width: 28, height: 28)
                            .background(Palette.accent.color, in: LeafCorner.control.shape)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ProductCopy.value(for: "onboarding.step\(step).title", french: french))
                                .font(CoreTendTypography.body.weight(.semibold))
                            Text(ProductCopy.value(for: "onboarding.step\(step).body", french: french))
                                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .serreRise(step + 2)
                }
            }
            Text(ProductCopy.value(for: "onboarding.privacy", french: french))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            HStack { Spacer(); Button(ProductCopy.value(for: "onboarding.start", french: french), action: finish).keyboardShortcut(.defaultAction).buttonStyle(.serre(.primary)) }
        }
        .padding(32).frame(width: 520)
        .background(Palette.surface.color)
    }
}

private struct DestinationView: View {
    let destination: Destination
    let french: Bool
    @Binding var recentFilesEnabled: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ProductCopy.value(for: destination.titleKey, french: french))
                        .font(CoreTendTypography.pageTitle)
                        .foregroundStyle(Palette.ink.color)
                        .accessibilityAddTraits(.isHeader)
                    Text(ProductCopy.value(for: destination.ledeKey, french: french))
                        .font(CoreTendTypography.lede)
                        .foregroundStyle(Palette.secondaryInk.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .serreRise(0)
                if destination == .overview || destination == .performance {
                    SystemSnapshotView(destination: destination, french: french)
                } else if destination != .record {
                    SerreBanner(.note, title: ProductCopy.value(for: "safety.notice", french: french))
                        .serreRise(1)
                }
                destinationContent
                    .serreRise(destination == .overview ? 6 : 2)
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .accessibilityIdentifier("destination-\(destination.rawValue)")
    }

    @ViewBuilder private var destinationContent: some View {
        switch destination.route {
        case .overview: SavedFilesView(french: french)
        case .record: RecordView(french: french)
        case .cleanup: CleanupView(french: french)
        case .explore: ExploreScanView(french: french, recentFilesEnabled: $recentFilesEnabled)
        case .duplicates: DuplicateScanView(french: french)
        case .applications: ApplicationsView(french: french)
        case .integrity: IntegrityView(french: french)
        case .performance: EmptyView()
        }
    }
}
