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
            let aliases = searchAliases(for: destination, french: french)
            return ProductCommand(id: destination.rawValue,
                                  title: ProductCopy.value(for: destination.titleKey, french: french),
                                  searchTerms: aliases,
                                  target: .destination(destination))
        }
        return destinations + [ProductCommand(id: "settings", title: ProductCopy.value(for: "settings.title", french: french),
                                              searchTerms: french ? ["préférences", "configuration"] : ["preferences", "configuration"],
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

    private static func searchAliases(for destination: Destination, french: Bool) -> [String] {
        switch destination {
        case .overview: french ? ["accueil", "favoris", "récents"] : ["home", "favorites", "recent files"]
        case .record: french ? ["journal", "activité", "historique"] : ["history", "activity", "log"]
        case .cleanup: french ? ["nettoyer", "récupérer de l’espace"] : ["clean", "free space"]
        case .explore: french ? ["fichiers", "dossiers", "stockage"] : ["files", "folders", "storage"]
        case .duplicates: french ? ["copies", "doublons exacts"] : ["copies", "duplicate files"]
        case .applications: french ? ["apps", "logiciels"] : ["apps", "software"]
        case .integrity: french ? ["signature", "quarantaine"] : ["signature", "quarantine"]
        case .performance: french ? ["système", "mesures", "charge"] : ["system", "measurements", "load"]
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
