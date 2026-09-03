// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import AppDiscovery
@testable import CoreTendApp

@Suite("Leftover shared/ambiguous detection")
@MainActor
struct LeftoversAmbiguityTests {
    @Test("group. prefixed containers are always flagged ambiguous")
    func groupPrefix() {
        let model = LeftoversViewModel()
        let item = AssociatedItem(kind: .containers,
                                   url: URL(fileURLWithPath: "/Users/u/Library/Containers/group.com.acme.shared"),
                                   sizeBytes: 100)
        model.leftovers = [item]
        #expect(model.isAmbiguous(item))
    }

    @Test("two leftovers sharing a vendor prefix are flagged, a lone one is not")
    func sharedVendorPrefix() {
        let model = LeftoversViewModel()
        let a = AssociatedItem(kind: .caches, url: URL(fileURLWithPath: "/L/Caches/com.acme.AppOne"), sizeBytes: 10)
        let b = AssociatedItem(kind: .caches, url: URL(fileURLWithPath: "/L/Caches/com.acme.AppTwo"), sizeBytes: 10)
        let c = AssociatedItem(kind: .caches, url: URL(fileURLWithPath: "/L/Caches/com.solo.OnlyApp"), sizeBytes: 10)
        model.leftovers = [a, b, c]
        #expect(model.isAmbiguous(a))
        #expect(model.isAmbiguous(b))
        #expect(!model.isAmbiguous(c))
    }
}
