// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import Persistence

@Suite("Database query failures")
struct DatabaseTests {
    @Test func excessBindingsCannotSilentlyWrite() throws {
        let db = try Database(path: ":memory:")
        try db.exec("CREATE TABLE records (value INTEGER)")
        #expect(throws: DatabaseError.self) {
            try db.run("INSERT INTO records VALUES (?)", [1, 2])
        }
        #expect(try db.query("SELECT * FROM records").isEmpty)
        try db.run("INSERT INTO records VALUES (?)", [42])
        #expect(try db.query("SELECT value FROM records").first?["value"] as? Int64 == 42)
    }

    @Test func failureAfterFirstRowDoesNotReturnPartialResults() throws {
        let db = try Database(path: ":memory:")
        // SQLite produces one row, then abs(Int64.min) fails at sqlite3_step,
        // not prepare. Returning the first row would hide a failed read.
        #expect(throws: DatabaseError.self) {
            try db.query("SELECT 1 AS value UNION ALL SELECT abs(-9223372036854775808)")
        }
        // The failed statement must be finalized; this connection remains usable.
        let rows = try db.query("SELECT 42 AS value")
        #expect(rows.count == 1)
        #expect(rows.first?["value"] as? Int64 == 42)
    }

    @Test func emptyQueryIsSuccessful() throws {
        let db = try Database(path: ":memory:")
        #expect(try db.query("SELECT 1 WHERE 0").isEmpty)
    }
}
