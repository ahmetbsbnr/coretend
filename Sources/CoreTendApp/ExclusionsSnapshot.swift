// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// The user's excluded paths, or an explicit statement that they could not be
/// read. Those are two different facts and the app used to express them with
/// the same value.
///
/// ## The bug this type exists to make impossible
///
/// Every caller read exclusions like this:
///
/// ```swift
/// let excluded = (try? await AppEnvironment.shared.store?.exclusions()) ?? []
/// ```
///
/// Three separate failures — the store never opened, the database is corrupt,
/// the read threw — all collapse into `[]`, which is *also* what a user with no
/// exclusions has. `CleanupView` then fed that into
/// `ScanConfiguration(excludedPaths:)`.
///
/// The consequence is the worst one this app can produce: a folder the user
/// explicitly marked "never scan, never clean" is scanned anyway, its contents
/// are offered for deletion, and — because cleanup findings arrive
/// `preselected` — they are **already ticked**. Nothing on screen differs from
/// a normal scan. The user's protection is gone and there is no signal that it
/// ever existed.
///
/// An empty exclusion list and an unreadable one must never again be the same
/// value, so they are not the same type.
enum ExclusionsSnapshot: Equatable {
    /// Read successfully. The array may legitimately be empty.
    case loaded([String])
    /// Could not be read. Callers that gate a destructive suggestion on
    /// exclusions must treat this as "do not suggest", never as "nothing is
    /// excluded".
    case unavailable

    /// Paths to hand to a scan engine.
    ///
    /// `unavailable` yields `[]` because there is nothing better to exclude —
    /// but callers must separately check `isTrustworthy` before preselecting
    /// anything for deletion. The two questions are deliberately separate calls
    /// so that answering only the first is visible at the call site.
    var paths: [String] {
        switch self {
        case .loaded(let paths): paths
        case .unavailable: []
        }
    }

    /// Whether this snapshot can be relied on to decide what is safe to delete.
    var isTrustworthy: Bool {
        if case .loaded = self { return true }
        return false
    }

    var count: Int { paths.count }
}
