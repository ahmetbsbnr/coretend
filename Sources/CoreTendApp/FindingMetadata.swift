// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// Human-readable presentation of the evidence a scan already carries.
///
/// The engines compute a risk level and a modification date for every finding,
/// and until now the UI showed neither: a row said what a file is called, where
/// it lives and how big it is. Size is the weakest of the three signals for
/// deciding whether something should go — a 2 MB cache written this morning and
/// a 2 MB cache untouched for a year are not the same decision, and the app
/// already knew the difference without saying so.
///
/// Risk also explains something the interface was doing silently: it is what
/// drives preselection. A row that is not ticked by default now says why.
///
/// Deliberately not surfaced per finding:
/// - `category`, because the rule group heading above the row already carries it;
/// - `confidence`, which is an engine-internal weight. Showing "90%" next to a
///   file invites a precision the number does not have, and the honest version
///   of that signal is the risk level, which is already here.
// Internal, like the rest of CoreTendApp: nothing outside this module
// consumes it, and a public default argument cannot reference
// LocalizationManager, which is internal.
enum FindingMetadata {

    /// Localized name for a risk level.
    ///
    /// Shared so the same level never reads two different ways: the Safety Log
    /// previously interpolated the raw enum, which printed "low"/"medium"/"high"
    /// untranslated in a fully French UI.
    static func riskLabel(_ risk: RiskLevel) -> String {
        switch risk {
        case .low: L("risk.low")
        case .medium: L("risk.medium")
        case .high: L("risk.high")
        }
    }

    /// Localized risk name for a raw stored string.
    ///
    /// Persisted audit records keep the raw value, so an unrecognised one is
    /// possible after a schema change. It is passed through rather than
    /// dropped: a log is evidence, and silently hiding a value it actually
    /// holds would be worse than showing an unfamiliar word.
    static func riskLabel(rawValue: String) -> String {
        RiskLevel(rawValue: rawValue).map(riskLabel) ?? rawValue
    }

    /// Compact age of a file, or nil when the filesystem gave no date.
    ///
    /// Relative rather than absolute ("8 months ago", not "12 Jan 2026"): the
    /// question a row has to answer is how stale something is, and a reader
    /// should not have to subtract dates to find out.
    static func ageDescription(
        for date: Date?,
        now: Date = Date(),
        language: AppLanguage = LocalizationManager.language
    ) -> String? {
        guard let date else { return nil }
        // A modification date in the future is real — a bad clock, a restored
        // backup, an archive that preserved timestamps. Treating it as "in 3
        // days" would read as a bug, so it is clamped to the present instead.
        let past = min(date, now)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        // Foundation formatters follow the *system* locale, which is not the
        // same thing as the language the user picked inside CoreTend. Without
        // this the line rendered "Risque faible · modifié 1 month ago" in a
        // fully French UI — the very defect this type was written to fix,
        // reintroduced one line below the fix. Caught by looking at the running
        // app, not by a test: the tests asserted structure, not language.
        if let identifier = language.localeIdentifier {
            formatter.locale = Locale(identifier: identifier)
        }
        return formatter.localizedString(for: past, relativeTo: now)
    }

    /// The one-line evidence summary shown under a finding's path.
    ///
    /// Returns nil when there is nothing to add, so the caller can omit the
    /// line entirely rather than render an empty or dangling separator.
    static func summary(
        risk: RiskLevel,
        modificationDate: Date?,
        now: Date = Date(),
        language: AppLanguage = LocalizationManager.language
    ) -> String? {
        var parts: [String] = [L("finding.risk_prefix", riskLabel(risk))]
        if let age = ageDescription(for: modificationDate, now: now, language: language) {
            parts.append(L("finding.modified_prefix", age))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
