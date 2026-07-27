// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SafetyCore

/// Redirects the store to a throwaway directory so a distribution smoke test can
/// launch the *real* Release app without reading, writing, or migrating the
/// user's actual data.
///
/// Why this needs to exist at all: `Scripts/test-distribution.sh` launches the
/// packaged app to prove it starts. Until this type existed there was no way to
/// point that launch anywhere but `~/Library/Application Support/CoreTend`, so
/// the test ran against real user data and merely claimed not to. A dead
/// `MACCARELOCAL_STORE_DIR` export implied isolation that never existed.
///
/// Why it is safe to ship in a release binary: an override is only honoured when
/// **two independent environment variables** agree — a marker
/// (`CORETEND_TEST_MODE=1`) *and* a path (`CORETEND_TEST_STORE_DIR`) — and the
/// path must survive every check in ``validate(marker:rawPath:)``. One stray
/// variable in a user's environment cannot silently relocate their database.
/// The path must also live under a real temporary root, so even a caller that
/// sets both variables cannot aim the store at `$HOME` or a system directory.
///
/// Nothing here reads the filesystem: validation is pure string and URL work, so
/// every rule below is unit-testable without touching a real disk.
public enum TestStoreOverride {

    // MARK: - Environment keys

    /// Explicit opt-in marker. Must be exactly `"1"`.
    public static let markerKey = "CORETEND_TEST_MODE"

    /// Absolute path of the throwaway store directory.
    public static let pathKey = "CORETEND_TEST_STORE_DIR"

    /// The only value of ``markerKey`` that activates an override. Deliberately
    /// not "true"/"yes"/"on": one spelling, so there is nothing to get subtly
    /// wrong and no fuzzy matching to reason about.
    public static let markerValue = "1"

    // MARK: - Rejection reasons

    /// Why an override was refused. Every case is surfaced rather than silently
    /// falling back, because a test that believes it is isolated and is not is
    /// worse than a test that fails loudly.
    public enum Rejection: Error, Equatable, Sendable {
        case markerAbsent
        case markerNotExactlyOne(String)
        case pathAbsent
        case pathEmpty
        case pathNotAbsolute(String)
        case pathNotUnderTemporaryRoot(String)
        case pathProtected(String)
        case pathIsHomeOrAbove(String)

        public var description: String {
            switch self {
            case .markerAbsent:
                return "\(TestStoreOverride.markerKey) is not set"
            case .markerNotExactlyOne(let v):
                return "\(TestStoreOverride.markerKey) must be exactly \"1\", got \"\(v)\""
            case .pathAbsent:
                return "\(TestStoreOverride.pathKey) is not set"
            case .pathEmpty:
                return "\(TestStoreOverride.pathKey) is empty"
            case .pathNotAbsolute(let p):
                return "\(TestStoreOverride.pathKey) must be an absolute path, got \"\(p)\""
            case .pathNotUnderTemporaryRoot(let p):
                return "\(TestStoreOverride.pathKey) must be under a temporary root, got \"\(p)\""
            case .pathProtected(let p):
                return "\(TestStoreOverride.pathKey) resolves under the protected root \"\(p)\""
            case .pathIsHomeOrAbove(let p):
                return "\(TestStoreOverride.pathKey) must not be the home directory or a root, got \"\(p)\""
            }
        }
    }

    // MARK: - Temporary roots

    /// Roots a throwaway store may live under. `/var` and `/tmp` are symlinks to
    /// `/private/...` on macOS, and `URL.standardizedFileURL` does not resolve
    /// symlinks, so both spellings are listed rather than relying on
    /// canonicalization that would need to hit the disk.
    ///
    /// `TMPDIR` is included because that is where `mktemp -d` puts things by
    /// default in a user session; it is read from the passed-in environment, not
    /// from the process, so tests stay hermetic.
    static func temporaryRoots(environment: [String: String]) -> [String] {
        var roots = [
            "/tmp", "/private/tmp",
            "/var/folders", "/private/var/folders",
            "/var/tmp", "/private/var/tmp",
        ]
        if let tmpdir = environment["TMPDIR"], tmpdir.hasPrefix("/") {
            // Trailing slash is normal in TMPDIR and would break prefix matching.
            var t = tmpdir
            while t.count > 1 && t.hasSuffix("/") { t.removeLast() }
            roots.append(t)
        }
        return roots
    }

    // MARK: - Validation

    /// Decides whether the given marker/path pair may redirect the store.
    ///
    /// Pure: no filesystem access, no `ProcessInfo`. Callers pass the
    /// environment in, which is what makes every rule directly testable.
    public static func validate(
        marker: String?,
        rawPath: String?,
        environment: [String: String] = [:]
    ) -> Result<URL, Rejection> {
        guard let marker else { return .failure(.markerAbsent) }
        guard marker == markerValue else { return .failure(.markerNotExactlyOne(marker)) }

        guard let rawPath else { return .failure(.pathAbsent) }
        // Whitespace-only counts as empty: it is a mis-quoted variable, not intent.
        guard !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.pathEmpty)
        }
        guard rawPath.hasPrefix("/") else { return .failure(.pathNotAbsolute(rawPath)) }

        // Collapses "..", "." and trailing slashes, so a path cannot use
        // traversal to look temporary while pointing somewhere else.
        let standardized = URL(fileURLWithPath: rawPath).standardizedFileURL
        let path = standardized.path

        guard path != "/" else { return .failure(.pathIsHomeOrAbove(path)) }

        for root in PathValidator.protectedRoots
        where PathValidator.isPath(path, under: root) {
            return .failure(.pathProtected(root))
        }

        // Checked before the temporary-root test so that a home directory which
        // somehow sits under a temp root still cannot be targeted.
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard path != home, !PathValidator.isPath(home, under: path) else {
            return .failure(.pathIsHomeOrAbove(path))
        }

        let roots = temporaryRoots(environment: environment)
        guard roots.contains(where: { PathValidator.isPath(path, under: $0) }) else {
            return .failure(.pathNotUnderTemporaryRoot(path))
        }
        // A bare temporary root is not a store directory; requiring at least one
        // component below it stops an override from scribbling into /tmp itself.
        guard !roots.contains(path) else { return .failure(.pathNotUnderTemporaryRoot(path)) }

        return .success(standardized)
    }

    /// Resolves the override from a process environment, or `nil` when there is
    /// none. A *rejected* override also yields `nil` — the caller falls back to
    /// the real path — and the reason is returned so it can be reported.
    public static func resolve(
        environment: [String: String]
    ) -> (directory: URL?, rejection: Rejection?) {
        switch validate(
            marker: environment[markerKey],
            rawPath: environment[pathKey],
            environment: environment
        ) {
        case .success(let url):
            return (url, nil)
        case .failure(let reason):
            // Absent marker/path is the overwhelmingly common case — a normal
            // user launch — and is not worth reporting as a problem.
            switch reason {
            case .markerAbsent, .pathAbsent:
                return (nil, nil)
            default:
                return (nil, reason)
            }
        }
    }

    /// True when the test marker is set, regardless of whether the path is
    /// valid. Used to suppress the legacy-data migration during a smoke test:
    /// the migration must never read the user's real pre-rename data just
    /// because a test launched the app.
    public static func isTestMarkerSet(environment: [String: String]) -> Bool {
        environment[markerKey] == markerValue
    }

    /// Convenience over the live process environment.
    public static var current: (directory: URL?, rejection: Rejection?) {
        resolve(environment: ProcessInfo.processInfo.environment)
    }
}
