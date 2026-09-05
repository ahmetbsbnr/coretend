// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import FinderShared

// MARK: - Selection classification (pure, URL-only)

@Suite("FinderSelectionClassifier — bounded single-item attributes")
struct FinderClassificationTests {
    private func fixture(_ name: String, directory: Bool = false, check: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("finder-menu-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let item = root.appendingPathComponent(name)
        if directory { try FileManager.default.createDirectory(at: item, withIntermediateDirectories: true) }
        else { try Data().write(to: item) }
        try check(item)
    }

    @Test func aFolderOffersOnlyScanFolder() throws {
        try fixture("Folder", directory: true) { url in
            #expect(FinderSelectionClassifier.actions(for: url) == [.scanFolder])
        }
    }
    @Test func anAppBundleOffersOnlyIntegrity() throws {
        try fixture("Demo.app", directory: true) { url in
            #expect(FinderSelectionClassifier.actions(for: url) == [.inspectApplication])
        }
        try fixture("fake.app") { url in #expect(FinderSelectionClassifier.actions(for: url).isEmpty) }
    }
    @Test func aSupportedImageOffersOnlyInspectImage() throws {
        for ext in ["jpg", "JPG", "png", "heic", "dng", "cr3"] {
            try fixture("photo.\(ext)") { url in
                #expect(FinderSelectionClassifier.actions(for: url) == [.inspectImage])
            }
        }
    }
    @Test func unsupportedAndMissingFilesOfferNothing() throws {
        try fixture("note.txt") { url in
            #expect(FinderSelectionClassifier.actions(for: url).isEmpty)
            #expect(FinderSelectionClassifier.actions(for: url.appendingPathComponent("missing.jpg")).isEmpty)
        }
        #expect(FinderSelectionClassifier.actions(for: URL(string: "https://example.com/photo.jpg")!).isEmpty)
    }
    @Test func emptyAndMultipleSelectionsOfferNothing() throws {
        #expect(FinderSelectionClassifier.actions(for: [URL]()).isEmpty)
        try fixture("photo.jpg") { url in
            #expect(FinderSelectionClassifier.actions(for: [url, url]).isEmpty)
        }
    }
    @Test func symlinkOffersNothing() throws {
        try fixture("photo.jpg") { url in
            let link = url.deletingLastPathComponent().appendingPathComponent("alias.jpg")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url)
            #expect(FinderSelectionClassifier.actions(for: link).isEmpty)
        }
    }
}

// MARK: - coretend:// handoff URL round-trip

@Suite("FinderHandoffURL — build and parse the coretend:// handoff")
struct FinderHandoffURLTests {
    @Test func roundTripsEachActionWithItsPath() {
        for action in FinderAction.allCases {
            let path = "/Users/x/Pictures/Ren\u{00e9}e's holiday.jpg"
            let url = try! #require(FinderHandoffURL.make(action: action, path: path))
            #expect(url.scheme == "coretend")
            #expect(url.host == "finder")
            let parsed = try! #require(FinderHandoffURL.parse(url))
            #expect(parsed.action == action)
            #expect(parsed.path == path)   // percent-decoding restores the exact path
        }
    }

    @Test func rejectsAMalformedOrHostileURL() {
        let bad = [
            "https://finder/scan-folder?path=/tmp",              // wrong scheme
            "coretend://elsewhere/scan-folder?path=/tmp",        // wrong host
            "coretend://finder/wipe-disk?path=/tmp",             // unknown action
            "coretend://finder/scan-folder",                     // no path
            "coretend://finder/scan-folder?path=relative/dir",   // not absolute
            "coretend://finder/scan-folder?path=/a/../../etc",   // traversal component
            "coretend://finder/scan-folder?path=//evil",
            "coretend://user@finder/scan-folder?path=/tmp",
            "coretend://finder:80/scan-folder?path=/tmp",
            "coretend://finder/scan-folder?path=/tmp#extra",
            "coretend://finder//scan-folder?path=/tmp",
            "coretend://finder/scan-folder?path=/tmp&path=/other",
            "coretend://finder/scan-folder?path=/tmp&extra=x",         // double slash
        ]
        for s in bad {
            #expect(FinderHandoffURL.parse(URL(string: s)!) == nil, "\(s)")
        }
    }

