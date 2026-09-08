// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// AIStorageDetector — finds storage belonging to local AI / LLM tooling
// (LM Studio, Ollama, Hugging Face, MLX, llama.cpp, Claude Code, Codex,
// Cursor, Copilot, …) and classifies it by *data type*.
//
// It never classifies a whole tool directory as "cache". Each subtree is
// bucketed. User memory / conversation history / auth / config / unknown are
// PROTECTED and can never be selected — but they are still shown, with size,
// tool, data type, rebuild cost and last activity, so the user sees the whole
// picture (spec §7).
//
// Regression anchor: `~/.claude/projects/**/memory` and equivalents must ALWAYS
// resolve to .userMemory here. See DeepScanCoreTests.

import Foundation

public enum AIDataType: String, Sendable, Codable {
    case modelWeights          // review-only, never default-selected
    case downloadCache         // re-downloadable blobs
    case compiledModelCache    // e.g. MLX / CoreML converted graphs
    case updatePayload         // finished installer / update payloads
    case tempFiles             // scratch
    case pluginCache
    case runtimeCache
    case userMemory            // PROTECTED
    case conversationHistory   // PROTECTED
    case projectState          // PROTECTED (agent's per-project state)
    case auth                  // PROTECTED
    case config                // PROTECTED
    case extensionsPlugins
    case unknownData           // PROTECTED (fail closed)

    public var isProtected: Bool {
        switch self {
        case .userMemory, .conversationHistory, .projectState, .auth, .config, .unknownData:
            return true
        default:
            return false
        }
    }
}

/// How an AI classification rule matches a direct child's name.
enum AIRuleMatch: Sendable {
    case exact(String)     // name == value (component boundary, not substring)
    case prefix(String)    // name begins with value (e.g. "thread_history_3.sqlite")
    case suffix(String)    // name ends with value (e.g. ".sqlite", ".log")
    case whole             // matches the tool root itself when nothing else did
}

struct AIRule: Sendable {
    let match: AIRuleMatch
    let type: AIDataType
    init(_ match: AIRuleMatch, _ type: AIDataType) { self.match = match; self.type = type }
}

/// A known AI tool and where its data lives, relative to home.
struct AIToolProfile: Sendable {
    let name: String
    /// Home-relative roots (first path component after `~`).
    let roots: [String]
    /// Ordered rules: first match wins. A name that matches NOTHING becomes
    /// `.unknownData` -> PROTECTED (fail closed).
    let rules: [AIRule]
}

public struct AIStorageDetector: Detector {
    public let id = "ai-storage"
    public let category: CleanupCategory = .aiAndLLM
    public init() {}

