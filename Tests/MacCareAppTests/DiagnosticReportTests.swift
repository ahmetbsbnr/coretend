import Testing
import Foundation
@testable import MacCareApp

@Suite("Diagnostic report redaction")
struct DiagnosticReportTests {
    /// Fixture deliberately includes sensitive-looking strings (a fake
    /// username, a fake full path, a fake installed-app name) nowhere in
    /// the Inputs struct — the report is built only from Inputs fields, so
    /// this test fails if a future edit starts interpolating raw strings
    /// (e.g. a real path) into the report body.
    @Test("report never contains injected sensitive strings")
    func reportExcludesSensitiveData() {
        let sensitiveUsername = "jsmith1985"
        let sensitivePath = "/Users/jsmith1985/Documents/TaxReturns2024.pdf"
        let sensitiveApp = "SuperSecretDatingApp.app"

        let inputs = DiagnosticReport.Inputs(
            appVersion: "0.7.0", appBuild: "42", macOSVersion: "Version 15.1 (Build 24B83)",
            architecture: "arm64", machineModel: "Mac15,6", deploymentTarget: "macOS 14+",
            fullDiskAccess: true, clamAVAvailable: true, clamAVPath: "/opt/homebrew/bin/clamscan",
            schemaVersion: 3, exclusionCount: 2,
            activityCountsByKind: ["scan": 10, "cleanup": 4, "restore": 1, "error": 0])

        let report = DiagnosticReport.build(inputs)

        #expect(!report.contains(sensitiveUsername))
        #expect(!report.contains(sensitivePath))
        #expect(!report.contains(sensitiveApp))
        #expect(!report.contains(NSHomeDirectory()))
        #expect(!report.contains(NSUserName()))
        #expect(!report.contains(Host.current().localizedName ?? "\u{0}unlikely\u{0}"))

        // Positive checks: the safe fields are actually present.
        #expect(report.contains("0.7.0"))
        #expect(report.contains("Mac15,6"))
        #expect(report.contains("Exclusion count: 2"))
    }

    @Test("redactPath strips the real home directory and username")
    func redactPathStripsHome() {
        let home = NSHomeDirectory()
        let path = home + "/Library/Application Support/MacCareLocal/store.sqlite"
        let redacted = DiagnosticReport.redactPath(path)
        #expect(!redacted.contains(home))
        #expect(redacted.hasPrefix("<home>"))
    }

    @Test("redactPath strips arbitrary /Users/<name> paths")
    func redactPathStripsUsersName() {
        let redacted = DiagnosticReport.redactPath("/Users/jsmith1985/Documents/secret.txt")
        #expect(!redacted.contains("jsmith1985"))
        #expect(redacted.contains("<redacted>"))
        #expect(redacted.contains("secret.txt")) // filename shape kept, identity stripped
    }
}
