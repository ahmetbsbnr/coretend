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

    func testRequirementsNameTheTeamAndBothEnds() {
        XCTAssertTrue(HelperIdentity.clientRequirement.contains(#"identifier "com.ahmetbsbnr.coretend""#))
        XCTAssertTrue(HelperIdentity.helperRequirement.contains(#"identifier "com.ahmetbsbnr.coretend.helper""#))
        for requirement in [HelperIdentity.clientRequirement, HelperIdentity.helperRequirement] {
            XCTAssertTrue(requirement.contains("anchor apple generic"))
            XCTAssertTrue(requirement.contains(HelperIdentity.teamIdentifier))
        }
    }
}
