import Foundation
import Testing
@testable import IntegrityCore

@Suite("ProvenanceScanner")
struct ProvenanceScannerTests {
    @Test("a plain file with no quarantine attribute reports isQuarantined == false")
    func noQuarantine() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("plain.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].isQuarantined == false)
        #expect(results[0].sourceURL == nil)
    }

    @Test("a file carrying LSQuarantine metadata is reported as quarantined, with the fields the xattr actually stores")
    func withQuarantine() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var file = dir.appendingPathComponent("downloaded.dmg")
        try "bytes".write(to: file, atomically: true, encoding: .utf8)

        // The `com.apple.quarantine` xattr itself only ever holds flag,
        // timestamp, agent and an event UUID. The origin/data URLs a real
        // download carries live in LaunchServices' separate quarantine-events
        // database, keyed by that UUID — populated by a browser's real
        // download registration, not by `setResourceValues` from a
        // command-line test binary with no app-level LaunchServices context.
        // So only the xattr-backed fields are asserted here; a real download's
        // origin URL is what Downloads actually shows once a browser creates
        // the file, which this synthetic unit test cannot reproduce.
        var values = URLResourceValues()
        values.quarantineProperties = [
            "LSQuarantineAgentName": "Safari",
        ]
        try file.setResourceValues(values)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].isQuarantined == true)
        #expect(results[0].agentName == "Safari")
    }

    @Test("directories are excluded, only regular files are reported")
    func skipsDirectories() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try FileManager.default.createDirectory(at: dir.appendingPathComponent("subfolder"), withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].name == "file.txt")
    }

    @Test("a missing folder returns an empty list rather than throwing")
    func missingFolder() {
        let results = ProvenanceScanner.scan(folder: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)"))
        #expect(results.isEmpty)
    }

    @Test("limit caps the number of results")
    func respectsLimit() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        for i in 0..<10 {
            try "x".write(to: dir.appendingPathComponent("f\(i).txt"), atomically: true, encoding: .utf8)
        }
        let results = ProvenanceScanner.scan(folder: dir, limit: 3)
        #expect(results.count == 3)
    }

    @Test("malformed quarantine metadata (raw bytes the OS can't parse as quarantine properties) is treated as not-quarantined, never crashes")
    func malformedQuarantineMetadata() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("garbage.bin")
        try "y".write(to: file, atomically: true, encoding: .utf8)

        // Written below the clean URLResourceValues API on purpose: that setter
        // crashes the whole process with an uncaught NSInvalidArgumentException
        // when given a malformed/wrongly-typed dictionary (verified separately,
        // not covered here since it can't be caught from Swift at all). Raw
        // setxattr is how a real malformed attribute would actually get there —
        // a corrupted write, not a value this scanner ever constructs itself —
        // and it's what exercises the read path IntegrityCore actually uses.
        let garbage = "not-a-valid-quarantine-string-####"
        let rc = garbage.withCString { ptr in
            setxattr(file.path, "com.apple.quarantine", ptr, strlen(ptr), 0, 0)
        }
        #expect(rc == 0)

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.count == 1)
        #expect(results[0].isQuarantined == false)
    }

    @Test("an unreadable folder (permission denied) returns an empty list rather than throwing")
    func permissionDeniedFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("hidden.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: dir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }

        let results = ProvenanceScanner.scan(folder: dir)
        #expect(results.isEmpty)
    }
}

@Suite("CodeSignInspector")
struct CodeSignInspectorTests {
    @Test("a system app is reported as Apple-signed and valid")
    func appleSystemApp() {
        // /System/Applications/Calculator.app exists on every supported macOS version.
        let info = CodeSignInspector.inspect(at: URL(fileURLWithPath: "/System/Applications/Calculator.app"))
        #expect(info.tier == .appleSigned)
        #expect(info.signatureValid == true)
    }

    @Test("a nonexistent path is reported unsigned, never crashes")
    func missingPath() {
        let info = CodeSignInspector.inspect(at: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).app"))
        #expect(info.tier == .adHocOrUnsigned)
        #expect(info.signatureValid == false)
    }

