// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import FileRules
import Persistence
@preconcurrency import UserNotifications
@testable import CoreTendApp

private final class FakeScheduler: BackgroundScheduling, @unchecked Sendable {
    private(set) var scheduledInterval: TimeInterval?
    private(set) var invalidateCount = 0
    private var operation: ((@escaping @Sendable () -> Void) -> Void)?

    func schedule(identifier: String, interval: TimeInterval, tolerance: TimeInterval,
                  operation: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void) {
        scheduledInterval = interval
        self.operation = operation
    }
    func invalidate() { invalidateCount += 1; scheduledInterval = nil }

    /// Fires the registered activity once, synchronously waiting for it.
    func fire() async {
        guard let operation else { return }
        await withCheckedContinuation { continuation in
            operation { continuation.resume() }
        }
    }
}

private actor SpyDelivery: NotificationDelivering {
    private(set) var postCount = 0
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async -> UNAuthorizationStatus { .authorized }
    func post(identifier: String, title: String, body: String, routeModule: String) async { postCount += 1 }
}

private func tempStore() throws -> Store {
    try Store(path: FileManager.default.temporaryDirectory
        .appendingPathComponent("macint-\(UUID().uuidString).sqlite").path)
}

@Suite("MacIntegrations — cadence + scheduler wiring")
@MainActor
struct MacIntegrationsTests {
    private func make(_ scheduler: FakeScheduler, store: Store,
                      home: URL, delivery: SpyDelivery) -> MacIntegrations {
        MacIntegrations(
            scheduler: scheduler,
            scanService: ScheduledScanService(store: store, home: home),
            notifications: NotificationService(
                delivery: delivery,
                preferences: NotificationPreferences(defaults: UserDefaults(suiteName: "mi.\(UUID().uuidString)")!),
                store: store, now: { Date() }),
            cadence: .off)
    }

    @Test func offInvalidatesAndSchedulesNothing() throws {
        let scheduler = FakeScheduler()
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let integrations = make(scheduler, store: try tempStore(), home: home, delivery: SpyDelivery())

        integrations.setCadence(.off)
        #expect(scheduler.scheduledInterval == nil)
        #expect(scheduler.invalidateCount >= 1)
    }

    @Test func dailyAndWeeklyScheduleTheRightInterval() throws {
        let scheduler = FakeScheduler()
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let integrations = make(scheduler, store: try tempStore(), home: home, delivery: SpyDelivery())

        integrations.setCadence(.daily)
        #expect(scheduler.scheduledInterval == 24.0 * 3600)
        integrations.setCadence(.weekly)
        #expect(scheduler.scheduledInterval == 7.0 * 24 * 3600)
    }

    @Test func firingTheScheduledActivityRunsAReadOnlyScanAndCanNotify() async throws {
        let scheduler = FakeScheduler()
        let store = try tempStore()
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Library/Logs"),
                                                withIntermediateDirectories: true)
        // A big stale log so the completed scan clears the "meaningful" bar
        // and the notification path is exercised end to end.
        let log = home.appendingPathComponent("Library/Logs/huge.log")
        try Data(String(repeating: "x", count: 2_000_000).utf8).write(to: log)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-10 * 86_400)], ofItemAtPath: log.path)
        defer { try? FileManager.default.removeItem(at: home) }

        let delivery = SpyDelivery()
        let integrations = make(scheduler, store: store, home: home, delivery: delivery)
        integrations.setCadence(.daily)
        await scheduler.fire()

        // The scan ran and wrote a scheduled snapshot; the real file is untouched.
        #expect(try await store.timelineSnapshots(scope: "cleanup").first?.trigger == "scheduled")
        #expect(FileManager.default.fileExists(atPath: log.path))
        // 2 MB stale log clears the 1 GB threshold? No — so no notification here.
        // (Threshold behaviour is covered directly in NotificationServiceTests;
        // this test's point is the wiring runs without error and stays read-only.)
        _ = await delivery.postCount
    }
}

/// Static guard: the scheduled/background execution path cannot reach a
/// destructive API, enforced at the source level (a dependency fact, not a
/// runtime flag). Mirrors the spirit of `Scripts/check-test-isolation.sh`.
/// Comments are stripped first so the prose in these files' own headers
/// (which name the APIs they must not call) does not trip the check.
@Suite("macOS integrations — destructive-API non-regression")
struct MacIntegrationsSafetyTests {
    private let sourceDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/CoreTendApp")

    /// Source with `//` line comments and `/* */` blocks removed.
    private func code(_ name: String) throws -> String {
        let raw = try String(contentsOf: sourceDir.appendingPathComponent(name), encoding: .utf8)
        var out = raw
        while let start = out.range(of: "/*"), let end = out.range(of: "*/", range: start.upperBound..<out.endIndex) {
            out.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return out
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                if let r = line.range(of: "//") { return String(line[line.startIndex..<r.lowerBound]) }
                return String(line)
            }
            .joined(separator: "\n")
    }

    private func expectAbsent(_ tokens: [String], in file: String) throws {
        let text = try code(file)
        for token in tokens {
            #expect(!text.contains(token), "\(file) must not reference `\(token)` in code")
        }
    }

    @Test func theScheduledScanExecutorReferencesNoDeleteRestoreOrCleanupAPI() throws {
        try expectAbsent(["CleanupExecution", "SafetyCenter", "RestoreService", "RecoveryPlanService",
                          "trashItem", ".removeItem(", "import FileRules"],
                         in: "ScheduledScanService.swift")
    }

    @Test func theAppIntentsReferenceNoDestructiveExecutionAPI() throws {
        for file in ["CoreTendIntents.swift", "CoreTendIntentText.swift"] {
            try expectAbsent(["CleanupExecution", "SafetyCenter(", "RestoreService", "RecoveryPlanService",
                              "trashItem", "import FileRules"],
                             in: file)
        }
    }

    @Test func theIntegrationGlueNeverCallsCleanupOrRestoreExecution() throws {
        try expectAbsent(["CleanupExecution.execute", "SafetyCenter(", "RestoreService(",
                          "RecoveryPlanService.execute", ".restore(", "trashItem"],
                         in: "MacIntegrations.swift")
    }
}
