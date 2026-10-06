// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Persistence availability is explicit")
struct PersistenceAvailabilityTests {
    @Test("a resolved database path is reported as persistent")
    func durableStore() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coretend-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = StoreBootstrap.open {
            root.appendingPathComponent("store.sqlite").path
        }

        #expect(result.availability == .persistent)
        #expect(result.store.map { _ in true } == true)
    }

    @Test("a default-path failure is reported as temporary memory storage")
    func memoryFallbackIsVisible() {
        let result = StoreBootstrap.open {
            throw FixtureError.noWritableApplicationSupport
        }

        #expect(result.availability == .temporary)
        #expect(result.store.map { _ in true } == true)
    }

    @Test("a database-open failure is reported unavailable without a memory fallback")
    func failedDatabaseOpenFailsClosed() {
        let result = StoreBootstrap.open { "/" }

        #expect(result.availability == .unavailable)
        #expect(result.store == nil)
    }

    @Test("only non-persistent states have warning copy")
    func warningsMatchAvailability() {
        #expect(PersistenceAvailability.persistent.warningKey == nil)
        #expect(PersistenceAvailability.temporary.warningKey != nil)
        #expect(PersistenceAvailability.unavailable.warningKey != nil)
        #expect(PersistenceAvailability.degraded.warningKey != nil)
    }

    @Test("a missing store keeps the explicit unavailable warning")
    func unavailableStateDoesNotBecomeGenericDegradedState() {
        #expect(PersistenceAvailability.unavailable.afterPersistenceFailure == .unavailable)
        #expect(PersistenceAvailability.persistent.afterPersistenceFailure == .degraded)
        #expect(PersistenceAvailability.temporary.afterPersistenceFailure == .degraded)
        #expect(PersistenceAvailability.degraded.afterPersistenceFailure == .degraded)
    }

    private enum FixtureError: Error {
        case noWritableApplicationSupport
    }
}