    @Test("a freshly-written plain file (no signature at all) is unsigned")
    func plainFileIsUnsigned() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bin")
        try "not a bundle".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let info = CodeSignInspector.inspect(at: file)
        #expect(info.tier == .adHocOrUnsigned)
        #expect(info.signatureValid == false)
    }

    @Test("a binary actually signed ad hoc (codesign -s -) is adHocOrUnsigned but its signature validates — distinct from having no signature at all")
    func validAdHocSignature() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/echo"), to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let sign = Process()
        sign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        sign.arguments = ["-s", "-", "-f", file.path]
        sign.standardOutput = FileHandle.nullDevice
        sign.standardError = FileHandle.nullDevice
        try sign.run()
        sign.waitUntilExit()
        #expect(sign.terminationStatus == 0)

        let info = CodeSignInspector.inspect(at: file)
        #expect(info.tier == .adHocOrUnsigned)
        #expect(info.signatureValid == true)
    }

    @Test("a directory named *.app with no real bundle contents does not crash and reports unsigned")
    func corruptedBundle() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try "not a plist".write(to: bundle.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: bundle) }

        let info = CodeSignInspector.inspect(at: bundle)
        #expect(info.tier == .adHocOrUnsigned)
        #expect(info.signatureValid == false)
    }

    @Test(
        "a Developer ID / other team-signed binary is reported teamSigned",
        .enabled(if: hasNonAppleCodesigningIdentity(), "requires a non-Apple codesigning identity in the keychain — none installed in this environment (see Documentation/HUMAN_BLOCKERS.md, Configuration/DeveloperID/)")
    )
    func teamSignedBinary() throws {
        // Intentionally has no fixture-construction code: the whole point of
        // this test is that it can only run against a real, keychain-resident,
        // non-Apple signing identity, which this environment does not have.
        // Faking one would test nothing real; skipping honestly is the correct
        // outcome until Configuration/DeveloperID's CSR becomes an installed
        // Developer ID Application certificate.
        Issue.record("This test should have been skipped by .enabled(if:) — it cannot construct its own signing identity.")
    }
}

/// True if `security find-identity -v -p codesigning` reports at least one
/// identity that isn't just "0 valid identities found". Shells out rather than
/// using the Security framework directly because enumerating *installed*
/// identities (as opposed to validating a given one) is what the `security`
/// CLI is for; this only gates whether teamSignedBinary can mean anything.
private func hasNonAppleCodesigningIdentity() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    task.arguments = ["find-identity", "-v", "-p", "codesigning"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    guard (try? task.run()) != nil else { return false }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""
    return !output.contains("0 valid identities found")
}

@Suite("LoginItemScanner")
struct LoginItemScannerTests {
    @Test("scanning never throws and returns items with a non-empty label")
    func scanIsSafeAndLabeled() {
        let items = LoginItemScanner.scan()
        for item in items {
            #expect(!item.label.isEmpty)
            #expect(!item.plistPath.isEmpty)
        }
    }

    @Test("a well-formed plist in a controlled (non-real) location is parsed with the right label, program and scope")
    func validLaunchAgent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let plist: [String: Any] = [
            "Label": "com.example.testagent",
            "ProgramArguments": ["/usr/bin/true"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: dir.appendingPathComponent("com.example.testagent.plist"))

        let items = LoginItemScanner.scan(locations: [(dir, .userAgent)])
        #expect(items.count == 1)
        #expect(items[0].label == "com.example.testagent")
        #expect(items[0].programPath == "/usr/bin/true")
        #expect(items[0].scope == .userAgent)
    }

    @Test("a malformed plist (not valid property-list data) is skipped, never crashes")
    func malformedPlist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "not a plist at all".write(to: dir.appendingPathComponent("broken.plist"), atomically: true, encoding: .utf8)

        let items = LoginItemScanner.scan(locations: [(dir, .userAgent)])
        #expect(items.isEmpty)
    }

    @Test("a location that doesn't exist yields an empty list rather than throwing")
    func missingLocation() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        let items = LoginItemScanner.scan(locations: [(missing, .globalDaemon)])
        #expect(items.isEmpty)
    }

    @Test("an unreadable location (permission denied) yields an empty list rather than throwing")
    func permissionDeniedLocation() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("x.plist"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: dir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }

        let items = LoginItemScanner.scan(locations: [(dir, .globalAgent)])
        #expect(items.isEmpty)
    }

    @Test("a plist reached via a symlink is followed and parsed like any other file")
    func symlinkedPlist() throws {
        let real = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let scanned = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scanned, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: real)
            try? FileManager.default.removeItem(at: scanned)
        }

        let plist: [String: Any] = ["Label": "com.example.symlinked", "Program": "/usr/bin/true"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let realFile = real.appendingPathComponent("com.example.symlinked.plist")
        try data.write(to: realFile)
        let link = scanned.appendingPathComponent("com.example.symlinked.plist")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realFile)

        let items = LoginItemScanner.scan(locations: [(scanned, .userAgent)])
        #expect(items.count == 1)
        #expect(items[0].label == "com.example.symlinked")
    }
}
