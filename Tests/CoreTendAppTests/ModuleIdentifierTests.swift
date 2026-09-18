// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Every module must be addressable from a shell argument.
///
/// This exists because of a silent verification failure, not a user-facing one.
/// `capture-module.sh` passed identifiers like "spaceLens" and "applications";
/// `ModuleID`'s raw values are "Space Lens" and "Applications";
/// `ModuleID(rawValue:)` returned nil; the app fell back to the Dashboard. So
/// every screenshot taken to verify eleven different modules was the same
/// screenshot, and the pixel check run against them all passed — because the
/// Dashboard renders correctly.
///
/// A verification tool that silently checks the wrong thing is worse than no
/// tool, because it produces confident, wrong reports. These tests make the
/// mapping an asserted contract instead of a guess.
@Suite("Module identifiers")
struct ModuleIdentifierTests {

    @Test func everyModuleResolvesFromItsRawValue() {
        for module in ModuleID.allCases {
            #expect(ModuleID(testIdentifier: module.rawValue) == module)
        }
    }

    /// The Swift case name is what anyone writing a script will reach for
    /// first, since it is what appears in the source.
    @Test func everyModuleResolvesFromItsCaseName() {
        for module in ModuleID.allCases {
            let caseName = String(describing: module)
            #expect(ModuleID(testIdentifier: caseName) == module,
                    "\(caseName) does not resolve — a script using it would silently get the Dashboard")
        }
    }

    @Test func matchingIgnoresCaseAndSpaces() {
        #expect(ModuleID(testIdentifier: "space lens") == .spaceLens)
        #expect(ModuleID(testIdentifier: "SPACELENS") == .spaceLens)
        #expect(ModuleID(testIdentifier: "  Smart Care  ") == .smartCare)
        #expect(ModuleID(testIdentifier: "myclutter") == .myClutter)
    }

    /// An unknown identifier must resolve to nil rather than to something
    /// plausible. Falling back to a module would recreate the original bug in a
    /// new shape.
    @Test func anUnknownIdentifierResolvesToNothing() {
        #expect(ModuleID(testIdentifier: "storage-lens") == nil)
        #expect(ModuleID(testIdentifier: "") == nil)
        #expect(ModuleID(testIdentifier: "dashboard") == nil,
                "\"dashboard\" is a label, not an identity — smartCare is the case")
    }

    /// No two modules may share a normalized identifier, or one of them becomes
    /// unreachable from a script.
    @Test func normalizedIdentifiersAreUnique() {
        var seen = Set<String>()
        for module in ModuleID.allCases {
            let normalized = module.rawValue.replacingOccurrences(of: " ", with: "").lowercased()
            #expect(seen.insert(normalized).inserted, "duplicate identifier: \(normalized)")
        }
    }
}