    // Data-type rules are deliberately explicit and conservative. Anything a
    // profile does not positively classify becomes `.unknownData` -> PROTECTED.
    static let profiles: [AIToolProfile] = [
        AIToolProfile(name: "Claude Code", roots: [".claude"], rules: [
            // --- PROTECTED user state (never weakened) ---
            .init(.exact("memory"), .userMemory),
            .init(.exact("projects"), .projectState),
            .init(.exact("history"), .conversationHistory),
            .init(.exact("todos"), .projectState),
            .init(.exact("file-history"), .projectState),   // edit-undo history = user work
            .init(.exact("plugins"), .extensionsPlugins),
            .init(.exact(".credentials.json"), .auth),
            .init(.suffix(".json"), .config),               // settings.json, config.json, …
            // --- deterministically rebuildable ---
            .init(.exact("statsig"), .runtimeCache),
            .init(.exact("shell-snapshots"), .tempFiles),
            .init(.exact("logs"), .runtimeCache),
        ]),
        AIToolProfile(name: "Codex", roots: [".codex"], rules: [
            .init(.exact("sessions"), .conversationHistory),
            .init(.exact("history"), .conversationHistory),
            .init(.prefix("thread_history"), .conversationHistory),
            .init(.prefix("state"), .projectState),
            .init(.exact("plugins"), .extensionsPlugins),
            .init(.exact("auth.json"), .auth),
            .init(.suffix(".toml"), .config),
            .init(.exact("log"), .runtimeCache),
            .init(.exact("logs"), .runtimeCache),
            .init(.suffix(".log"), .runtimeCache),
        ]),
        AIToolProfile(name: "LM Studio", roots: [".cache/lm-studio", ".lmstudio"], rules: [
            .init(.exact("models"), .modelWeights),
            .init(.exact("downloads"), .downloadCache),
            .init(.exact("conversations"), .conversationHistory),
            .init(.exact("config-presets"), .config),
            .init(.suffix(".json"), .config),
            // Re-downloadable runtime binaries and disposable logs/scratch.
            .init(.exact("bin"), .runtimeCache),
            .init(.exact(".internal"), .runtimeCache),
            .init(.exact("logs"), .runtimeCache),
            .init(.exact("server-logs"), .runtimeCache),
            .init(.suffix(".log"), .runtimeCache),
            .init(.exact("extensions"), .extensionsPlugins),
        ]),
        AIToolProfile(name: "Ollama", roots: [".ollama"], rules: [
            .init(.exact("models"), .modelWeights),
            .init(.exact("history"), .conversationHistory),
            .init(.exact("id_ed25519"), .auth),
            .init(.prefix("id_ed25519"), .auth),            // .pub
            .init(.exact("logs"), .runtimeCache),
        ]),
        AIToolProfile(name: "Hugging Face", roots: [".cache/huggingface", ".huggingface"], rules: [
            .init(.exact("hub"), .downloadCache),
            .init(.exact("datasets"), .downloadCache),
            .init(.exact("token"), .auth),
            .init(.exact("stored_tokens"), .auth),
            .init(.exact("modules"), .runtimeCache),
        ]),
        AIToolProfile(name: "MLX", roots: [".cache/mlx", ".mlx"], rules: [
            .init(.exact("models"), .compiledModelCache),
        ]),
        AIToolProfile(name: "llama.cpp", roots: [".cache/llama.cpp"], rules: [
            .init(.whole, .downloadCache),
        ]),
        AIToolProfile(name: "Cursor", roots: [".cursor"], rules: [
            .init(.exact("extensions"), .extensionsPlugins),
            .init(.exact("argv.json"), .config),
            .init(.suffix(".json"), .config),
        ]),
    ]

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        let homePath = context.home.standardizedFileURL.path
        var candidates: [CleanupCandidate] = []
        let model = RiskConfidenceModel()

