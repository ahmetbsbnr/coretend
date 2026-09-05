// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Read-only validation for a URL a user selected in Finder and handed to
/// CoreTend through the `coretend://` scheme.
///
/// This is deliberately **not** `SafetyCore.PathValidator`. That type gates
/// *destructive* operations: it rejects user-content roots (`~/Documents`,
/// `~/Desktop`, `~/Pictures`, …), the home directory itself, and anything
/// outside a cleanup allowlist. A person who right-clicks their own photo
/// for a read-only look must not be blocked by delete-path rules. This
/// validator only checks that the target is coherent and safe to *inspect*,
/// re-evaluated against the live filesystem at the moment the host acts
/// (state can change between the Finder selection and the host handling it).
public enum SelectionValidator {
    public enum Rejection: String, Error, Equatable, Sendable {
        case invalidPath
        case symbolicLink
        case notAbsolute
        case containsTraversal
        case doesNotExist
        case wrongKind                 // asked to scan a folder, it's a file now (or vice-versa)
        case symlinkEscapesToSystem    // selection is a symlink whose target leads into a protected root
        case systemLocation            // a "scan folder" target inside a protected system root
    }

    /// System roots CoreTend will not treat as a user "scan this folder"
    /// target. Scanning them is read-only but never what the user meant and
    /// wastes work. Inspecting a *single* file under them is still allowed
    /// (e.g. `Inspect Application Integrity` on `/Applications/Safari.app`,
    /// which is a `.app` under a normal root, or a system app deliberately
    /// chosen — see `.inspectApplication` below).
    static let systemScanRoots = [
        "/System", "/private/var", "/private/etc", "/usr", "/bin", "/sbin",
        "/dev", "/cores", "/Library/Apple",
    ]

    /// Validate `path` for `action`. Pure except for the existence / kind /
    /// symlink checks against `fileManager`, which is the point — the host
    /// must re-check reality, not trust the extension's classification.
    public static func validate(path: String,
                                for action: FinderAction,
                                fileManager fm: FileManager = .default) -> Result<URL, Rejection> {
        guard path.hasPrefix("/") else { return .failure(.notAbsolute) }
        guard !path.split(separator: "/", omittingEmptySubsequences: true).contains("..") else {
            return .failure(.containsTraversal)
        }

        guard FinderHandoffURL.isPlausibleAbsolutePath(path) else { return .failure(.invalidPath) }
        let url = URL(fileURLWithPath: path).standardizedFileURL

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return .failure(.doesNotExist)
        }

        // Explicit symlink handling: if the selection itself resolves
        // elsewhere, the target must still exist, and for a folder scan it
        // must not lead into a protected system location.
        let resolved = url.resolvingSymlinksInPath()
        if resolved.path != url.path {
            guard fm.fileExists(atPath: resolved.path) else { return .failure(.doesNotExist) }
            if action == .scanFolder, isUnderAnySystemRoot(resolved.path) {
                return .failure(.symlinkEscapesToSystem)
            }
        }

        // Reject a selected symlink; parent aliases (such as /tmp) are resolved.
        guard let attributes = try? fm.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else { return .failure(.doesNotExist) }
        if type == .typeSymbolicLink { return .failure(.symbolicLink) }
        switch action {
        case .scanFolder:
            guard isDir.boolValue else { return .failure(.wrongKind) }
            if url.path == "/" || resolved.path == "/" || isUnderAnySystemRoot(url.path) || isUnderAnySystemRoot(resolved.path) {
                return .failure(.systemLocation)
            }
        case .inspectApplication:
            // A macOS app bundle is a directory named *.app.
            guard isDir.boolValue, url.pathExtension.lowercased() == "app" else {
                return .failure(.wrongKind)
            }
        case .inspectImage:
            guard type == .typeRegular,
                  FinderSelectionClassifier.imageExtensions.contains(url.pathExtension.lowercased())
            else { return .failure(.wrongKind) }
        }

        return .success(url)
    }

    static func isUnderAnySystemRoot(_ path: String) -> Bool {
        systemScanRoots.contains { root in
            path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }
}
