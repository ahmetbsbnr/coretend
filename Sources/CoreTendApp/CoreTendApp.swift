import SwiftUI
import AppKit
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
                .onAppear {
                    // Fixture-only (store captures): the window at an exact size in points.
                    guard let size = CoreTendPreferences().fixtureWindowSize else { return }
                    DispatchQueue.main.async {
                        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else { return }
                        window.setContentSize(NSSize(width: size.width, height: size.height))
                        window.center()
                    }
                }
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
            Image(nsImage: MenuBarGlyph.image)
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
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.scenePhase) private var scenePhase
    /// Decision 0003: "Living greenhouse", on by default.
    @AppStorage("coretend.livingGreenhouse") private var livingGreenhouse = true
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
            .background(LivingBackdrop())
            // Every button in the content is a Serre button unless it says otherwise.
            .buttonStyle(.serre(.secondary))
        }
        .onPreferenceChange(SidebarRowFrames.self) { rowFrames = $0 }
        // Views such as the Overview's shortcuts change destination through the navigation.
        .environment(navigation)
        // Ambient motion only while this window is active and in front (decision 0003).
        .environment(\.serreAmbientAllowed, livingGreenhouse && controlActiveState == .key && scenePhase == .active)
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
        .onChange(of: appearance) { _, value in
            preferences.saveAppearance(value)
            applyAppearance(value)
        }
        .onAppear { applyAppearance(appearance) }
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
            HStack(spacing: 10) {
                SerreLogo(size: 26, germinates: false).ambientSway(degrees: 5)
                Text("CoreTend").font(.custom("IowanOldStyle-Bold", size: 18, relativeTo: .title3)).foregroundStyle(Palette.ink.color)
            }
            MenuBarMetricsView(french: french)
            Palette.separator.color.frame(height: 1)
            Text(ProductCopy.value(for: "menubar.open", french: french))
                .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
            VStack(spacing: 2) {
                ForEach(Destination.sidebarOrder) { destination in
                    Button {
                        navigation.selection = destination
                        navigation.activeSheet = nil
                        openWindow(id: "coretend.main")
                    } label: {
                        Label { Text(ProductCopy.value(for: destination.titleKey, french: french)) } icon: {
                            SerreIcon(destination.glyph, size: 15).foregroundStyle(Palette.accent.color)
                                .ambientSway(degrees: 4, phase: Double(destination.shortcutNumber) * 0.61)
                        }
                        .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.serre(.row(selected: false)))
                }
            }
            Palette.separator.color.frame(height: 1)
            Button {
                navigation.activeSheet = .settings
                openWindow(id: "coretend.main")
            } label: {
                Label { Text(ProductCopy.value(for: "settings.title", french: french)) } icon: { SerreIcon(.settings, size: 15) }
                    .font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.serre(.row(selected: false)))
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .tint(Palette.accent.color)
        .background(LivingBackdrop())
        // The menu is only on screen while it is open: it lives while it is seen.
        .environment(\.serreAmbientAllowed, true)
    }
}

