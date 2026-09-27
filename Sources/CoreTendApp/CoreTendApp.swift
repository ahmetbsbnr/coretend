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
            List(selection: $navigation.selection) {
                Section(ProductCopy.value(for: Destination.overview.sectionTitleKey, french: french)) {
                    ForEach([Destination.overview, .explore, .cleanup, .duplicates]) { destination in
                        destinationLink(destination)
                    }
                }
                Section(ProductCopy.value(for: Destination.applications.sectionTitleKey, french: french)) {
                    ForEach([Destination.applications, .integrity, .performance, .record]) { destination in
                        destinationLink(destination)
                    }
                }
            }
            .navigationTitle("CoreTend")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                Button { navigation.activeSheet = .settings } label: {
                    Label { Text(ProductCopy.value(for: "settings.title", french: french)) } icon: { SerreIcon(.settings) }
                        .font(CoreTendTypography.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.serre(.row(selected: false)))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Palette.surface.color)
                .overlay(alignment: .top) { Palette.separator.color.frame(height: 1) }
                .accessibilityLabel(ProductCopy.value(for: "settings.title", french: french))
            }
        } detail: {
            ZStack {
                if let selection = navigation.selection {
                    DestinationView(destination: selection, french: french, recentFilesEnabled: $recentFilesEnabled)
                        .id(selection)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 8)))
                } else {
                    ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french), systemImage: "square.grid.2x2")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.canvas.color)
            // Every button in the content is a Serre button unless it says otherwise.
            .buttonStyle(.serre(.secondary))
            .motion(.standard, value: navigation.selection)
        }
        .tint(Palette.accent.color)
        .preferredColorScheme(effectiveColorScheme)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { navigation.activeSheet = .commands } label: { SerreIcon(.search) }
                    .keyboardShortcut("k", modifiers: [.command])
                    .accessibilityLabel(ProductCopy.value(for: "command.palette.title", french: french))
                    .help(french ? "Accéder à… (⌘K)" : "Go to or open… (⌘K)")
            }
            ToolbarItem(placement: .automatic) {
                Button { navigation.activeSheet = .settings } label: { SerreIcon(.settings) }
                    .accessibilityLabel(ProductCopy.value(for: "settings.title", french: french))
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
        case .commands:
            CommandPaletteView(french: french) { target in
                switch target {
                case .destination(let destination): navigation.selection = destination; navigation.activeSheet = nil
                case .settings: navigation.activeSheet = .settings
                }
            }
        case .onboarding: OnboardingView(french: french) { onboardingCompleted = true; navigation.activeSheet = nil }
        }
    }

    private func destinationLink(_ destination: Destination) -> some View {
        let title = ProductCopy.value(for: destination.titleKey, french: french)
        return NavigationLink(value: destination) {
            Label { Text(title) } icon: { SerreIcon(destination.glyph) }
                .font(CoreTendTypography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.leading, 8)
                .background(navigation.selection == destination ? Palette.accent.color.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) {
                    if navigation.selection == destination {
                        Capsule().fill(Palette.focus.color).frame(width: 3).padding(.vertical, 4)
                    }
                }
        }
    }
}

enum RootSheet: String, Identifiable { case settings, commands, onboarding; var id: String { rawValue } }

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
                Text(ProductCopy.value(for: destination.titleKey, french: french))
                    .font(CoreTendTypography.pageTitle)
                    .accessibilityAddTraits(.isHeader)
                if destination == .overview {
                    Text(ProductCopy.value(for: "overview.summary", french: french)).font(CoreTendTypography.sectionTitle)
                }
                if destination == .overview || destination == .performance {
                    SystemSnapshotView(destination: destination, french: french)
                } else if destination != .record {
                    Label(ProductCopy.value(for: "safety.notice", french: french), systemImage: "lock.shield")
                        .font(CoreTendTypography.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 14))
                }
                destinationContent
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
