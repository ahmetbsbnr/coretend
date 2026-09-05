// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("macOS integrations localization parity")
struct MacIntegrationsLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func strings(_ folder: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(
            "Sources/CoreTendApp/Resources/\(folder).lproj/Localizable.strings"), encoding: .utf16)
    }

    private var requiredKeys: [String] {
        var keys = [
            "settings.scheduled_scans", "settings.scheduled_scans.cadence", "settings.scheduled_scans.detail",
            "settings.notifications_categories", "settings.notifications_categories.detail",
            "settings.notifications.enable",
            "notif.low_disk.title", "notif.low_disk.body",
            "notif.scan.title", "notif.scan.reclaimable", "notif.scan.growth",
            "appintent.module.type", "appintent.open.title", "appintent.open.description", "appintent.open.param",
            "appintent.freespace.title", "appintent.freespace.description", "appintent.freespace.result",
            "appintent.summary.title", "appintent.change.title", "appintent.devstorage.title",
            "appintent.integrity.title", "appintent.imagemeta.title", "appintent.imagemeta.param",
        ]
        for c in ScanCadence.allCases { keys.append(c.labelKey) }
        for c in NotificationCategory.allCases { keys.append("notif.category.\(c.rawValue).title") }
        for m in CoreTendModuleAppEnum.allCases {
            // Each module case has a display key of the form appintent.module.<...>.
            _ = m
        }
        keys += ["appintent.module.dashboard", "appintent.module.storage", "appintent.module.timeline",
                 "appintent.module.recovery_plan", "appintent.module.developer", "appintent.module.privacy_lab",
                 "appintent.module.restore_center", "appintent.module.apfs", "appintent.module.applications",
                 "appintent.module.settings"]
        keys += ["shortcut.summary.short", "shortcut.change.short", "shortcut.freespace.short",
                 "shortcut.devstorage.short", "shortcut.imagemeta.short", "shortcut.open.short"]
        keys += ["appintent.integrity.tier.appleSigned", "appintent.integrity.tier.teamSigned",
                 "appintent.integrity.tier.adHocOrUnsigned"]
        return keys
    }

    @Test func everyKeyExistsInBothBaseAndFrench() throws {
        let base = try strings("Base")
        let fr = try strings("fr")
        for key in requiredKeys {
            #expect(base.contains("\"\(key)\""), "Base.lproj missing \(key)")
            #expect(fr.contains("\"\(key)\""), "fr.lproj missing \(key)")
        }
    }

    @Test func cadenceAndCategoryLabelsAreTranslated() {
        for c in ScanCadence.allCases {
            let en = LocalizationManager.string(forKey: c.labelKey, language: .en)
            let fr = LocalizationManager.string(forKey: c.labelKey, language: .fr)
            #expect(!en.isEmpty && en != c.labelKey)
            #expect(en != fr || c == .off, "\(c) label should be translated")
        }
        for cat in NotificationCategory.allCases {
            let key = "notif.category.\(cat.rawValue).title"
            #expect(LocalizationManager.string(forKey: key, language: .fr) != key)
        }
    }

    @Test func notificationBodiesTakeExactlyOneFormatArgument() {
        // Guards against a %@ / %d mismatch that would crash String(format:).
        #expect(L("notif.low_disk.body", "5 GB").contains("5 GB"))
        #expect(L("notif.scan.reclaimable", "8 GB").contains("8 GB"))
        #expect(L("notif.scan.growth", "3 GB").contains("3 GB"))
    }
}
