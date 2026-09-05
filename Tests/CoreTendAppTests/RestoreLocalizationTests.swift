// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Restore Center localization parity")
struct RestoreLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func strings(_ folder: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(
            "Sources/CoreTendApp/Resources/\(folder).lproj/Localizable.strings"), encoding: .utf16)
    }

    private var requiredKeys: [String] {
        var keys = [
            "module.restore_center",
            "restore.title", "restore.intro", "restore.private_note", "restore.loading",
            "restore.empty.title", "restore.empty.message", "restore.refresh",
            "restore.forget", "restore.forget.title", "restore.forget.action", "restore.forget.message",
            "restore.confirm.title", "restore.confirm.action", "restore.confirm.message",
            "restore.selected", "restore.restore_selected",
            "restore.result.header", "restore.result.restored", "restore.result.conflict",
            "restore.result.unavailable", "restore.result.failed",
            "restore.select_all_in_operation", "restore.operation.summary", "restore.operation.restorable",
            "restore.op.trash_emptied", "restore.op.none_restorable", "restore.op.some_restorable",
            "restore.state.available", "restore.state.restored", "restore.state.conflict",
            "restore.state.location_unavailable", "restore.state.changed", "restore.state.not_in_trash",
            "restore.state.volume_missing",
            "restore.select_item", "restore.item.details", "restore.item.original",
            "restore.item.trash", "restore.item.is_directory",
        ]
        // One explanation key per live-availability case the UI can render.
        for availability in [
            RestoreAvailability.available, .destinationOccupied, .parentMissing, .parentNotWritable,
            .missingFromTrash, .invalidIdentity, .volumeUnavailable, .alreadyRestored,
        ] {
            keys.append("restore.explain.\(availability.rawValue)")
        }
        return keys
    }

    @Test func everyRestoreKeyExistsInBothBaseAndFrench() throws {
        let base = try strings("Base")
        let fr = try strings("fr")
        for key in requiredKeys {
            #expect(base.contains("\"\(key)\""), "Base.lproj missing \(key)")
            #expect(fr.contains("\"\(key)\""), "fr.lproj missing \(key)")
        }
    }

    @Test func moduleAndKeyStatesAreActuallyTranslated() {
        #expect(LocalizationManager.string(forKey: "module.restore_center", language: .en) == "Restore Center")
        #expect(LocalizationManager.string(forKey: "module.restore_center", language: .fr) != "Restore Center")
        for availability in [RestoreAvailability.available, .missingFromTrash, .destinationOccupied] {
            let en = LocalizationManager.string(forKey: "restore.explain.\(availability.rawValue)", language: .en)
            let fr = LocalizationManager.string(forKey: "restore.explain.\(availability.rawValue)", language: .fr)
            #expect(!en.isEmpty && en != "restore.explain.\(availability.rawValue)")
            #expect(en != fr, "\(availability) explanation not translated")
        }
    }

    @Test func forgetHistoryWordingSeparatesRecordsFromEmptyingTrash() {
        for language: AppLanguage in [.en, .fr] {
            let message = LocalizationManager.string(forKey: "restore.forget.message", language: language)
            #expect(!message.isEmpty)
        }
        let en = LocalizationManager.string(forKey: "restore.forget.message", language: .en)
        #expect(en.lowercased().contains("not empty the trash") || en.lowercased().contains("does not empty"))
    }
}
