// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Whether the thing a module is about to scan can actually be read.
enum ScanTargetAccess {

    /// Whether the folder this module is actually going to scan can be read.
    ///
    /// Full Disk Access is the right question for a scan of the real home. It
    /// is the wrong question for a scan of a stand-in home under a temporary
    /// root, which is readable without any grant at all: there the gate
    /// refused a scan that would have succeeded. Test mode only — outside it
    /// `homeOverride` is nil and this is exactly the previous behaviour.
    static var canReadScanTarget: Bool {
        CaptureHarness.homeOverride != nil || SystemAuthorization.probeLive().hasFullDiskAccess
    }
}
