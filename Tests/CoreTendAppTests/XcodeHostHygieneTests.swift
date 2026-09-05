// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation

/// The Xcode shipping host is checked in (generated from `project.yml` by
/// xcodegen). These tests guard the properties that matter for a shared,
/// reproducible project: relative paths only, the widget target and App
/// Group entitlement present, and the widget source linking nothing that
/// could scan or delete.
@Suite("Xcode host + Widget — repository hygiene")
struct XcodeHostHygieneTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func read(_ rel: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

    @Test func theXcodegenManifestAndGeneratedProjectBothExist() {
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("project.yml").path))
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("CoreTend.xcodeproj/project.pbxproj").path))
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("CoreTend.xcodeproj/xcshareddata/xcschemes/CoreTend-App.xcscheme").path))
    }

    @Test func theProjectDeclaresBothTheAppAndTheWidgetExtension() throws {
        let pbx = try read("CoreTend.xcodeproj/project.pbxproj")
        #expect(pbx.contains("com.apple.product-type.application"))
        #expect(pbx.contains("com.apple.product-type.app-extension"))
        #expect(pbx.contains("CoreTendWidget"))
        #expect(pbx.contains("com.ahmetbsbnr.coretend.widget"))
    }

    @Test func noCommittedXcodeFileCarriesAnAbsoluteDeveloperPath() throws {
        for file in ["CoreTend.xcodeproj/project.pbxproj",
                     "CoreTend.xcodeproj/project.xcworkspace/contents.xcworkspacedata",
                     "CoreTend.xcodeproj/xcshareddata/xcschemes/CoreTend-App.xcscheme",
                     "project.yml"] {
            let text = try read(file)
            #expect(!text.contains("/Users/"), "\(file) contains an absolute /Users path")
            #expect(!text.contains(NSHomeDirectory()), "\(file) contains the build machine's home path")
        }
    }

    @Test func noXcuserdataOrUserStateIsCommitted() {
        let fm = FileManager.default
        let proj = root.appendingPathComponent("CoreTend.xcodeproj")
        let enumerator = fm.enumerator(at: proj, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            #expect(!url.path.contains("xcuserdata"), "committed xcuserdata: \(url.lastPathComponent)")
            #expect(url.pathExtension != "xcuserstate")
        }
    }

    @Test func hostAndWidgetShareTheExactSameAppGroupEntitlement() throws {
        let group = "group.com.ahmetbsbnr.coretend"
        let host = try read("Configuration/CoreTend.entitlements")
        let widget = try read("Configuration/CoreTendWidget.entitlements")
        #expect(host.contains("com.apple.security.application-groups"))
        #expect(host.contains(group))
        #expect(widget.contains("com.apple.security.application-groups"))
        #expect(widget.contains(group))
        // The widget extension is sandboxed; the host is not.
        #expect(widget.contains("com.apple.security.app-sandbox"))
        #expect(!host.contains("com.apple.security.app-sandbox"))
    }

    /// Removes XML `<!-- ... -->` comments so the entitlement files' own
    /// prose (which names capabilities it deliberately does NOT grant)
    /// doesn't trip the check.
    private func stripXMLComments(_ text: String) -> String {
        var out = text
        while let start = out.range(of: "<!--"),
              let end = out.range(of: "-->", range: start.upperBound..<out.endIndex) {
            out.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return out
    }

    @Test func entitlementsStayMinimal_noSpeculativeCapabilities() throws {
        for file in ["Configuration/CoreTend.entitlements", "Configuration/CoreTendWidget.entitlements"] {
            let text = stripXMLComments(try read(file))
            for forbidden in ["com.apple.developer.icloud", "aps-environment",
                              "com.apple.developer.networking", "com.apple.security.cs.",
                              "com.apple.developer.system-extension"] {
                #expect(!text.contains(forbidden), "\(file) adds a speculative capability: \(forbidden)")
            }
        }
    }

    @Test func theWidgetExtensionInfoPlistIsAWidgetKitExtension() throws {
        let plist = try read("WidgetExtension/Info.plist")
        #expect(plist.contains("com.apple.widgetkit-extension"))
    }

    @Test func theWidgetSourceLinksNothingThatCouldScanOrDelete() throws {
        let source = try read("WidgetExtension/CoreTendWidget.swift")
        // Strip // comments (the header names the modules it must not import).
        let code = source.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            if let r = line.range(of: "//") { return String(line[line.startIndex..<r.lowerBound]) }
            return String(line)
        }.joined(separator: "\n")
        for forbidden in ["import ScanCore", "import SafetyCore", "import FileRules",
                          "import Persistence", "import AppDiscovery", "import IntegrityCore",
                          "import CoreTendApp", "ScanEngine", "SafetyCenter", "RestoreService",
                          "RecoveryPlanService", "DeveloperCenterService", "trashItem"] {
            #expect(!code.contains(forbidden), "widget source references \(forbidden)")
        }
        // What it IS allowed to link.
        #expect(code.contains("import WidgetShared"))
    }
}
