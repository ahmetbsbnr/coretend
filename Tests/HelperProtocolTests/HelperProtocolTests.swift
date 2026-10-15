import XCTest
@testable import HelperProtocol

final class HelperProtocolTests: XCTestCase {
    func testDisabledLabelsReadBothSpellings() {
        let output = """
        disabled services = {
        \t"com.example.off" => disabled
        \t"com.example.on" => enabled
        \t"com.example.old" => true
        \t"com.example.oldon" => false
        }
        """
        XCTAssertEqual(LaunchctlOutput.disabledLabels(output), ["com.example.off", "com.example.old"])
    }

    func testDisabledLabelsIgnoreNoise() {
        XCTAssertTrue(LaunchctlOutput.disabledLabels("").isEmpty)
        XCTAssertTrue(LaunchctlOutput.disabledLabels("disabled services = {\n}\n").isEmpty)
    }

    func testSnapshotDatesAreReadExactlyAndAnythingElseIsRefused() {
        let output = "Snapshot dates for disk /:\n2026-10-15-120000\n 2026-10-14-083015 \n2026-10-15-12000\n../../etc\n"
        XCTAssertEqual(TmutilOutput.snapshotDates(output), ["2026-10-15-120000", "2026-10-14-083015"])
        XCTAssertTrue(TmutilOutput.snapshotDates("Snapshot dates for disk /:\n").isEmpty)
        for refused in ["2026-10-15-120000 --all", "-a", "2026-10-15", "2026-10-15-120000\n2026-10-14-083015", ""] {
            XCTAssertFalse(TmutilOutput.isSnapshotDate(refused), refused)
        }
        XCTAssertEqual(HelperIdentity.version, "2", "a helper without the snapshot and Spotlight requests is told apart")
    }

    func testRequirementsNameTheTeamAndBothEnds() {
        XCTAssertTrue(HelperIdentity.clientRequirement.contains(#"identifier "com.ahmetbsbnr.coretend""#))
        XCTAssertTrue(HelperIdentity.helperRequirement.contains(#"identifier "com.ahmetbsbnr.coretend.helper""#))
        for requirement in [HelperIdentity.clientRequirement, HelperIdentity.helperRequirement] {
            XCTAssertTrue(requirement.contains("anchor apple generic"))
            XCTAssertTrue(requirement.contains(HelperIdentity.teamIdentifier))
        }
    }
}
