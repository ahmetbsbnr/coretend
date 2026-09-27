import Foundation

/// Resolves an isolated store only when the process declares a complete test profile.
/// This function never creates a directory or database.
public enum TestStoreOverride {
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
              resolvedTemporaryRoot == resolvedSystemTemporaryRoot || isStrictDescendant(resolvedTemporaryRoot, of: resolvedSystemTemporaryRoot),
              resolvedTemporaryRoot.path == temporaryRoot.standardizedFileURL.path,
              resolvedHome.path == homeDirectory.standardizedFileURL.path,
              resolvedStoreDirectory.path == storeDirectory.path,
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

    private static func isStrictDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        let parentComponents = parent.standardizedFileURL.pathComponents
        return candidateComponents.count > parentComponents.count
            && candidateComponents.starts(with: parentComponents)
    }
}
