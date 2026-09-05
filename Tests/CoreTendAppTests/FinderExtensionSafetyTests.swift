// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation

/// The primary safety proof for the Finder Sync extension is structural:
///
///   CoreTendFinder  →  FinderShared only  →  no link to any destructive
///   module.
///
/// These tests enforce that at the dependency level (project.yml) and,
/// belt-and-braces, at the source level (a comment-stripped grep of the
/// extension's one source file). They do NOT rely on an `if destructive`
/// runtime guard — there is no such guard, and there is nothing to guard.
@Suite("Finder Sync extension — cannot execute destructive code")
struct FinderExtensionSafetyTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

    /// Strip `//` line comments so the file header (which names the modules
    /// it must not import) doesn't trip the grep.
    private func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            if let r = line.range(of: "//") { return String(line[line.startIndex..<r.lowerBound]) }
            return String(line)
        }.joined(separator: "\n")
    }

    @Test func theFinderTargetDependsOnFinderSharedAndNothingDestructive() throws {
        let yml = try read("project.yml")
        // Find the CoreTendFinder target block.
        guard let range = yml.range(of: "CoreTendFinder:\n    type: app-extension") else {
            Issue.record("CoreTendFinder target block not found in project.yml"); return
        }
        let block = String(yml[range.lowerBound...].components(separatedBy: "\nschemes:")[0])
        #expect(block.contains("product: FinderShared"))
        for forbidden in ["ScanCore", "SafetyCore", "FileRules", "Persistence",
                          "AppDiscovery", "IntegrityCore", "CoreTendApp", "WidgetShared"] {
            #expect(!block.contains("product: \(forbidden)"),
                    "Finder target links \(forbidden) — it must link only FinderShared")
        }
    }

    @Test func theFinderExtensionSourceReferencesNoDestructiveAPI() throws {
        let sources = ["FinderExtension/CoreTendFinder.swift"] +
            (try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Sources/FinderShared").path))
                .filter { $0.hasSuffix(".swift") }.map { "Sources/FinderShared/" + $0 }
        let code = try sources.map { codeOnly(try read($0)) }.joined(separator: "\n")
        for forbidden in [
            // no destructive-domain modules
            "import ScanCore", "import SafetyCore", "import FileRules",
            "import Persistence", "import AppDiscovery", "import IntegrityCore",
            "import CoreTendApp", "import WidgetShared",
            // no destructive API surface
            "trashItem", "removeItem", "FileManager.default.remove",
            "SafetyCenter", "RecoveryPlanService", "RestoreService",
            "CleanupExecution", "DeveloperCenterService", "PathValidator",
            // no file-content inspection in the extension
            "ImageMetadataInspector", "CodeSignInspector", "CGImageSource",
            "contentsOfDirectory", "enumerator(at",
        ] {
            #expect(!code.contains(forbidden),
                    "Finder extension source references \(forbidden)")
        }
        // What it IS allowed to link.
        #expect(code.contains("import FinderShared"))
        #expect(code.contains("import FinderSync"))
    }

    @Test func theFinderSharedModuleItselfHasNoDependencies() throws {
        let pkg = try read("Package.swift")
        #expect(pkg.contains(".target(name: \"FinderShared\", resources: [.process(\"Resources\")])"),
                "FinderShared must be a Foundation-only target with no dependencies")
    }

    @Test func theFinderExtensionDoesNotReadFileContents() throws {
        // Bounded item attributes are allowed; contents and traversal are not.
        let code = try read("FinderExtension/CoreTendFinder.swift")
        #expect(!code.contains("Data(contentsOf"))
        #expect(!code.contains("String(contentsOf"))
        #expect(!code.contains(".read("))
        #expect(!code.contains("contentsOfDirectory"))
    }
}
