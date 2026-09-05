// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Observation
import ScanCore
import FileRules
import SystemMetrics
import Persistence

struct DeveloperScanSnapshot: Sendable {
    let date: Date
    let groups: [DeveloperStorage.Group]
    let rootStates: [String: StorageAvailability]
    let failedRuleIDs: Set<String>
    let excludedRuleIDs: Set<String>
    let omittedCount: Int
    let xcode: StorageAvailability
    let simulators: StorageMeasurement
    let docker: DeveloperStorageInspector.DockerInspection

    /// Only retained, executable Cleanup findings. Inspections have no route
    /// into this total. A failed rule's partial results are never actionable.
    var potentiallyRecoverableBytes: Int64 { groups.reduce(0) { $0 + $1.logicalBytes } }
}

enum DeveloperCenterService {
    static let findingLimit = 50_000

    /// Caller runs this on a detached utility task. Same ScanEngine and rules
    /// as Cleanup, limited to Developer categories. Never writes a partial
    /// Developer scan into the full Cleanup Timeline scope.
    static func scan(home: URL, applicationRoots: [URL], excludedPaths: [String],
                     limit: Int = findingLimit) async -> DeveloperScanSnapshot? {
        let rules = DeveloperStorage.rules
        var states: [String: StorageAvailability] = [:]
        var excludedRules: Set<String> = []
        for rule in rules {
            for root in rule.roots(home) {
                states[root.path] = DeveloperStorageInspector.presence(root)
                if excludedPaths.contains(where: {
                    let path = URL(fileURLWithPath: $0).standardizedFileURL.path
                    return root.standardizedFileURL.path == path || root.standardizedFileURL.path.hasPrefix(path + "/")
                }) { excludedRules.insert(rule.id) }
            }
        }
        var findings: [ScanFinding] = []
        var failures: Set<String> = []
        var omitted = 0
        for await event in ScanEngine(configuration: ScanConfiguration(home: home, excludedPaths: excludedPaths)).run(rules: rules) {
            guard !Task.isCancelled else { return nil }
            switch event {
            case let .finding(finding):
                if findings.count < limit { findings.append(finding) } else { omitted += 1 }
            case let .error(path, _):
                let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
                for rule in rules where rule.roots(home).contains(where: {
                    normalized == $0.standardizedFileURL.path || normalized.hasPrefix($0.standardizedFileURL.path + "/")
                }) { failures.insert(rule.id) }
            case .cancelled: return nil
            default: break
            }
        }
        guard !Task.isCancelled else { return nil }
        let simulators = DeveloperStorageInspector.simulators(home: home)
        guard !Task.isCancelled else { return nil }
        let docker = DeveloperStorageInspector.docker(home: home, applicationRoots: applicationRoots)
        let xcodes = applicationRoots.map { DeveloperStorageInspector.presence($0.appendingPathComponent("Xcode.app")) }
        let xcode: StorageAvailability = xcodes.contains(.available) ? .available
            : xcodes.contains(.unavailable) ? .unavailable : .absent
        return DeveloperScanSnapshot(date: Date(),
            groups: DeveloperStorage.groups(findings: findings.filter { !failures.contains($0.ruleID) }),
            rootStates: states, failedRuleIDs: failures, excludedRuleIDs: excludedRules,
            omittedCount: omitted, xcode: xcode, simulators: simulators, docker: docker)
    }
}

@MainActor
@Observable
final class DeveloperCenterModel {
    enum Phase: Equatable { case idle, scanning, ready, running }
    private(set) var phase: Phase = .idle
    private(set) var snapshot: DeveloperScanSnapshot?
    var selectedIDs: Set<UUID> = []
    private(set) var executionResult: CleanupExecution.Result?
    let home: URL
    private let applicationRoots: [URL]
    private let store: Store?
    private var scanTask: Task<DeveloperScanSnapshot?, Never>?
    private var generation = UUID()

    convenience init() {
        let locations = ApplicationInventoryLocations.resolve(environment: ProcessInfo.processInfo.environment)
        self.init(home: locations.home, applicationRoots: locations.applicationRoots, store: AppEnvironment.shared.store)
    }

    init(home: URL, applicationRoots: [URL], store: Store?) {
        self.home = home
        self.applicationRoots = applicationRoots
        self.store = store
    }

    var selectedFindings: [ScanFinding] {
        (snapshot?.groups.flatMap(\.findings) ?? []).filter { selectedIDs.contains($0.id) }
    }
    var selectedBytes: Int64 { selectedFindings.reduce(0) { $0 + $1.logicalSize } }

    func loadIfNeeded() async {
        if snapshot == nil { await refresh() }
    }

    func refresh() async {
        guard phase != .scanning, phase != .running else { return }
        phase = .scanning
        selectedIDs = []
        executionResult = nil
        let token = UUID()
        generation = token
        let excluded = (try? await store?.exclusions()) ?? []
        guard generation == token, !Task.isCancelled else { cancel(); return }
        let home = home, roots = applicationRoots
        let worker = Task.detached(priority: .utility) {
            await DeveloperCenterService.scan(home: home, applicationRoots: roots, excludedPaths: excluded)
        }
        scanTask = worker
        let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        guard generation == token else { return }
        scanTask = nil
        guard let result, !Task.isCancelled, !worker.isCancelled else {
            phase = snapshot == nil ? .idle : .ready
            return
        }
        snapshot = result
        selectedIDs = Set(result.groups.flatMap(\.findings).filter { $0.preselected && $0.risk == .low }.map(\.id))
        phase = .ready
    }

    func cancel() {
        guard phase == .scanning else { return }
        generation = UUID()
        scanTask?.cancel()
        scanTask = nil
        phase = snapshot == nil ? .idle : .ready
    }

    func setSelection(_ on: Bool, group: DeveloperStorage.Group) {
        guard phase == .ready, executionResult == nil else { return }
        for finding in group.findings {
            if on { selectedIDs.insert(finding.id) } else { selectedIDs.remove(finding.id) }
        }
    }

    /// Called only after the same explicit Trash confirmation used by Cleanup.
    func executeSelection() async {
        guard phase == .ready, executionResult == nil, !selectedIDs.isEmpty else { return }
        phase = .running
        let selected = selectedFindings
        let excluded = (try? await store?.exclusions()) ?? []
        let result = await CleanupExecution.execute(selected, home: home, excludedPaths: excluded, sink: store)
        if let store {
            _ = try? await store.recordActivity(ActivityRecord(kind: .cleanup,
                summary: "Developer Center: moved \(result.executed.count) items to Trash",
                itemCount: result.executed.count, bytes: result.processedBytes))
        }
        executionResult = result
        selectedIDs = []
        phase = .ready
    }
}
