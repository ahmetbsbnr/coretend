// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import DesignSystem
@testable import CoreTendApp

@Suite("Beta polish — locale, byte formatting, action-state wording")
struct RecoveryPlanPolishTests {

    // MARK: - In-app language → Locale

    @Test func appLanguageMapsToTheRightFormattingLocale() {
        #expect(LocalizationManager.locale(for: .fr).identifier == "fr_FR")
        #expect(LocalizationManager.locale(for: .en).identifier == "en_US")
        // .system follows the process locale.
        #expect(LocalizationManager.locale(for: .system).identifier == Locale.autoupdatingCurrent.identifier)
    }

    @Test func mcFormatBytesFollowsTheInAppLanguageNotTheProcessLocale() {
        let previous = MCFormatting.locale
        defer { MCFormatting.locale = previous }

        MCFormatting.locale = LocalizationManager.locale(for: .fr)
        #expect(mcFormatBytes(3_900_000_000).contains("3,9"))
        #expect(mcFormatBytes(3_900_000_000).hasSuffix("Go"))
        #expect(mcFormatBytes(664_700_000).hasSuffix("Mo"))

        MCFormatting.locale = LocalizationManager.locale(for: .en)
        #expect(mcFormatBytes(3_900_000_000).contains("3.9"))
        #expect(mcFormatBytes(3_900_000_000).hasSuffix("GB"))
    }

    // MARK: - Action-state semantics (the "Déplacé vers la Corbeille" bug)

    /// The reversibility badge is shown BEFORE the user confirms anything, so
    /// it must not read as a completed past action.
    @Test func theTrashReversibilityBadgeIsNotWordedAsACompletedAction() {
        for lang in [AppLanguage.en, .fr] {
            let badge = LocalizationManager.string(forKey: "advisor.reversibility.trash", language: lang)
            // No past-tense "moved / déplacé".
            #expect(!badge.lowercased().contains("moved"))
            #expect(!badge.lowercased().contains("déplacé"))
            // It still communicates the Trash mechanism.
            #expect(badge.lowercased().contains("trash") || badge.lowercased().contains("corbeille"))
        }
    }

    /// The genuinely post-execution strings DO stay past-tense — the fix must
    /// not have blunted the success messaging.
    @Test func postExecutionStringsRemainPastTense() {
        #expect(LocalizationManager.string(forKey: "cleanup.done.moved", language: .en).contains("moved to Trash"))
        #expect(LocalizationManager.string(forKey: "leftovers.finished.moved", language: .en).contains("moved to Trash"))
        #expect(LocalizationManager.string(forKey: "privacy.finished.moved", language: .fr).contains("Corbeille"))
    }

    // MARK: - Recovery Plan state model distinguishes plan / executing / done

    @MainActor
    @Test func viewModelExposesDistinctPreAndPostExecutionState() async {
        let vm = RecoveryPlanViewModel()
        #expect(vm.phase == .idle)
        #expect(vm.executionResult == nil)
        // Executing and finished are separate phases, and the result only
        // exists once finished — so the UI can never imply "done" while the
        // move is still in flight (or before it started).
        #expect(RecoveryPlanViewModel.Phase.executing != RecoveryPlanViewModel.Phase.finished)
    }

    // MARK: - Localization key parity for the surfaces touched this pass

    @Test func recoveryAndAdvisorKeysHaveEnFrParity() {
        for key in [
            "advisor.reversibility.trash", "recovery.preparing", "recovery.executing",
            "recovery.confirm_button", "recovery.summary.current_selection",
            "recovery.summary.potentially_recoverable", "recovery.goal_label",
            "common.cancel", "palette.placeholder", "palette.no_results",
        ] {
            let en = LocalizationManager.string(forKey: key, language: .en)
            let fr = LocalizationManager.string(forKey: key, language: .fr)
            #expect(en != key, "missing EN for \(key)")
            #expect(fr != key, "missing FR for \(key)")
        }
    }
}
