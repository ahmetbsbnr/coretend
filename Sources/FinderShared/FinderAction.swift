// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// The read-only CoreTend actions a Finder selection can trigger. Every one
/// of them opens the host and lands on an existing screen — none deletes,
/// cleans, trashes, restores, uninstalls, or mutates anything.
public enum FinderAction: String, Sendable, CaseIterable, Equatable {
    case scanFolder = "scan-folder"
    case inspectImage = "inspect-image"
    case inspectApplication = "inspect-application"
}

/// Conservative classification using only single-item filesystem attributes.
public enum FinderSelectionKind: Equatable, Sendable {
    case directory
    case applicationBundle
    case image
    case otherFile
}

public enum FinderSelectionClassifier {
    /// Lower-cased extensions Privacy Lab's `ImageMetadataInspector` accepts
    /// (ImageIO-readable stills). Kept deliberately small and explicit; an
    /// unlisted extension simply gets no "inspect image" action rather than
    /// a broken one.
    public static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp",
        "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2",
    ]

    public static func kind(of url: URL) -> FinderSelectionKind {
        guard url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else { return .otherFile }
        let ext = url.pathExtension.lowercased()
        if type == .typeDirectory {
            return ext == "app" ? .applicationBundle : .directory
        }
        guard type == .typeRegular else { return .otherFile }
        return imageExtensions.contains(ext) ? .image : .otherFile
    }

    public static func actions(for selection: [URL]) -> [FinderAction] {
        guard selection.count == 1, let url = selection.first else { return [] }
        return actions(for: url)
    }

    /// The action(s) offered for a **single-item** selection. Multi-selection
    /// is intentionally unsupported in v1 (see the extension's menu policy):
    /// a folder gets "scan", an `.app` gets "inspect integrity", a supported
    /// image gets "inspect metadata", anything else gets nothing.
    public static func actions(for url: URL) -> [FinderAction] {
        switch kind(of: url) {
        case .directory: return [.scanFolder]
        case .applicationBundle: return [.inspectApplication]
        case .image: return [.inspectImage]
        case .otherFile: return []
        }
    }
}
