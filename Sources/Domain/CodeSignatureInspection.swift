import Foundation
import Security

public enum CodeSignatureState: Sendable, Equatable { case valid, invalid, unavailable }

public struct CodeSignatureReport: Sendable, Equatable {
    public let state: CodeSignatureState
    public let identifier: String?
    public let teamIdentifier: String?
    public let statusCode: Int32
    public init(state: CodeSignatureState, identifier: String?, teamIdentifier: String?, statusCode: Int32) {
        self.state = state; self.identifier = identifier; self.teamIdentifier = teamIdentifier; self.statusCode = statusCode
    }
}

public protocol CodeSignatureInspecting: Sendable { func inspect(at applicationURL: URL) -> CodeSignatureReport }

public struct MacOSCodeSignatureInspector: CodeSignatureInspecting {
    public init() {}
    public func inspect(at applicationURL: URL) -> CodeSignatureReport {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(applicationURL as CFURL, SecCSFlags(rawValue: 0), &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return CodeSignatureReport(state: .unavailable, identifier: nil, teamIdentifier: nil, statusCode: createStatus)
        }
        var information: CFDictionary?
        let informationStatus = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
        let values = information as? [String: Any]
        let identifier = values?[kSecCodeInfoIdentifier as String] as? String
        let teamIdentifier = values?[kSecCodeInfoTeamIdentifier as String] as? String
        let validityStatus = SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: 0), nil)
        let state: CodeSignatureState = validityStatus == errSecSuccess ? .valid : .invalid
        let status = validityStatus == errSecSuccess ? informationStatus : validityStatus
        return CodeSignatureReport(state: state, identifier: identifier, teamIdentifier: teamIdentifier, statusCode: status)
    }
}
