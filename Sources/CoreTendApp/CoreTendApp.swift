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
    @State private var selection: Destination? = Destination(rawValue: UserDefaults.standard.string(forKey: "coretend.lastDestination") ?? "") ?? .overview
    @State private var activeSheet: RootSheet?
    @AppStorage("coretend.language") private var language = "system"
    @AppStorage("coretend.onboarding.completed") private var onboardingCompleted = false
    private var french: Bool { language == "fr" || (language == "system" && Locale.preferredLanguages.first?.hasPrefix("fr") == true) }

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
                DestinationView(destination: selection, french: french)
            } else {
                ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french), systemImage: "square.grid.2x2")
            }
        }
        .toolbar { ToolbarItem(placement: .automatic) { Button { activeSheet = .settings } label: { Image(systemName: "gearshape") }.accessibilityLabel(ProductCopy.value(for: "settings.title", french: french)) } }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings: SettingsView(french: french, language: $language)
            case .onboarding: OnboardingView(french: french) { onboardingCompleted = true; activeSheet = nil }
            }
        }
        .onChange(of: selection) { _, destination in
            if let destination { UserDefaults.standard.set(destination.rawValue, forKey: "coretend.lastDestination") }
        }
        .task {
            if let store = try? await LocalStoreAccess.open(), let saved = try? await store.languagePreference() { language = saved }
            if !onboardingCompleted { activeSheet = .onboarding }
        }
    }
}

private enum RootSheet: String, Identifiable { case settings, onboarding; var id: String { rawValue } }

private struct OnboardingView: View {
    let french: Bool
    let finish: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "lock.shield").font(.system(size: 36)).foregroundStyle(.tint)
            Text(french ? "Bienvenue dans CoreTend" : "Welcome to CoreTend").font(.largeTitle.bold())
            Text(french ? "Choisissez vous-même les dossiers à examiner. Les scans restent locaux et en lecture seule. Tout déplacement nécessite sélection, revue et confirmation vers la Corbeille macOS." : "Choose folders yourself. Scans stay local and read-only. Any move requires selection, review and confirmation to macOS Trash.")
                .font(.body).fixedSize(horizontal: false, vertical: true)
            Text(french ? "Aucun accès intégral au disque n’est demandé. Vous pouvez commencer sans autoriser d’accès supplémentaire." : "CoreTend does not request Full Disk Access. You can begin without granting extra access.")
                .font(.callout).foregroundStyle(.secondary)
            HStack { Spacer(); Button(french ? "Commencer" : "Get started", action: finish).keyboardShortcut(.defaultAction) }
        }
        .padding(32).frame(width: 520)
    }
}

private struct DestinationView: View {
    let destination: Destination
    let french: Bool

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
                if destination == .explore {
                    ExploreScanView(french: french)
                } else if destination == .duplicates {
                    DuplicateScanView(french: french)
                } else if destination == .overview || destination == .performance {
                    EmptyView()
                } else if destination == .record {
                    RecordView(french: french)
                } else if destination == .cleanup {
                    CleanupView(french: french)
                } else if destination == .applications {
                    ApplicationsView(french: french)
                } else if destination == .integrity {
                    IntegrityView(french: french)
                } else {
                    ContentUnavailableView(ProductCopy.value(for: "empty.title", french: french),
                                           systemImage: destination.symbol,
                                           description: Text(ProductCopy.value(for: "empty.body", french: french)))
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(32)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .accessibilityIdentifier("destination-\(destination.rawValue)")
    }
}