/// The welcome, in three pages of the greenhouse: what CoreTend is, how it works, what it will
/// never do. The scene lives here too (the sheet is the active window).
private struct OnboardingView: View {
    let french: Bool
    let finish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                switch page {
                case 0: welcome.transition(pageTransition)
                case 1: how.transition(pageTransition)
                default: never.transition(pageTransition)
                }
            }
            .frame(minHeight: 380, alignment: .top)
            HStack(spacing: 10) {
                // One leaf per page; the current one is open.
                ForEach(0..<3, id: \.self) { index in
                    RiskLeafShape(level: .low)
                        .fill(index == page ? Palette.accent.color : Palette.strongSeparator.color)
                        .frame(width: index == page ? 14 : 10, height: index == page ? 14 : 10)
                }
                Spacer()
                if page > 0 {
                    Button(ProductCopy.value(for: "onboarding.back", french: french)) { go(page - 1) }
                        .buttonStyle(.serre(.secondary))
                }
                if page < 2 {
                    Button(ProductCopy.value(for: "onboarding.next", french: french)) { go(page + 1) }
                        .keyboardShortcut(.defaultAction).buttonStyle(.serre(.primary))
                } else {
                    Button(ProductCopy.value(for: "onboarding.start", french: french), action: finish)
                        .keyboardShortcut(.defaultAction).buttonStyle(.serre(.primary))
                }
            }
        }
        .padding(32).frame(width: 620)
        .background(LivingBackdrop())
        .environment(\.serreAmbientAllowed, true)
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                              removal: .move(edge: .leading).combined(with: .opacity))
    }

    private func go(_ next: Int) {
        withAnimation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.grow.duration)) { page = next }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                SerreLogo(size: 64, germinates: true).ambientSway(degrees: 5)
                Text(ProductCopy.value(for: "onboarding.title", french: french)).font(CoreTendTypography.pageTitle)
                    .foregroundStyle(Palette.ink.color)
            }
            Text(ProductCopy.value(for: "onboarding.lede", french: french))
                .font(CoreTendTypography.lede).foregroundStyle(Palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
            GreenhouseScene(state: GreenhouseState(freeFraction: 0.75, lastActionFailed: false, recentlyPruned: false))
            Text(ProductCopy.value(for: "onboarding.scope", french: french))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var how: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ProductCopy.value(for: "onboarding.how", french: french)).font(CoreTendTypography.pageTitle)
                .foregroundStyle(Palette.ink.color)
            ForEach(Array([(SerreGlyph.explore, 1), (.search, 2), (.cleanup, 3)].enumerated()), id: \.offset) { order, item in
                HStack(alignment: .center, spacing: 16) {
                    DestinationPlant(item.0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ProductCopy.value(for: "onboarding.step\(item.1).title", french: french))
                            .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                        Text(ProductCopy.value(for: "onboarding.step\(item.1).body", french: french))
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .serreRise(order)
            }
        }
    }

    private var never: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ProductCopy.value(for: "onboarding.never.title", french: french)).font(CoreTendTypography.pageTitle)
                .foregroundStyle(Palette.ink.color)
            ForEach(1...3, id: \.self) { index in
                SerreSignalTag(.good, title: ProductCopy.value(for: "onboarding.never\(index)", french: french), order: index)
            }
            Text(ProductCopy.value(for: "onboarding.privacy", french: french))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DestinationView: View {
    let destination: Destination
    let french: Bool
    @Binding var recentFilesEnabled: Bool
    /// What the page's content is doing, for its plant (a scan running, a scan done).
    @State private var plantActivity = PlantActivity.resting

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Each page opens with a vine growing across its top (caused by navigation).
                VineSweep().padding(.bottom, -12)
                HStack(alignment: .bottom, spacing: 20) {
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
                    Spacer(minLength: 12)
                    // Each destination has its plant; it grows on arrival and lives while the window does.
                    DestinationPlant(destination.glyph, activity: plantActivity).id(destination)
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
            .frame(maxWidth: 1280, alignment: .leading)
            // The whole width scrolls, not only the reading column.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onPreferenceChange(PlantActivityKey.self) { plantActivity = $0 }
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

/// The menu bar icon: the Serre sprout, drawn once as a template image so macOS tints it like any
/// other menu bar item.
@MainActor
enum MenuBarGlyph {
    static let image: NSImage = {
        let renderer = ImageRenderer(content: MenuBarSprout())
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "leaf", accessibilityDescription: "CoreTend") ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

private struct MenuBarSprout: View {
    var body: some View {
        SerreGlyphShape(glyph: .overview)
            .stroke(Palette.ink.color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .padding(1)
    }
}

/// Serre colours resolve against the window's appearance, not SwiftUI's colour scheme, so the
/// chosen appearance is set on the whole app: every window, the menu bar extra included.
@MainActor
func applyAppearance(_ preference: AppearancePreference) {
    switch preference {
    case .system: NSApp.appearance = nil
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
