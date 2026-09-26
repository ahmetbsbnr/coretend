import Foundation
import Persistence
import ScanCore

public enum CLIOutputFormat: String, Sendable { case text, json }
public enum CLICommand: Sendable {
    case help
    case version
    case scan(root: URL, rule: ScanRule, format: CLIOutputFormat)
    case record(store: URL)

    public static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else { return .help }
        switch command {
        case "help", "--help", "-h": return .help
        case "version", "--version": return .version
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
            result[key] = arguments[index + 1]
            index += 2
        }
        return result
    }
}

public enum CLIError: Error, Equatable { case invalidArguments, unsupportedCommand, storePathRequired }

public enum CoreTendCLIRunner {
    public static let helpText = """
    CoreTend — local read-only tools
    Usage:
      coretend scan --root PATH --rule RULE_ID [--format text|json]
      coretend record list --store PATH
      coretend version
    Scans require an explicit root. CLI has no file-removal command.
    """

    public static func run(_ command: CLICommand, write: @Sendable (String) -> Void) async -> Int32 {
        switch command {
        case .help:
            write(helpText); return 0
        case .version:
            write("CoreTend greenfield — unreleased"); return 0
        case .record(let url):
            do {
                let store = try SQLiteStore(url: url, readOnly: true)
                let events = try await store.events()
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; encoder.dateEncodingStrategy = .iso8601
                guard let data = try? encoder.encode(events), let text = String(data: data, encoding: .utf8) else { write("Unable to encode records."); return 1 }
                write(text); return 0
            } catch { write("Unable to read the requested store."); return 1 }
        case .scan(let root, let rule, let format):
            do {
                var output: [CLIResult] = []
                for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: rule)])) {
                    if case .result(let result) = event { output.append(CLIResult(result)) }
                    if Task.isCancelled { return 130 }
                }
                if format == .json {
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(output)
                    write(String(decoding: data, as: UTF8.self))
                } else {
                    for row in output { write("\(row.path)\t\(row.logicalBytes.map(String.init) ?? "unknown")") }
                    write("\(output.count) files")
                }
                return 0
            } catch { write("Scan failed."); return 1 }
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