        for profile in Self.profiles {
            for rel in profile.roots {
                let rootPath = homePath + "/" + rel
                guard let rootNode = graph.node(at: rootPath) else { continue }

                // Emit a candidate per direct child that a rule classifies, plus
                // one for the tool root itself as UNKNOWN if nothing matched.
                // A `.whole` rule means "treat the entire tool root as this one
                // data type" (e.g. llama.cpp's cache dir).
                if let wholeType = profile.rules.first(where: {
                    if case .whole = $0.match { return true } else { return false }
                })?.type {
                    candidates.append(Self.candidate(node: rootNode, tool: profile.name,
                        type: wholeType, graph: graph, context: context, model: model))
                    continue
                }

                let children = graph.children(of: rootPath)
                if children.isEmpty {
                    candidates.append(Self.candidate(node: rootNode, tool: profile.name,
                        type: .unknownData, graph: graph, context: context, model: model))
                    continue
                }
                for child in children {
                    let name = (child.canonicalPath as NSString).lastPathComponent
                    // Unclassified -> .unknownData -> PROTECTED (fail closed).
                    let type = Self.classify(name: name, rules: profile.rules) ?? .unknownData
                    candidates.append(Self.candidate(node: child, tool: profile.name, type: type,
                        graph: graph, context: context, model: model))
                }
            }
        }
        return candidates
    }

    /// First matching rule wins. No match -> nil -> caller uses `.unknownData`.
    static func classify(name: String, rules: [AIRule]) -> AIDataType? {
        for rule in rules {
            switch rule.match {
            case .whole:
                continue   // handled by the caller, not per-child
            case .exact(let s):
                if name == s { return rule.type }
            case .prefix(let s):
                if name.hasPrefix(s) { return rule.type }
            case .suffix(let s):
                if name.hasSuffix(s) { return rule.type }
            }
        }
        return nil
    }

    static func candidate(node: ScanNode, tool: String, type: AIDataType,
                          graph: DiskGraph, context: DetectorContext,
                          model: RiskConfidenceModel) -> CleanupCandidate {
        let subtreeComplete = graph.subtreeFullyObserved(node.canonicalPath)
        var evidence: [Evidence] = [
            Evidence(.pathPattern, "Inside \(tool)'s data folder", detail: node.canonicalPath),
        ]
        if type.isProtected {
            evidence.append(Evidence(.userStateMarker,
                "This is \(tool) \(humanType(type)) — protected user state",
                detail: node.canonicalPath))
        }
        if !subtreeComplete {
            evidence.append(Evidence(.subtreeIncomplete,
                "CoreTend could not fully read this folder", detail: node.canonicalPath))
        }
        let running = context.runningBundleIDs.contains { $0.localizedCaseInsensitiveContains(tool) }
        if running {
            evidence.append(Evidence(.runningProcess, "\(tool) appears to be running"))
        }

        let reconstruction: Reconstructability = {
            switch type {
            case .modelWeights: return .largeModelDownload
            case .downloadCache, .compiledModelCache: return .networkRedownload
            case .updatePayload, .tempFiles, .runtimeCache, .pluginCache: return .regeneratesLocally
            case .extensionsPlugins: return .reinstallRequired
            case .userMemory, .conversationHistory, .projectState, .auth, .config, .unknownData:
                return .irreplaceable
            }
        }()

        let verdict = model.evaluate(
            evidence: evidence, subtreeComplete: subtreeComplete,
            reconstruction: reconstruction,
            activeState: running ? .inUseByRunningApp : .idle,
            gitSafety: nil)

        let action: CleanupCandidate.RecommendedAction =
            verdict.risk == .protected ? .keep
            : (type == .modelWeights ? .review
               : (verdict.risk == .safe ? .remove : .review))

        return CleanupCandidate(
            path: node.path, canonicalPath: node.canonicalPath,
            category: .aiAndLLM, subcategory: type.rawValue, detector: "ai-storage",
            logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
            estimatedReclaimableBytes: type.isProtected ? 0 : node.allocatedBytes,
            owner: tool, confidence: verdict.confidence, risk: verdict.risk,
            recoverability: .trashRestore, reconstructability: reconstruction,
            lastActivity: node.modifiedAt, activeState: running ? .inUseByRunningApp : .idle,
            evidence: evidence, protectedReason: verdict.protectedReason,
            recommendedAction: action, defaultSelected: verdict.defaultSelected,
            rationale: "\(tool) — \(humanType(type)).",
            ifRemoved: ifRemovedText(type: type, tool: tool))
    }

    static func humanType(_ t: AIDataType) -> String {
        switch t {
        case .modelWeights: "model weights"
        case .downloadCache: "download cache"
        case .compiledModelCache: "compiled model cache"
        case .updatePayload: "finished update payload"
        case .tempFiles: "temporary files"
        case .pluginCache: "plugin cache"
        case .runtimeCache: "runtime cache"
        case .userMemory: "saved memory"
        case .conversationHistory: "conversation history"
        case .projectState: "per-project state"
        case .auth: "sign-in credentials"
        case .config: "configuration"
        case .extensionsPlugins: "extensions / plugins"
        case .unknownData: "data of an unknown kind"
        }
    }

    static func ifRemovedText(type: AIDataType, tool: String) -> String {
        switch type {
        case .modelWeights: "You would re-download these model weights (can be many GB)."
        case .downloadCache, .compiledModelCache: "\(tool) would re-download or rebuild this on next use."
        case .updatePayload, .tempFiles, .runtimeCache, .pluginCache: "\(tool) recreates this automatically."
        case .extensionsPlugins: "You would reinstall the extensions."
        case .userMemory, .conversationHistory, .projectState, .auth, .config, .unknownData:
            "This cannot be recovered. CoreTend will not remove it."
        }
    }
}
