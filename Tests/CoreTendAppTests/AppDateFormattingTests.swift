// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp

@Suite("Dates follow the in-app language, not the system locale")
struct AppDateFormattingTests {

    /// 2 February 2026, 14:03 UTC. Fixed so a failure is a formatting change,
    /// never a clock.
    private let sample = Date(timeIntervalSince1970: 1_770_040_980)

    @Test("an explicit language overrides the system locale")
    func overrideBeatsSystem() {
        // The whole point. Locale.current is the system's and does not move
        // when CoreTend's language picker does — measured: on an en_US system,
        // launching with -AppleLanguages "(fr)" leaves Locale.current at en_US.
        #expect(AppDateFormatting.locale(for: .fr).identifier == "fr")
        #expect(AppDateFormatting.locale(for: .en).identifier == "en")
    }

    @Test("following the system is still possible, and is what .system means")
    func systemFallsBackToCurrent() {
        #expect(AppDateFormatting.locale(for: .system) == Locale.current)
    }

    @Test("every style renders differently in French than in English")
    func everyStyleIsLocalized() {
        for style in [AppDateFormatting.Style.dayMonthYear,
                      .dayMonthYearWithTime,
                      .fullDay] {
            let english = AppDateFormatting.string(sample, style: style, language: .en)
            let french = AppDateFormatting.string(sample, style: style, language: .fr)
            #expect(!english.isEmpty)
            #expect(!french.isEmpty)
            #expect(english != french, "style \(style) rendered identically in both languages")
        }
    }

    @Test("a French date carries no English month name")
    func frenchHasNoEnglishMonth() {
        // The bug this file exists for looked exactly like this: French
        // interface, "Feb 2, 2026" underneath it.
        let french = AppDateFormatting.string(sample, style: .dayMonthYear, language: .fr)
        for month in ["Jan", "Feb", "Mar", "Apr", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] {
            #expect(!french.contains(month), "French date contained English month \(month): \(french)")
        }
    }

    @Test("a full day heading names the weekday, which the short style does not")
    func fullDayIsLongerThanShortDate() {
        let short = AppDateFormatting.string(sample, style: .dayMonthYear, language: .en)
        let full = AppDateFormatting.string(sample, style: .fullDay, language: .en)
        #expect(full.count > short.count)
    }

    @Test("only the styles that promise a time include one")
    func timeAppearsOnlyWhereIntended() {
        let withTime = AppDateFormatting.string(sample, style: .dayMonthYearWithTime, language: .en)
        let withoutTime = AppDateFormatting.string(sample, style: .dayMonthYear, language: .en)
        #expect(withTime.contains(":"))
        #expect(!withoutTime.contains(":"))
    }

    @Test("the same date and language always render the same way")
    func formattingIsStable() {
        // Guards against a shared mutable formatter being introduced later as
        // an optimisation: the second call must not see the first one's state.
        let first = AppDateFormatting.string(sample, style: .dayMonthYearWithTime, language: .fr)
        _ = AppDateFormatting.string(sample, style: .fullDay, language: .en)
        let second = AppDateFormatting.string(sample, style: .dayMonthYearWithTime, language: .fr)
        #expect(first == second)
    }
}
