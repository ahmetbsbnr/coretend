import Foundation

public enum CommandTarget: Equatable, Sendable {
    case destination(Destination)
    case settings
}

public struct ProductCommand: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let searchTerms: [String]
    public let target: CommandTarget
}

public enum CommandPaletteCatalog {
    public static func commands(french: Bool) -> [ProductCommand] {
        let destinations = Destination.allCases.map { destination in
            let aliases = searchAliases(for: destination)
            return ProductCommand(id: destination.rawValue,
                                  title: ProductCopy.value(for: destination.titleKey, french: french),
                                  searchTerms: aliases,
                                  target: .destination(destination))
        }
        return destinations + [ProductCommand(id: "settings", title: ProductCopy.value(for: "settings.title", french: french),
                                              searchTerms: ["preferences", "préférences", "configuration"],
                                              target: .settings)]
    }

    public static func search(_ query: String, french: Bool) -> [ProductCommand] {
        let all = commands(french: french)
        let needle = folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return all }
        return all.filter { command in
            ([command.title] + command.searchTerms).contains { folded($0).contains(needle) }
        }
    }

    private static func searchAliases(for destination: Destination) -> [String] {
        switch destination {
        case .overview: ["home", "favorites", "recent files", "accueil", "favoris", "récents"]
        case .record: ["history", "activity", "log", "journal", "activité", "historique"]
        case .cleanup: ["clean", "free space", "nettoyer", "récupérer de l’espace"]
        case .explore: ["files", "folders", "storage", "fichiers", "dossiers", "stockage"]
        case .duplicates: ["copies", "duplicate files", "doublons exacts"]
        case .applications: ["apps", "software", "logiciels"]
        case .integrity: ["signature", "quarantine", "quarantaine"]
        case .performance: ["system", "measurements", "load", "système", "mesures", "charge"]
        }
    }

    private static func folded(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

public enum CommandMoveDirection: Equatable, Sendable { case up, down }

public enum CommandPaletteNavigation {
    public static func move(in commands: [ProductCommand], selectedID: String?, direction: CommandMoveDirection) -> String? {
        guard !commands.isEmpty else { return nil }
        guard let index = commands.firstIndex(where: { $0.id == selectedID }) else {
            return direction == .down ? commands.first?.id : commands.last?.id
        }
        switch direction {
        case .up: return commands[max(0, index - 1)].id
        case .down: return commands[min(commands.count - 1, index + 1)].id
        }
    }
}
