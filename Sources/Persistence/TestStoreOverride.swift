import Foundation

/// Resolves an isolated store only when the process declares a complete test profile.
/// This function never creates a directory or database.
public enum TestStoreOverride {
    /// Resolves a reversible test Trash only when it is a non-symlink descendant of the
    /// already validated fixture store. A malformed override throws so callers can fail closed.
    public static func trashDirectory(
        environment: [String: String],
        temporaryRoot: URL,
        homeDirectory: URL
    ) throws -> URL? {
        guard let path = environment["CORETEND_TEST_TRASH_DIR"] else { return nil }
        guard environment["CORETEND_TEST_MODE"] == "1",
              let storePath = environment["CORETEND_TEST_STORE_DIR"],
              try databaseURL(environment: environment, temporaryRoot: temporaryRoot,
                              homeDirectory: homeDirectory) != nil,
              path.hasPrefix("/") else { throw StoreError.invalidTestStoreOverride }

        let store = URL(fileURLWithPath: storePath, isDirectory: true).standardizedFileURL
        let trash = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let confined = isStrictDescendant(trash, of: store)
        let linked = containsSymbolicLink(trash, below: store)
        guard confined, !linked else {
            throw StoreError.invalidTestStoreOverride
        }
        return trash
    }

    public static func databaseURL(
        environment: [String: String],
        temporaryRoot: URL,
        homeDirectory: URL
    ) throws -> URL? {
        let mode = environment["CORETEND_TEST_MODE"]
        let storePath = environment["CORETEND_TEST_STORE_DIR"]
        guard mode != nil || storePath != nil else { return nil }
        guard mode == "1", let storePath, storePath.hasPrefix("/"),
              let homePath = environment["HOME"],
              let fixedHomePath = environment["CFFIXED_USER_HOME"],
              homePath.hasPrefix("/"), homePath == fixedHomePath,
              URL(fileURLWithPath: homePath, isDirectory: true).standardizedFileURL == homeDirectory.standardizedFileURL
        else { throw StoreError.invalidTestStoreOverride }

        let fileManager = FileManager.default
        let resolvedSystemTemporaryRoot = fileManager.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedTemporaryRoot = temporaryRoot.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedHome = homeDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let storeDirectory = URL(fileURLWithPath: storePath, isDirectory: true).standardizedFileURL
        let resolvedStoreDirectory = storeDirectory.resolvingSymlinksInPath()

        var rootIsDirectory: ObjCBool = false
        var homeIsDirectory: ObjCBool = false
        var storeIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedTemporaryRoot.path, isDirectory: &rootIsDirectory), rootIsDirectory.boolValue,
              fileManager.fileExists(atPath: resolvedHome.path, isDirectory: &homeIsDirectory), homeIsDirectory.boolValue,
              fileManager.fileExists(atPath: resolvedStoreDirectory.path, isDirectory: &storeIsDirectory), storeIsDirectory.boolValue,
              resolvedTemporaryRoot.path != "/",
              resolvedTemporaryRoot.path == resolvedSystemTemporaryRoot.path || isStrictDescendant(resolvedTemporaryRoot, of: resolvedSystemTemporaryRoot),
              resolvedTemporaryRoot.path == temporaryRoot.standardizedFileURL.resolvingSymlinksInPath().path,
              resolvedHome.path == homeDirectory.standardizedFileURL.resolvingSymlinksInPath().path,
              resolvedStoreDirectory.path == storeDirectory.resolvingSymlinksInPath().path,
              !isSymbolicLink(homeDirectory), !isSymbolicLink(storeDirectory),
              isStrictDescendant(resolvedHome, of: resolvedTemporaryRoot),
              isStrictDescendant(resolvedStoreDirectory, of: resolvedTemporaryRoot),
              !overlaps(resolvedHome, resolvedStoreDirectory)
        else { throw StoreError.invalidTestStoreOverride }

        return StoreLocation.databaseURL(applicationSupportDirectory: resolvedStoreDirectory)
    }

    private static func overlaps(_ first: URL, _ second: URL) -> Bool {
        first.standardizedFileURL == second.standardizedFileURL
            || isStrictDescendant(first, of: second)
            || isStrictDescendant(second, of: first)
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        return attributes[.type] as? FileAttributeType == .typeSymbolicLink
    }

    private static func containsSymbolicLink(_ candidate: URL, below parent: URL) -> Bool {
        let components = candidate.standardizedFileURL.pathComponents
        let parentComponents = parent.standardizedFileURL.pathComponents
        guard components.count > parentComponents.count, components.starts(with: parentComponents) else { return true }
        var current = parent
        for component in components.dropFirst(parentComponents.count) {
            current.appendPathComponent(component)
            if isSymbolicLink(current) { return true }
        }
        return false
    }

    private static func isStrictDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        let parentComponents = parent.standardizedFileURL.pathComponents
        return candidateComponents.count > parentComponents.count
            && candidateComponents.starts(with: parentComponents)
    }
}
