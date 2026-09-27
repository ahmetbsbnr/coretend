import Foundation
import Persistence
import ScanCore

public enum CLIOutputFormat: String, Sendable { case text, json }
public enum CLILanguage: String, Equatable, Sendable {
    case en
    case fr

    public static func bestEffort(from arguments: [String]) -> Self {
        guard arguments.count > 1, arguments[0] == "--lang" else { return .en }
        return Self(rawValue: arguments[1]) ?? .en
    }

    public var helpText: String {
        switch self {
        case .en: CoreTendCLIRunner.helpText
        case .fr: CoreTendCLIRunner.frenchHelpText
        }
    }

    public var unreadableStoreMessage: String {
        self == .fr ? "Impossible de lire le store demandé." : "Unable to read the requested store."
    }

    public var encodingRecordsMessage: String {
        self == .fr ? "Impossible d’encoder les événements." : "Unable to encode records."
    }

    public var scanFailedMessage: String {
        self == .fr ? "Échec de l’analyse." : "Scan failed."
    }

    public var versionMessage: String {
        self == .fr ? "CoreTend greenfield — non publiée" : "CoreTend greenfield — unreleased"
    }

    public func fileCountMessage(_ count: Int) -> String {
        self == .fr ? "\(count) fichiers" : "\(count) files"
    }

    public func scanIssueMessage(reason: String, path: String) -> String {
        self == .fr ? "Problème d’analyse [\(reason)] : \(path)" : "Scan issue [\(reason)]: \(path)"
    }
}

public struct CLIInvocation: Sendable {
    public let command: CLICommand
    public let language: CLILanguage

    public static func parse(_ arguments: [String]) throws -> Self {
        var commandArguments = arguments
        var language = CLILanguage.en
        if commandArguments.first == "--lang" {
            guard commandArguments.count >= 3,
                  let parsedLanguage = CLILanguage(rawValue: commandArguments[1]) else {
                throw CLIError.invalidArguments
            }
            language = parsedLanguage
            commandArguments.removeFirst(2)
        }
        return Self(command: try CLICommand.parse(commandArguments), language: language)
    }
}

public enum CLICommand: Sendable {
    case help
    case version
    case scan(root: URL, rule: ScanRule, format: CLIOutputFormat)
    case record(store: URL)

    public static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else { return .help }
        switch command {
        case "help", "--help", "-h":
            guard arguments.count == 1 else { throw CLIError.invalidArguments }
            return .help
        case "version", "--version":
            guard arguments.count == 1 else { throw CLIError.invalidArguments }
            return .version
        case "scan":
            let values = try flags(Array(arguments.dropFirst()), allowed: ["--root", "--rule", "--format"])
            guard let rootValue = values["--root"], !rootValue.isEmpty,
                  let ruleValue = values["--rule"], let rule = ScanRule(rawValue: ruleValue) else { throw CLIError.invalidArguments }
            let format = CLIOutputFormat(rawValue: values["--format"] ?? "text")
            guard let format else { throw CLIError.invalidArguments }
            return .scan(root: URL(fileURLWithPath: rootValue).standardizedFileURL, rule: rule, format: format)
        case "record":
            guard arguments.dropFirst().first == "list" else { throw CLIError.invalidArguments }
            let values = try flags(Array(arguments.dropFirst(2)), allowed: ["--store"])
            guard let path = values["--store"], !path.isEmpty else { throw CLIError.storePathRequired }
            return .record(store: URL(fileURLWithPath: path).standardizedFileURL)
        default: throw CLIError.unsupportedCommand
        }
    }

    private static func flags(_ arguments: [String], allowed: Set<String>) throws -> [String: String] {
        var result: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard allowed.contains(key), result[key] == nil, index + 1 < arguments.count else { throw CLIError.invalidArguments }
            let value = arguments[index + 1]
            guard !value.hasPrefix("-") else { throw CLIError.invalidArguments }
            result[key] = value
            index += 2
        }
        return result
    }
}

public enum CLIError: Error, Equatable { case invalidArguments, unsupportedCommand, storePathRequired }

