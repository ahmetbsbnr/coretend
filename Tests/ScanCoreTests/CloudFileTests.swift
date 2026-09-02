// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import ScanCore

@Suite("Cloud dataless-file guard")
struct CloudFileTests {
    @Test func nonUbiquitousFileIsAlwaysLocal() {
        #expect(CloudFile.isRemoteOnly(isUbiquitous: false, status: nil) == false)
        #expect(CloudFile.isRemoteOnly(isUbiquitous: nil, status: nil) == false)
        // Even a nil/odd status on a non-ubiquitous file stays local.
        #expect(CloudFile.isRemoteOnly(isUbiquitous: false, status: .notDownloaded) == false)
    }

    @Test func ubiquitousNotDownloadedIsRemoteOnly() {
        #expect(CloudFile.isRemoteOnly(isUbiquitous: true, status: .notDownloaded) == true)
    }

    @Test func ubiquitousCurrentOrDownloadingIsLocalEnoughToRead() {
        #expect(CloudFile.isRemoteOnly(isUbiquitous: true, status: .current) == false)
        #expect(CloudFile.isRemoteOnly(isUbiquitous: true, status: .downloaded) == false)
        // Unknown status: don't skip a file we might be able to read.
        #expect(CloudFile.isRemoteOnly(isUbiquitous: true, status: nil) == false)
    }
}
