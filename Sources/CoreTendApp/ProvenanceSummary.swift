// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import IntegrityCore

/// Turns what macOS recorded about a download into something a person can read.
///
/// The Integrity list showed `sourceURL` and, when that was nil, the words
/// "no provenance recorded". `sourceURL` is `LSQuarantineDataURL` — the direct
/// file URL — and macOS very often does not store it. Measured on a real
/// machine: **280 of 280 quarantined files in ~/Downloads and ~/Desktop had no
/// dataURL, and every one of them had an agent name and a timestamp.**
///
/// So the list said "no provenance recorded" for every file on that Mac while
/// LaunchServices knew Safari had downloaded it on a particular date. The
/// feature was not merely incomplete; it was stating the opposite of what the
/// system had recorded.
///
/// Quarantine keys are populated independently, so this reads each one on its
/// own and claims nothing is known only when nothing is.
enum ProvenanceSummary {

    /// Where the file came from: the direct URL when macOS kept it, otherwise
    /// the page it was linked from. Nil when neither was recorded.
    static func location(for item: DownloadProvenance) -> String? {
        item.sourceURL ?? item.originURL
    }

    /// Who brought it in and when — "Downloaded by Safari · 12 Mar 2026".
    ///
    /// This is the part that was missing entirely and that, in practice, is
    /// the only part most files have.
    static func acquisition(
        for item: DownloadProvenance,
        language: AppLanguage = LocalizationManager.language
    ) -> String? {
        let date = item.downloadedAt.map {
            AppDateFormatting.string($0, style: .dayMonthYear, language: language)
        }
        switch (item.agentName, date) {
        case let (agent?, date?):
            return L("integrity.downloads.by_agent_on_date", agent, date)
        case let (agent?, nil):
            return L("integrity.downloads.by_agent", agent)
        case let (nil, date?):
            return L("integrity.downloads.on_date", date)
        case (nil, nil):
            return nil
        }
    }

    /// True only when macOS recorded nothing at all about where this came
    /// from. The old check asked whether `sourceURL` alone was missing, which
    /// is why it answered "nothing known" about files it knew plenty about.
    static func isUnknown(_ item: DownloadProvenance) -> Bool {
        location(for: item) == nil && item.agentName == nil && item.downloadedAt == nil
    }
}
