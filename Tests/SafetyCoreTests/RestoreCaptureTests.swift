// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import SafetyCore

/// Records every manifest the SafetyCenter emits, in order.
private actor CapturingRestoreSink: RestoreManifestSink {
    private(set) var records: [RestoreManifestRecord] = []
    func recordRestoreManifest(_ record: RestoreManifestRecord) async { records.append(record) }
}

private actor CapturingAuditSink: SafetyAuditSink {
    private(set) var events: [SafetyAuditEvent] = []
    func recordSafetyEvent(_ event: SafetyAuditEvent) async { events.append(event) }
}

@Suite("SafetyCenter — restore manifest capture")
struct RestoreCaptureTests {

    /// A real `FileManager.trashItem` move: the resulting Trash URL must be
    /// captured from the API, not reconstructed, and must actually exist.
    @Test func realTrashMoveEmitsAManifestWithTheActualResultingURL() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("capture-me.txt")
        try Data("hello".utf8).write(to: file)

        let restoreSink = CapturingRestoreSink()
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [dir], regularFilesOnly: true),
            sink: nil, restoreSink: restoreSink)
        let op = try await center.approve(url: file, logicalSize: 5, ruleID: "test.rule", risk: .low)
        let result = await center.execute([op])
        #expect(result.executed.count == 1)

        let records = await restoreSink.records
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.operationID == op.id)
        #expect(record.originalURL.path == file.standardizedFileURL.path)
        #expect(record.ruleID == "test.rule")
        #expect(record.isDirectory == false)
        #expect(FileManager.default.fileExists(atPath: record.trashURL.path),
                "the captured Trash URL must point at the item that is actually there now")
        #expect(record.trashURL.path != file.path, "it moved")
        #expect(record.inode != nil)

        // Clean the item out of the real Trash so the test leaves nothing behind.
        try? FileManager.default.removeItem(at: record.trashURL)
    }

    @Test func directoryTrashMoveEmitsASingleDirectoryManifest() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let subtree = dir.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: subtree, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: subtree.appendingPathComponent("child.bin"))

        let restoreSink = CapturingRestoreSink()
        // A validator that permits a plain directory (Cleanup's dir rules do
        // this via allowedDirectoryExtensions; here the item just needs to be
        // approvable).
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [dir]),
                                  sink: nil, restoreSink: restoreSink)
        let op = try await center.approve(url: subtree, logicalSize: 1, ruleID: "test.dir", risk: .low)
        let result = await center.execute([op])
        #expect(result.executed.count == 1)

        let records = await restoreSink.records
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.isDirectory == true)
        #expect(FileManager.default.fileExists(atPath: record.trashURL.path))
        try? FileManager.default.removeItem(at: record.trashURL)
    }

    /// A non-Trash outcome must NEVER produce a restorable manifest. The
    /// manifest is emitted textually inside the `trashItem`-succeeded branch
    /// only; the `removeItem` permanent-deletion fallback and every skip path
    /// are in `catch`, where `trashURL` is `nil`. Here the file vanishes
    /// before execution, so the op is skipped — and no manifest is written.
    @Test func aSkippedOrPermanentlyRemovedItemGetsNoManifest() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-skip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("ephemeral.txt")
        try Data("gone".utf8).write(to: file)

        let restoreSink = CapturingRestoreSink()
        let center = SafetyCenter(
            validator: PathValidator(allowedRoots: [dir], regularFilesOnly: true),
            sink: nil, restoreSink: restoreSink)
        let op = try await center.approve(url: file, logicalSize: 4, ruleID: "test.skip", risk: .low)
        // The file is gone by the time execute() re-validates it.
        try FileManager.default.removeItem(at: file)
        let result = await center.execute([op])

        #expect(result.executed.isEmpty)
        #expect(await restoreSink.records.isEmpty,
                "nothing was moved to the Trash, so nothing is restorable")
    }

    /// Restore capture is opt-in: with no `RestoreManifestSink` there is no
    /// manifest, even for a perfectly good Trash move. This is why adding the
    /// capability was a no-op for call sites that pass a non-conforming sink.
    @Test func withNoRestoreSinkATrashMoveStillEmitsNothing() async throws {
        actor PlainAudit: SafetyAuditSink {
            func recordSafetyEvent(_ event: SafetyAuditEvent) async {}
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-nosink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("orphan.txt")
        try Data("x".utf8).write(to: file)

        // A plain audit sink that does NOT conform to RestoreManifestSink.
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [dir], regularFilesOnly: true),
                                  sink: PlainAudit())
        let op = try await center.approve(url: file, logicalSize: 1, ruleID: "test.nosink", risk: .low)
        let result = await center.execute([op])
        #expect(result.executed.count == 1)
        // Nothing to assert on a sink we don't have — the point is it does
        // not crash and there is no restore-capture side effect. Clean up.
        if let trash = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask,
                                                    appropriateFor: file, create: false) {
            try? FileManager.default.removeItem(at: trash.appendingPathComponent("orphan.txt"))
        }
    }

    /// A plain `sink:` that also conforms to `RestoreManifestSink` is picked
    /// up automatically — this is what makes every existing call site capture
    /// manifests with no change.
    @Test func aSinkConformingToBothProtocolsIsUsedForRestoreCaptureToo() async throws {
        actor DualSink: SafetyAuditSink, RestoreManifestSink {
            private(set) var manifests = 0
            func recordSafetyEvent(_ event: SafetyAuditEvent) async {}
            func recordRestoreManifest(_ record: RestoreManifestRecord) async { manifests += 1 }
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sc-dual-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("dual.txt")
        try Data("d".utf8).write(to: file)

        let dual = DualSink()
        let center = SafetyCenter(validator: PathValidator(allowedRoots: [dir], regularFilesOnly: true),
                                  sink: dual)
        let op = try await center.approve(url: file, logicalSize: 1, ruleID: "test.dual", risk: .low)
        let result = await center.execute([op])
        #expect(result.executed.count == 1)
        #expect(await dual.manifests == 1)

        // best-effort trash cleanup
        if let trashURL = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask,
                                                       appropriateFor: file, create: false) {
            try? FileManager.default.removeItem(at: trashURL.appendingPathComponent("dual.txt"))
        }
    }
}
