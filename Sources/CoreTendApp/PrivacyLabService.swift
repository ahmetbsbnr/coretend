// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SystemMetrics

/// Privacy Lab's app-layer boundary over the pure `ImageMetadataInspector`
/// domain. It adds three things SwiftUI needs and the domain deliberately
/// does not carry: an off-main-actor execution hop, localized per-category
/// explanations, and an honest at-a-glance summary that is a set of counts —
/// never a "privacy score".
///
/// Nothing here persists metadata, writes to the Store, logs a value, or
/// touches the network. See `Documentation/PRIVACY_LAB.md`.

/// Injectable so tests can drive the view model deterministically (e.g. a
/// slow inspection racing a fast one) without real files on a background
/// queue.
typealias ImageMetadataInspecting = @Sendable (URL) async -> ImageMetadataInspection

enum PrivacyLabService {
    /// Runs the synchronous ImageIO read on a detached utility task so file
    /// work never lands on `MainActor`.
    static let live: ImageMetadataInspecting = { url in
        await Task.detached(priority: .utility) {
            ImageMetadataInspector.inspect(fileURL: url)
        }.value
    }
}

// MARK: - Localized category catalog

/// Fixed-key lookups into `Localizable.strings` for each metadata category's
/// display title and its "why this can matter" explanation. Every key exists
/// in both `Base.lproj` and `fr.lproj` (asserted by
/// `PrivacyLabLocalizationTests`).
enum PrivacyLabCatalog {
    static func title(for category: ImageMetadataCategory) -> String {
        L("privacylab.category.\(category.rawValue).title")
    }

    static func explanation(for category: ImageMetadataCategory) -> String {
        L("privacylab.category.\(category.rawValue).why")
    }
}

// MARK: - Summary

/// A plain, countable description of an inspection outcome. Intentionally not
/// a score and not a verdict: it never says an image is "safe", only what
/// was and was not found, and whether the inspection was complete.
enum PrivacyLabSummary: Equatable {
    /// The file could not be inspected at all. `headlineKey` is a
    /// `Localizable.strings` key describing which failure occurred.
    case cannotInspect(headlineKey: String)
    /// At least one category carries embedded metadata. `incompleteCount`
    /// is how many categories the inspection could not evaluate.
    case metadataPresent(count: Int, incompleteCount: Int)
    /// The inspection ran but found no supported metadata in any category.
    /// This is *not* a statement that the image is clean — only that no
    /// supported field was detected.
    case noSupportedMetadataDetected(incompleteCount: Int)

    init(_ inspection: ImageMetadataInspection) {
        switch inspection.status {
        case .fileMissing:
            self = .cannotInspect(headlineKey: "privacylab.status.file_missing")
        case .unreadable:
            self = .cannotInspect(headlineKey: "privacylab.status.unreadable")
        case .unsupported:
            self = .cannotInspect(headlineKey: "privacylab.status.unsupported")
        case .inspected:
            let present = inspection.presentCount
            let incomplete = inspection.unavailableCount
            self = present > 0
                ? .metadataPresent(count: present, incompleteCount: incomplete)
                : .noSupportedMetadataDetected(incompleteCount: incomplete)
        }
    }
}