    @Test func rejectsAnOversizedPathBothWays() {
        let huge = "/" + String(repeating: "a", count: FinderHandoffURL.maxPathLength + 1)
        #expect(FinderHandoffURL.make(action: .scanFolder, path: huge) == nil)
        // And if one is hand-crafted, parse still refuses it.
        var c = URLComponents()
        c.scheme = "coretend"; c.host = "finder"; c.path = "/scan-folder"
        c.queryItems = [URLQueryItem(name: "path", value: huge)]
        #expect(FinderHandoffURL.parse(c.url!) == nil)
    }

    @Test func rejectsEmbeddedControlCharacters() {
        #expect(FinderHandoffURL.make(action: .inspectImage, path: "/Users/x/a\nb.jpg") == nil)
        #expect(FinderHandoffURL.make(action: .inspectImage, path: "/Users/x/a\u{0}b.jpg") == nil)
    }
}

// MARK: - Read-only selection validator (touches a synthetic FS only)

@Suite("SelectionValidator — read-only, re-checked against the live filesystem")
struct SelectionValidatorTests {
    private func makeSandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-val-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func acceptsARealUserFolderForScan_evenUnderDocuments() throws {
        let root = try makeSandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let docs = root.appendingPathComponent("Documents/Trip")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        // A cleanup-path validator would reject ~/Documents; this one must not.
        #expect((try? SelectionValidator.validate(path: docs.path, for: .scanFolder).get()) != nil)
    }

    @Test func rejectsAFileWhenTheActionExpectsAFolder_andViceVersa() throws {
        let root = try makeSandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("photo.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: file)
        #expect(SelectionValidator.validate(path: file.path, for: .scanFolder) == .failure(.wrongKind))
        #expect(SelectionValidator.validate(path: root.path, for: .inspectImage) == .failure(.wrongKind))
        // .inspectApplication needs a *.app directory.
        #expect(SelectionValidator.validate(path: root.path, for: .inspectApplication) == .failure(.wrongKind))
    }

    @Test func acceptsAnAppBundleForIntegrity() throws {
        let root = try makeSandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Demo.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        #expect((try? SelectionValidator.validate(path: app.path, for: .inspectApplication).get()) == app.standardizedFileURL)
    }

    @Test func rejectsAVanishedPath() throws {
        let root = try makeSandbox()
        let gone = root.appendingPathComponent("was-here")
        try FileManager.default.createDirectory(at: gone, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: root)
        #expect(SelectionValidator.validate(path: gone.path, for: .scanFolder) == .failure(.doesNotExist))
    }

    @Test func rejectsScanningAProtectedSystemRoot() {
        #expect(SelectionValidator.validate(path: "/", for: .scanFolder) == .failure(.systemLocation))
        #expect(SelectionValidator.validate(path: "/System/Library", for: .scanFolder) == .failure(.systemLocation))
        #expect(SelectionValidator.validate(path: "/usr/lib", for: .scanFolder) == .failure(.systemLocation))
    }

    @Test func rejectsRelativeOrTraversalPaths() {
        #expect(SelectionValidator.validate(path: "relative", for: .scanFolder) == .failure(.notAbsolute))
        #expect(SelectionValidator.validate(path: "/a/../b", for: .scanFolder) == .failure(.containsTraversal))
    }

    @Test func aSymlinkedFolderWhoseTargetIsSystemIsRejectedForScan() throws {
        let root = try makeSandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("shortcut")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/System")
        #expect(SelectionValidator.validate(path: link.path, for: .scanFolder) == .failure(.symlinkEscapesToSystem))
    }
}

// MARK: - Localization parity

@Suite("FinderShared — EN/FR menu-label parity")
struct FinderLocalizationParityTests {
    private func keys(_ folder: String) throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/FinderShared/Resources/\(folder).lproj/Localizable.strings")
        var used = String.Encoding.utf8
        let text = try String(contentsOf: url, usedEncoding: &used)   // UTF-16 BE per .gitattributes
        var found: Set<String> = []
        for line in text.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("\"") else { continue }
            if let end = t.dropFirst().firstIndex(of: "\"") {
                found.insert(String(t[t.index(after: t.startIndex)..<end]))
            }
        }
        return found
    }

    @Test func baseAndFrenchDeclareTheExactSameKeys() throws {
        let base = try keys("Base")
        let fr = try keys("fr")
        #expect(base == fr, "only in Base \(base.subtracting(fr)); only in fr \(fr.subtracting(base))")
        #expect(base.count == 4)
    }

    @Test func everyMenuKeyResolvesInBothLanguages() {
        for key in ["finder.menu.scan_folder", "finder.menu.inspect_image",
                    "finder.menu.inspect_application", "finder.menu.open"] {
            #expect(FL(key) != key, "\(key) does not resolve in Bundle.module")
        }
    }
}
