// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("LocalizationManager runtime language override")
struct LocalizationManagerTests {
    /// A key known to exist, with a different value in Base vs fr, so a
    /// real mismatch would be caught rather than a coincidental match.
    private let key = "common.cancel"

    @Test("system language resolves no override bundle — falls back to Bundle.module")
    func systemHasNoOverride() {
        #expect(LocalizationManager.bundle(for: .system) == nil)
    }

    @Test("fr resolves to a real bundle whose lookup is actually French, independent of the system locale")
    func frResolvesRealFrenchBundle() throws {
        let bundle = try #require(LocalizationManager.bundle(for: .fr))
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        #expect(value == "Annuler")
    }

    @Test("en resolves to a real bundle whose lookup is actually English")
    func enResolvesRealEnglishBundle() throws {
        let bundle = try #require(LocalizationManager.bundle(for: .en))
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        #expect(value == "Cancel")
    }

    @Test("an unknown persisted value falls back to .system rather than crashing")
    func unknownStoredValueFallsBackSafely() {
        #expect(LocalizationManager.language(fromStoredValue: "de") == .system)
        #expect(LocalizationManager.language(fromStoredValue: nil) == .system)
    }
}
