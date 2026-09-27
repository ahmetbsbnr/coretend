import SwiftUI
import AppShell

@main
struct CoreTendApp: App {
    var body: some Scene {
        WindowGroup {
            CoreTendRootView()
                .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)
    }
}

private struct CoreTendRootView: View {
    private let preferences: CoreTendPreferences
    @State private var selection: Destination?
    @State private var activeSheet: RootSheet?
    @State private var language: String
    @State private var onboardingCompleted: Bool
    @State private var recentFilesEnabled: Bool
    private var french: Bool { language == "fr" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("fr") == true) }

    init() {
        let preferences = CoreTendPreferences()
        self.preferences = preferences
        _selection = State(initialValue: Destination.restored(from: preferences.lastDestination))
        _language = State(initialValue: preferences.resolvedLanguage(storedValue: nil))
        _onboardingCompleted = State(initialValue: preferences.onboardingCompleted)
        _recentFilesEnabled = State(initialValue: preferences.recentFilesEnabled)
    }

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                NavigationLink(value: destination) {
                    Label(ProductCopy.value(for: destination.titleKey, french: french), systemImage: destination.symbol)
                }
            }
            .navigationTitle("CoreTend")
            .listStyle(.sidebar)
        } detail: {
            if let selection {
                DestinationView(destination: selection, french: french, recentFilesEnabled: $recentFilesEnabled)
            } else {
                ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french), systemImage: "square.grid.2x2")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { activeSheet = .commands } label: { Image(systemName: "command") }
                    .keyboardShortcut("k", modifiers: [.command])
                    .accessibilityLabel(ProductCopy.value(for: "command.palette.title", french: french))
                    .help(french ? "Accéder à… (⌘K)" : "Go to or open… (⌘K)")
            }
            ToolbarItem(placement: .automatic) {
                Button { activeSheet = .settings } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(ProductCopy.value(for: "settings.title", french: french))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: SettingsView(french: french, language: $language, recentFilesEnabled: $recentFilesEnabled)
            case .commands:
                CommandPaletteView(french: french) { target in
                    switch target {
                    case .destination(let destination): selection = destination; activeSheet = nil
                    case .settings: activeSheet = .settings
                    }
                }
            case .onboarding: OnboardingView(french: french) { onboardingCompleted = true; activeSheet = nil }
            }
        }
        .onChange(of: selection) { _, destination in
            if let destination { preferences.saveLastDestination(destination.rawValue) }
        }
        .onChange(of: language) { _, value in preferences.saveLanguage(value) }
        .onChange(of: onboardingCompleted) { _, value in preferences.saveOnboardingCompleted(value) }
        .onChange(of: recentFilesEnabled) { _, value in preferences.saveRecentFilesEnabled(value) }
        .task {
            if let store = try? await LocalStoreAccess.open(), preferences.usesPersistentStorage,
               let saved = try? await store.languagePreference() {
                language = preferences.resolvedLanguage(storedValue: saved)
            }
            if !onboardingCompleted { activeSheet = .onboarding }
        }
    }
}

private enum RootSheet: String, Identifiable { case settings, commands, onboarding; var id: String { rawValue } }

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
