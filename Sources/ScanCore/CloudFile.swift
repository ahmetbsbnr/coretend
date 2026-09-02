// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Cloud/dataless-file guard shared by the duplicate and similar-image
/// inventories. A remote-only iCloud file is a placeholder on disk — reading its
/// bytes (to hash or to decode) would force a full download. We must skip such
/// files rather than silently hydrate gigabytes of cloud storage.
public enum CloudFile {
    /// Resource keys the inventory must request so `isRemoteOnly` has real data.
    public static let inventoryKeys: Set<URLResourceKey> = [
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
    ]

    /// True only when the file is an iCloud item that is definitely NOT
    /// materialized locally. Non-ubiquitous files, and ubiquitous files that are
    /// current/downloading, are treated as local (return false) — we never skip a
    /// file we could actually read, and never hydrate one we can't.
    public static func isRemoteOnly(isUbiquitous: Bool?,
                                    status: URLUbiquitousItemDownloadingStatus?) -> Bool {
        guard isUbiquitous == true else { return false }
        return status == .notDownloaded
    }

    /// Convenience over already-fetched resource values.
    public static func isRemoteOnly(_ values: URLResourceValues) -> Bool {
        isRemoteOnly(isUbiquitous: values.isUbiquitousItem,
                     status: values.ubiquitousItemDownloadingStatus)
    }
}
