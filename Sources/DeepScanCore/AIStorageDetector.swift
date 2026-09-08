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

/// A known AI tool and where its data lives, relative to home.
struct AIToolProfile: Sendable {
    let name: String
    /// Home-relative roots (first path component after `~`).
    let roots: [String]
    /// Ordered rules: first matching suffix/segment wins. Segments match on a
    /// path *component* boundary, not substring.
    let rules: [(segment: String, type: AIDataType)]
}

public struct AIStorageDetector: Detector {
    public let id = "ai-storage"
    public let category: CleanupCategory = .aiAndLLM
    public init() {}

    // Data-type rules are deliberately explicit and conservative. Anything a
    // profile does not positively classify becomes `.unknownData` -> PROTECTED.
    static let profiles: [AIToolProfile] = [
        AIToolProfile(name: "Claude Code", roots: [".claude"], rules: [
            ("memory", .userMemory),
            ("projects", .projectState),
            ("history", .conversationHistory),
            ("todos", .projectState),
            ("statsig", .runtimeCache),
            ("shell-snapshots", .tempFiles),
            (".credentials.json", .auth),
            ("settings.json", .config),
        ]),
        AIToolProfile(name: "Codex", roots: [".codex"], rules: [
            ("sessions", .conversationHistory),
            ("history", .conversationHistory),
            ("auth.json", .auth),
            ("config.toml", .config),
            ("log", .runtimeCache),
        ]),
        AIToolProfile(name: "LM Studio", roots: [".cache/lm-studio", ".lmstudio"], rules: [
            ("models", .modelWeights),
            ("downloads", .downloadCache),
            ("conversations", .conversationHistory),
            ("config-presets", .config),
            ("logs", .runtimeCache),
        ]),
        AIToolProfile(name: "Ollama", roots: [".ollama"], rules: [
            ("models", .modelWeights),
            ("history", .conversationHistory),
            ("id_ed25519", .auth),
            ("logs", .runtimeCache),
        ]),
        AIToolProfile(name: "Hugging Face", roots: [".cache/huggingface", ".huggingface"], rules: [
            ("hub", .downloadCache),
            ("datasets", .downloadCache),
            ("token", .auth),
            ("modules", .runtimeCache),
        ]),
        AIToolProfile(name: "MLX", roots: [".cache/mlx", ".mlx"], rules: [
            ("models", .compiledModelCache),
        ]),
        AIToolProfile(name: "llama.cpp", roots: [".cache/llama.cpp"], rules: [
            ("", .downloadCache),
        ]),
        AIToolProfile(name: "Cursor", roots: [".cursor"], rules: [
            ("extensions", .extensionsPlugins),
            ("argv.json", .config),
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
                let children = graph.children(of: rootPath)
                var classifiedAny = false
                for child in children {
                    let name = (child.canonicalPath as NSString).lastPathComponent
                    guard let type = Self.classify(name: name, rules: profile.rules) else {
                        candidates.append(Self.candidate(node: child, tool: profile.name,
                            type: .unknownData, graph: graph, context: context, model: model))
                        classifiedAny = true
                        continue
                    }
                    classifiedAny = true
                    candidates.append(Self.candidate(node: child, tool: profile.name, type: type,
                        graph: graph, context: context, model: model))
                }
                if !classifiedAny {
                    candidates.append(Self.candidate(node: rootNode, tool: profile.name,
                        type: .unknownData, graph: graph, context: context, model: model))
                }
            }
        }
        return candidates
    }

    /// Component-boundary match. `""` matches the root itself (whole dir).
    static func classify(name: String, rules: [(segment: String, type: AIDataType)]) -> AIDataType? {
        for rule in rules {
            if rule.segment.isEmpty { return rule.type }
            if name == rule.segment { return rule.type }
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
