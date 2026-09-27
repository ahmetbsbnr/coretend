import SwiftUI
import AppShell
import DesignSystem
import Observation

@main
struct CoreTendApp: App {
    @State private var navigation: CoreTendNavigation
    @State private var menuBarEnabled: Bool

    init() {
        let preferences = CoreTendPreferences()
        _navigation = State(initialValue: CoreTendNavigation(language: preferences.resolvedLanguage(storedValue: nil)))
        _menuBarEnabled = State(initialValue: preferences.menuBarEnabled)
    }

    var body: some Scene {
        Window("CoreTend", id: "coretend.main") {
            CoreTendRootView(navigation: navigation, menuBarEnabled: $menuBarEnabled)
                .frame(minWidth: 920, minHeight: 620)
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
        } label: {
            Image(systemName: "externaldrive")
                .accessibilityLabel("CoreTend")
        }
        .menuBarExtraStyle(.window)
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
    @State private var onboardingCompleted: Bool
    @State private var recentFilesEnabled: Bool
    private var french: Bool { language == "fr" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("fr") == true) }

    init(navigation: CoreTendNavigation, menuBarEnabled: Binding<Bool>) {
        let preferences = CoreTendPreferences()
        self.preferences = preferences
        self.navigation = navigation
        _menuBarEnabled = menuBarEnabled
        _language = State(initialValue: preferences.resolvedLanguage(storedValue: nil))
        _onboardingCompleted = State(initialValue: preferences.onboardingCompleted)
        _recentFilesEnabled = State(initialValue: preferences.recentFilesEnabled)
    }

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $navigation.selection) { destination in
                NavigationLink(value: destination) {
                    Label(ProductCopy.value(for: destination.titleKey, french: french), systemImage: destination.symbol)
                }
            }
            .navigationTitle("CoreTend")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            ZStack {
                if let selection = navigation.selection {
                    DestinationView(destination: selection, french: french, recentFilesEnabled: $recentFilesEnabled)
                        .id(selection)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                } else {
                    ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french), systemImage: "square.grid.2x2")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.canvas.color)
            .motion(.standard, value: navigation.selection)
        }
        .tint(Palette.accent.color)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { navigation.activeSheet = .commands } label: { Image(systemName: "command") }
                    .keyboardShortcut("k", modifiers: [.command])
                    .accessibilityLabel(ProductCopy.value(for: "command.palette.title", french: french))
                    .help(french ? "Accéder à… (⌘K)" : "Go to or open… (⌘K)")
            }
            ToolbarItem(placement: .automatic) {
                Button { navigation.activeSheet = .settings } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(ProductCopy.value(for: "settings.title", french: french))
            }
        }
        .sheet(item: $navigation.activeSheet) { sheet in
            switch sheet {
            case .settings: SettingsView(french: french, language: $language, recentFilesEnabled: $recentFilesEnabled, menuBarEnabled: $menuBarEnabled) {
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
        .onChange(of: navigation.selection) { _, destination in
            if let destination { preferences.saveLastDestination(destination.rawValue) }
        }
        .onChange(of: language) { _, value in preferences.saveLanguage(value); navigation.language = value }
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
                .font(.headline)
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
    }
}

private struct OnboardingView: View {
    let french: Bool
    let finish: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "lock.shield").font(.system(size: 36)).foregroundStyle(.tint)
            Text(ProductCopy.value(for: "onboarding.title", french: french)).font(.largeTitle.bold())
            Text(ProductCopy.value(for: "onboarding.scope", french: french))
                .font(.body).fixedSize(horizontal: false, vertical: true)
            Text(ProductCopy.value(for: "onboarding.privacy", french: french))
                .font(.callout).foregroundStyle(.secondary)
            HStack { Spacer(); Button(ProductCopy.value(for: "onboarding.start", french: french), action: finish).keyboardShortcut(.defaultAction) }
        }
        .padding(32).frame(width: 520)
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
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if destination == .overview {
                    Text(ProductCopy.value(for: "overview.summary", french: french)).font(.title3)
                }
                if destination == .overview || destination == .performance {
                    SystemSnapshotView(destination: destination, french: french)
                } else if destination != .record {
                    Label(ProductCopy.value(for: "safety.notice", french: french), systemImage: "lock.shield")
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
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
