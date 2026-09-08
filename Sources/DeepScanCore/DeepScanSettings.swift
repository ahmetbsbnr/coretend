// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanSettings — user-tunable *analysis scope* for Deep Scan (spec §31).
//
// These only widen or narrow what is analysed. There is deliberately no toggle
// here for any SafetyCenter protection, the protected-path policy, Trash-only
// execution, or the execution feature gate — those are not user-configurable.

import Foundation

public struct DeepScanSettings: Sendable, Codable, Equatable {
    /// Absolute paths of volumes to include beyond the home volume. Empty by
    /// default: external / secondary volumes are opt-in.
    public var includedExternalVolumeRoots: [String]
    /// Analyse external volumes at all (must also be listed above).
    public var scanExternalVolumes: Bool
    /// Run the developer-storage detector (.next, node_modules, target, …).
    public var developerAnalysisEnabled: Bool
    /// Allow `git ls-remote` during Git analysis (network). Off by default.
    public var gitNetworkVerificationEnabled: Bool
    /// Run the AI / LLM storage detector.
    public var aiAnalysisEnabled: Bool
    /// Run the system / settings detector (launch agents, etc.).
    public var systemAnalysisEnabled: Bool
    /// Analyse cloud-backed locations (detection only — never deleted).
    public var cloudAnalysisEnabled: Bool

    public static let `default` = DeepScanSettings(
        includedExternalVolumeRoots: [],
        scanExternalVolumes: false,
        developerAnalysisEnabled: true,
        gitNetworkVerificationEnabled: false,
        aiAnalysisEnabled: true,
        systemAnalysisEnabled: true,
        cloudAnalysisEnabled: true)

    public init(includedExternalVolumeRoots: [String], scanExternalVolumes: Bool,
                developerAnalysisEnabled: Bool, gitNetworkVerificationEnabled: Bool,
                aiAnalysisEnabled: Bool, systemAnalysisEnabled: Bool, cloudAnalysisEnabled: Bool) {
        self.includedExternalVolumeRoots = includedExternalVolumeRoots
        self.scanExternalVolumes = scanExternalVolumes
        self.developerAnalysisEnabled = developerAnalysisEnabled
        self.gitNetworkVerificationEnabled = gitNetworkVerificationEnabled
        self.aiAnalysisEnabled = aiAnalysisEnabled
        self.systemAnalysisEnabled = systemAnalysisEnabled
        self.cloudAnalysisEnabled = cloudAnalysisEnabled
    }

    // Tolerant decode so adding a field never wipes a user's saved settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DeepScanSettings.default
        includedExternalVolumeRoots = (try? c.decode([String].self, forKey: .includedExternalVolumeRoots)) ?? d.includedExternalVolumeRoots
        scanExternalVolumes = (try? c.decode(Bool.self, forKey: .scanExternalVolumes)) ?? d.scanExternalVolumes
        developerAnalysisEnabled = (try? c.decode(Bool.self, forKey: .developerAnalysisEnabled)) ?? d.developerAnalysisEnabled
        gitNetworkVerificationEnabled = (try? c.decode(Bool.self, forKey: .gitNetworkVerificationEnabled)) ?? d.gitNetworkVerificationEnabled
        aiAnalysisEnabled = (try? c.decode(Bool.self, forKey: .aiAnalysisEnabled)) ?? d.aiAnalysisEnabled
        systemAnalysisEnabled = (try? c.decode(Bool.self, forKey: .systemAnalysisEnabled)) ?? d.systemAnalysisEnabled
        cloudAnalysisEnabled = (try? c.decode(Bool.self, forKey: .cloudAnalysisEnabled)) ?? d.cloudAnalysisEnabled
    }

    // MARK: persistence

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("CoreTend/deep-scan-settings.json")
    }

    public static func load(from url: URL = DeepScanSettings.defaultFileURL()) -> DeepScanSettings {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(DeepScanSettings.self, from: data)
        else { return .default }
        return decoded
    }

    public func save(to url: URL = DeepScanSettings.defaultFileURL()) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    // MARK: apply to a run

    /// The detector set implied by these settings.
    public func detectors() -> [any Detector] {
        var out: [any Detector] = [
            OrphanedAppDetector(),
            InstallerDetector(),
            LargeOldFileDetector(),
            TempFilesDetector(),
        ]
        if aiAnalysisEnabled { out.insert(AIStorageDetector(), at: 0) }
        if developerAnalysisEnabled {
            out.append(DeveloperStorageDetector())
            out.append(GitProjectDetector())
            out.append(DuplicateProjectsDetector())
        }
        if systemAnalysisEnabled { out.append(SystemSettingsDetector()) }
        if cloudAnalysisEnabled { out.append(CloudStorageDetector()) }
        return out
    }

    /// Roots to scan given the user's home. External volume roots are added
    /// only when `scanExternalVolumes` is on.
    public func scanRoots(home: URL) -> [URL] {
        var roots = [home]
        if scanExternalVolumes {
            roots += includedExternalVolumeRoots.map { URL(fileURLWithPath: $0) }
        }
        return roots
    }
}
