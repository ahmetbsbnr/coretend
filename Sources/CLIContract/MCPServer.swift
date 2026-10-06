import Foundation
import ScanCore
import Domain

/// `coretend mcp`: a Model Context Protocol server over standard input and output (one JSON-RPC
/// message per line). Every tool only reads; nothing is moved, nothing leaves the Mac.
public struct MCPServer: Sendable {
    let home: URL

    public init(home: URL = CLIHome.url) { self.home = home }

    public func serve() async {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }
            if let reply = await handle(line) {
                FileHandle.standardOutput.write(Data((reply + "\n").utf8))
            }
        }
    }

    /// The reply to one message, or nil for a notification.
    public func handle(_ line: String) async -> String? {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = message["method"] as? String else {
            return Self.encode(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        let result: Any
        switch method {
        case "initialize":
            result = ["protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                      "capabilities": ["tools": [String: Any]()],
                      "serverInfo": ["name": "coretend", "version": CoreTendCLIRunner.version],
                      "instructions": "CoreTend reads the Mac's disk usage. Every tool is read-only: to remove anything, the person uses the CoreTend app or `coretend clean --confirm`, which move items to the Trash."]
        case "ping": result = [String: Any]()
        case "tools/list": result = ["tools": Self.tools]
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            do {
                let payload = try await call(name, arguments)
                let text = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
                result = ["content": [["type": "text", "text": text]], "isError": false]
            } catch {
                result = ["content": [["type": "text", "text": "\(error)"]], "isError": true]
            }
        default:
            return Self.encode(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found"]])
        }
        return Self.encode(["jsonrpc": "2.0", "id": id, "result": result])
    }

    enum ToolError: Error, CustomStringConvertible {
        case unknownTool(String), missingArgument(String), notAFolder(String)
        var description: String {
            switch self {
            case .unknownTool(let name): "Unknown tool: \(name)"
            case .missingArgument(let name): "Missing argument: \(name)"
            case .notAFolder(let path): "Not a readable folder: \(path)"
            }
        }
    }

    static var tools: [[String: Any]] { [
        ["name": "disk_usage", "description": "Free and total space of the volume holding the home folder, as macOS reports it.",
         "inputSchema": ["type": "object", "properties": [String: Any]()]],
        ["name": "cleanup_candidates", "description": "Caches, logs and developer files CoreTend would offer to clean, grouped by rule with risk (low = safe) and size. Read-only.",
         "inputSchema": ["type": "object", "properties": [String: Any]()]],
        ["name": "largest_items", "description": "The largest entries directly inside a folder (default: the home folder), with their total size. Read-only.",
         "inputSchema": ["type": "object", "properties": ["path": ["type": "string", "description": "Folder to measure; ~ for the home folder."],
                                                           "limit": ["type": "integer", "minimum": 1, "maximum": 100]]]],
        ["name": "app_leftovers", "description": "Files an app left in ~/Library, found by its exact bundle identifier (and its name for a few folders). Read-only.",
         "inputSchema": ["type": "object", "properties": ["bundle_id": ["type": "string"], "name": ["type": "string"]], "required": ["bundle_id"]]],
    ] }

    func call(_ name: String, _ arguments: [String: Any]) async throws -> Any {
        switch name {
        case "disk_usage":
            let values = try home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            return ["total_bytes": values.volumeTotalCapacity ?? 0, "available_bytes": values.volumeAvailableCapacityForImportantUsage ?? 0]
        case "cleanup_candidates":
            let report = try await CleanupSurvey(home: home).run()
            return ["total_bytes": report.bytes, "groups": report.groups.map { group in
                ["rule": group.rule.id.rawValue, "risk": group.rule.risk.rawValue, "bytes": group.bytes, "items": group.items.count,
                 "largest": group.items.prefix(5).map { ["path": $0.url.path, "bytes": $0.bytes] }] as [String: Any]
            }]
        case "largest_items":
            let raw = (arguments["path"] as? String) ?? "~"
            let root = raw == "~" || raw.isEmpty ? home : URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            let limit = min(max(arguments["limit"] as? Int ?? 20, 1), 100)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw ToolError.notAFolder(root.path) }
            return ["path": root.path, "items": try await Self.largest(in: root, limit: limit)]
        case "app_leftovers":
            guard let id = arguments["bundle_id"] as? String, !id.isEmpty else { throw ToolError.missingArgument("bundle_id") }
            let found = AppLeftoverFinder(home: home).find(bundleIdentifier: id, displayName: arguments["name"] as? String ?? "")
            return ["bundle_id": id, "items": found.map { ["path": $0.url.path, "bytes": $0.bytes, "evidence": $0.evidence == .identifier ? "identifier" : "name"] }]
        default:
            throw ToolError.unknownTool(name)
        }
    }

    /// Sums every file under `root` into the entry directly inside it that holds it.
    static func largest(in root: URL, limit: Int) async throws -> [[String: Any]] {
        var totals: [String: Int64] = [:]
        let rootComponents = root.standardizedFileURL.pathComponents.count
        for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: .explore)])) {
            guard case .result(let result) = event, case .known(let bytes) = result.allocatedBytes else { continue }
            let components = result.url.standardizedFileURL.pathComponents
            guard components.count > rootComponents else { continue }
            totals[components[rootComponents], default: 0] += bytes
        }
        return totals.sorted { $0.value > $1.value }.prefix(limit).map { ["path": root.appendingPathComponent($0.key).path, "bytes": $0.value] }
    }

    static func encode(_ object: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}
