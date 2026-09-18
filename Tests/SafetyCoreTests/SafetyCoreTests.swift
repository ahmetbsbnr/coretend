// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import SafetyCore


/// Execution failures must say what actually happened.
///
/// `execute` reported **every** failure of `trashItem` as `.fileVanished`:
/// permission denied, read-only volume, item in use, no Trash on the volume.
/// The realistic case is uninstalling an app from /Applications without admin
/// rights, where the user was told the bundle had disappeared — false, and
/// alarming in a way that invites them to go looking for a file that is
/// perfectly fine.
///
/// The audit log already distinguished these ("trashItem failed" versus a
/// genuine vanish). Only the typed error the caller and the UI see did not.
@Suite("Execution failures are classified, not flattened")
struct ExecutionFailureClassificationTests {

    @Test func aMissingFileIsAVanish() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        #expect(SafetyCenter.classify(cocoa) == .fileVanished)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
        #expect(SafetyCenter.classify(posix) == .fileVanished)
    }

    @Test func aPermissionFailureIsNotAVanish() {
        for error in [
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError),
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM)),
        ] {
            #expect(SafetyCenter.classify(error) == .permissionDenied,
                    "\(error.domain) \(error.code) was misclassified")
        }
    }

    /// Anything else keeps its real domain and code rather than being flattened
    /// into whichever case reads most plausibly. Flattening is the bug.
    @Test func anUnrecognisedFailureKeepsItsIdentity() {
        let error = NSError(domain: "NSOSStatusErrorDomain", code: -5000)
        #expect(SafetyCenter.classify(error) == .trashFailed(domain: "NSOSStatusErrorDomain", code: -5000))
    }

    /// Cocoa routinely wraps the real POSIX error. Reporting the wrapper's
    /// generic code would lose the only useful part.
    @Test func aWrappedPosixErrorIsUnwrapped() {
        let inner = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        let outer = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                            userInfo: [NSUnderlyingErrorKey: inner])
        #expect(SafetyCenter.classify(outer) == .permissionDenied)
    }

    /// A read-only volume is neither a vanish nor a permission problem, and
    /// must not be silently folded into either.
    @Test func aReadOnlyVolumeIsItsOwnFailure() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(EROFS))
        #expect(SafetyCenter.classify(error) == .trashFailed(domain: NSPOSIXErrorDomain, code: Int(EROFS)))
        #expect(SafetyCenter.classify(error) != .fileVanished)
    }

    /// Classification must terminate on a self-referential userInfo chain
    /// rather than recursing forever.
    @Test func aSelfReferentialErrorChainTerminates() {
        let error = NSError(domain: "X", code: 1,
                            userInfo: [NSUnderlyingErrorKey: NSError(domain: "X", code: 1)])
        #expect(SafetyCenter.classify(error) == .trashFailed(domain: "X", code: 1))
    }
}