public extension CLIError {
    func message(in language: CLILanguage) -> String {
        switch (self, language) {
        case (.invalidArguments, .en), (.unsupportedCommand, .en): "Invalid or unsupported command. Run 'coretend help'."
        case (.invalidArguments, .fr), (.unsupportedCommand, .fr): "Commande invalide ou non prise en charge. Lancez 'coretend help'."
        case (.storePathRequired, .en): "Provide --store PATH. The CLI never guesses a user store location."
        case (.storePathRequired, .fr): "Fournissez --store CHEMIN. Le CLI ne devine jamais le chemin d’un store utilisateur."
        }
    }
}

public enum CoreTendCLIRunner {
    public static let helpText = """
    CoreTend — local read-only tools
    Usage:
      coretend scan --root PATH --rule RULE_ID [--format text|json]
      coretend record list --store PATH
      coretend version
    Scans require an explicit root. CLI has no file-removal command.
    Exit codes: 0 complete/help; 1 scan or store failure; 2 partial scan or usage error; 130 cancelled.
    """

    public static let frenchHelpText = """
    CoreTend — outils locaux en lecture seule
    Utilisation :
      coretend [--lang en|fr] scan --root CHEMIN --rule ID_RÈGLE [--format text|json]
      coretend [--lang en|fr] record list --store CHEMIN
      coretend [--lang en|fr] version
    Toute analyse exige une racine explicite. Le CLI ne propose aucune commande de retrait de fichier.
    Codes de sortie : 0 terminé/aide; 1 échec d’analyse ou de store; 2 analyse partielle ou erreur d’usage; 130 annulation.
    """

    public static func run(_ command: CLICommand, language: CLILanguage = .en,
                           write: @Sendable (String) -> Void) async -> Int32 {
        switch command {
        case .help:
            write(language.helpText); return 0
        case .version:
            write(language.versionMessage); return 0
        case .record(let url):
            do {
                let store = try SQLiteStore(url: url, readOnly: true)
                let events = try await store.events()
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; encoder.dateEncodingStrategy = .iso8601
                guard let data = try? encoder.encode(events), let text = String(data: data, encoding: .utf8) else { write(language.encodingRecordsMessage); return 1 }
                write(text); return 0
            } catch { write(language.unreadableStoreMessage); return 1 }
        case .scan(let root, let rule, let format):
            do {
                var output: [CLIResult] = []
                var issues: [CLIIssue] = []
                for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: rule)])) {
                    if case .result(let result) = event { output.append(CLIResult(result)) }
                    if case .itemFailure(let path, let reason) = event { issues.append(CLIIssue(path: path, reason: reason)) }
                    if Task.isCancelled { return 130 }
                }
                if Task.isCancelled { return 130 }
                if format == .json {
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(CLIScanReport(files: output, issues: issues, complete: issues.isEmpty))
                    write(String(decoding: data, as: UTF8.self))
                } else {
                    for row in output { write("\(row.path)\t\(row.logicalBytes.map(String.init) ?? "unknown")") }
                    write(language.fileCountMessage(output.count))
                    for issue in issues { write(language.scanIssueMessage(reason: issue.reason, path: issue.path)) }
                }
                return issues.isEmpty ? 0 : 2
            } catch { write(language.scanFailedMessage); return 1 }
        }
    }
}

private struct CLIResult: Codable {
    let path: String
    let rule: String
    let logicalBytes: Int64?
    let allocatedBytes: Int64?
    let modifiedAt: Date?
    init(_ result: ScanResult) {
        path = result.url.path; rule = result.ruleID.rawValue
        if case .known(let value) = result.logicalBytes { logicalBytes = value } else { logicalBytes = nil }
        if case .known(let value) = result.allocatedBytes { allocatedBytes = value } else { allocatedBytes = nil }
        modifiedAt = result.modifiedAt
    }
}

private struct CLIScanReport: Codable {
    let files: [CLIResult]
    let issues: [CLIIssue]
    let complete: Bool
}

private struct CLIIssue: Codable {
    let path: String
    let reason: String
}
