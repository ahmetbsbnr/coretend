// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("First-run wizard logic")
struct OnboardingLogicTests {

    // MARK: Security profile mapping

    @Test func everyProfileMapsToSafeDefaults() {
        for profile in SecurityProfile.allCases {
            let c = SecurityConfig.forProfile(profile)
            #expect(c.useTrash == true)
            // Safety invariant: no profile ever enables an aggressive default.
            #expect(c.mediumRiskRules == false)
            #expect(c.emptyTrash == false)
            #expect(c.autoQuarantine == false)
        }
    }

    // MARK: Launch-location detection

    @Test func detectsApplications() {
        #expect(LaunchLocation.detect(bundlePath: "/Applications/CoreTend.app", home: "/Users/me") == .applications)
        #expect(LaunchLocation.detect(bundlePath: "/Users/me/Applications/CoreTend.app", home: "/Users/me") == .applications)
    }

    @Test func detectsDownloads() {
        #expect(LaunchLocation.detect(bundlePath: "/Users/me/Downloads/CoreTend.app", home: "/Users/me") == .downloads)
    }

    @Test func detectsDiskImage() {
        #expect(LaunchLocation.detect(bundlePath: "/Volumes/CoreTend/CoreTend.app", home: "/Users/me") == .diskImage)
    }

    @Test func detectsTemporaryAndTranslocation() {
        #expect(LaunchLocation.detect(bundlePath: "/private/var/folders/xy/T/AppTranslocation/ABC/d/CoreTend.app", home: "/Users/me") == .temporary)
        #expect(LaunchLocation.detect(bundlePath: "/private/var/folders/xy/T/CoreTend.app", home: "/Users/me") == .temporary)
        #expect(LaunchLocation.detect(bundlePath: "/tmp/CoreTend.app", home: "/Users/me") == .temporary)
    }

    @Test func detectsOther() {
        #expect(LaunchLocation.detect(bundlePath: "/Users/me/Desktop/CoreTend.app", home: "/Users/me") == .other)
    }

    @Test func moveOfferedOnlyOutsideApplications() {
        #expect(LaunchLocation.applications.canOfferMove == false)
        #expect(LaunchLocation.downloads.canOfferMove == true)
        #expect(LaunchLocation.diskImage.canOfferMove == true)
        #expect(LaunchLocation.temporary.canOfferMove == true)
    }

    // MARK: System-check status derivation

    private var healthy: SystemCheck.Inputs {
        SystemCheck.Inputs(
            isARM64: true, macOSMajor: 15, bundleValid: true, resourcesPresent: true,
            sqliteAvailable: true, fullDiskAccess: true,
            freeSpaceBytes: 50_000_000_000, configuredLocationAccessible: true,
            safetyCoreReady: true)
    }

    @Test func allGreenIsReady() {
        #expect(SystemCheck.overall(SystemCheck.items(healthy)) == .ok)
    }

    @Test func missingOptionalsDegradeToLimited() {
        var i = healthy
        i.fullDiskAccess = false
        i.freeSpaceBytes = 100
        i.configuredLocationAccessible = false
        let items = SystemCheck.items(i)
        #expect(SystemCheck.overall(items) == .limited)
        #expect(items.first { $0.id == "permissions" }?.status == .limited)
        #expect(items.first { $0.id == "freespace" }?.status == .limited)
    }

    @Test func badBundleIsActionRequired() {
        var i = healthy
        i.bundleValid = false
        #expect(SystemCheck.overall(SystemCheck.items(i)) == .actionRequired)
    }

    @Test func wrongArchOrOldOSIsUnavailable() {
        var i = healthy
        i.isARM64 = false
        #expect(SystemCheck.overall(SystemCheck.items(i)) == .unavailable)
        var j = healthy
        j.macOSMajor = 13
        #expect(SystemCheck.overall(SystemCheck.items(j)) == .unavailable)
    }

    @Test func unavailableOutranksActionRequired() {
        var i = healthy
        i.sqliteAvailable = false // unavailable
        i.bundleValid = false     // actionRequired
        #expect(SystemCheck.overall(SystemCheck.items(i)) == .unavailable)
    }
}
