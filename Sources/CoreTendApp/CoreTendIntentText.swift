// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SystemMetrics
import DesignSystem

/// Pure text builders for the App Intents' spoken/returned results. Kept
/// apart from the intents so the "given this service output, produce this
/// string" mapping is fully testable without running an `AppIntent` or
/// touching `AppEnvironment.shared`.
enum CoreTendIntentText {
    static func freeSpace(freeBytes: Int64, totalBytes: Int64) -> String {
        L("appintent.freespace.result", mcFormatBytes(freeBytes), mcFormatBytes(totalBytes))
    }

    /// `deltaBytes == nil` => no comparable history yet.
    static func summary(freeBytes: Int64, deltaBytes: Int64?, lastScan: Date?) -> String {
        var parts = [L("appintent.summary.free", mcFormatBytes(freeBytes))]
        switch deltaBytes {
        case .none:
            parts.append(L("appintent.summary.no_history"))
        case .some(0):
            parts.append(L("appintent.summary.no_change"))
        case let .some(delta):
            parts.append(L(delta > 0 ? "appintent.summary.grew" : "appintent.summary.shrank",
                           mcFormatBytes(abs(delta))))
        }
        if let lastScan {
            parts.append(L("appintent.summary.last_scan",
                           lastScan.formatted(date: .abbreviated, time: .shortened)))
        }
        return parts.joined(separator: " ")
    }

    static func storageChange(deltaBytes: Int64?, topIncreaseBytes: Int64?) -> String {
        guard let delta = deltaBytes else { return L("appintent.change.no_history") }
        if delta == 0 { return L("appintent.change.none") }
        var text = L(delta > 0 ? "appintent.change.increase" : "appintent.change.decrease",
                     mcFormatBytes(abs(delta)))
        if delta > 0, let top = topIncreaseBytes, top > 0 {
            text += " " + L("appintent.change.top_category", mcFormatBytes(top))
        }
        return text
    }

    static func developerStorage(reclaimableBytes: Int64) -> String {
        L("appintent.devstorage.result", mcFormatBytes(reclaimableBytes))
    }

    static func integrity(provenanceCount: Int, quarantinedCount: Int,
                          loginItemCount: Int, ownTierRawValue: String) -> String {
        L("appintent.integrity.result", provenanceCount, quarantinedCount, loginItemCount,
          L("appintent.integrity.tier.\(ownTierRawValue)"))
    }

    /// `presentCategories` are already-localized category titles.
    static func imageMetadata(status: ImageMetadataInspection.Status,
                              presentCategories: [String]) -> String {
        switch status {
        case .inspected:
            return presentCategories.isEmpty
                ? L("appintent.imagemeta.none")
                : L("appintent.imagemeta.present", presentCategories.count,
                    presentCategories.joined(separator: ", "))
        case .unsupported:
            return L("appintent.imagemeta.unsupported")
        case .unreadable:
            return L("appintent.imagemeta.unreadable")
        case .fileMissing:
            return L("appintent.imagemeta.missing")
        }
    }
}
