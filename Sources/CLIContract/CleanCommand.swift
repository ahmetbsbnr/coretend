import Foundation
import ScanCore
import SafetyCore

/// `coretend clean`: the Clean space for the terminal. It reads every rule's folder in the home
/// folder; without `--confirm` it only lists. With `--confirm` it moves the safe items (or every
/// item of the rule named with `--rule`) to the Trash, each one revalidated just before.
struct CleanCommand {
    let rule: ScanRule?
    let confirm: Bool
    let format: CLIOutputFormat
    let language: CLILanguage
    var home = CLIHome.url
    var trash: any TrashClient = MacOSTrashClient()

    func run(write: @Sendable (String) -> Void) async -> Int32 {
        let survey = CleanupSurvey(home: home)
        let report: CleanupSurveyReport
        do { report = try await survey.run() } catch { write(language.scanFailedMessage); return Task.isCancelled ? 130 : 1 }
        let chosen = report.groups.flatMap(\.items).filter { item in
            if let rule { return item.ruleID == rule }
            return item.risk == .low
        }
        var moved: [String] = [], failed: [String: String] = [:]
        if confirm && !chosen.isEmpty {
            let roots = survey.presentRoots().map(\.root)
            let rules = Set(chosen.map(\.ruleID.rawValue))
            let executor = SafeActionExecutor(allowedRoots: roots, allowedRules: rules, trash: trash)
            for item in chosen {
                do {
                    let approved = try PathValidator().approve(target: item.url, allowedRoots: roots, ruleID: item.ruleID.rawValue, allowedRuleIDs: rules)
                    if case .movedToTrash = await executor.execute(approved) { moved.append(item.url.path) } else { failed[item.url.path] = "trash_failed" }
                } catch { failed[item.url.path] = "revalidation_failed" }
            }
        }
        if format == .json {
            let groups = report.groups.map { group in
                CleanGroupJSON(rule: group.rule.id.rawValue, risk: group.rule.risk.rawValue, bytes: group.bytes,
                               items: group.items.map { CleanItemJSON(path: $0.url.path, bytes: $0.bytes, files: $0.files) })
            }
            let output = CleanReportJSON(groups: groups, selectedBytes: chosen.reduce(0) { $0 + $1.bytes },
                                         confirmed: confirm, moved: moved, failed: failed)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            write((try? encoder.encode(output)).map { String(decoding: $0, as: UTF8.self) } ?? "{}")
        } else {
            let fr = language == .fr
            for group in report.groups {
                let mark = chosen.contains { $0.ruleID == group.rule.id } ? "•" : " "
                write("\(mark) \(group.rule.id.rawValue)\t\(group.rule.risk.rawValue)\t\(Self.bytes(group.bytes))\t\(group.items.count) \(fr ? "éléments" : "items")")
            }
            let total = Self.bytes(chosen.reduce(0) { $0 + $1.bytes })
            if !confirm {
                write(fr ? "Simulation : \(total) seraient placés dans la Corbeille (•). Rien n’a bougé. Ajoutez --confirm pour le faire."
                         : "Dry run: \(total) would go to the Trash (•). Nothing moved. Add --confirm to do it.")
            } else {
                write(fr ? "\(moved.count) éléments placés dans la Corbeille ; \(failed.count) laissés en place."
                         : "\(moved.count) items moved to the Trash; \(failed.count) left in place.")
            }
        }
        return failed.isEmpty ? 0 : 1
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

private struct CleanItemJSON: Codable { let path: String; let bytes: Int64; let files: Int }
private struct CleanGroupJSON: Codable { let rule: String; let risk: String; let bytes: Int64; let items: [CleanItemJSON] }
private struct CleanReportJSON: Codable {
    let groups: [CleanGroupJSON]
    let selectedBytes: Int64
    let confirmed: Bool
    let moved: [String]
    let failed: [String: String]
}

/// The home folder a command-line tool works in: `HOME` when it is set, as every Unix tool does.
public enum CLIHome {
    public static var url: URL {
        let path = ProcessInfo.processInfo.environment["HOME"].flatMap { $0.isEmpty ? nil : $0 } ?? NSHomeDirectory()
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
