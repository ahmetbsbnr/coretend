import Darwin
import Foundation

public enum QuickLookCandidate {
    public static func isAllowed(_ candidate: URL, within selectedRoot: URL) -> Bool {
        guard candidate.isFileURL, selectedRoot.isFileURL else { return false }

        var rootInfo = stat()
        guard lstat(selectedRoot.path, &rootInfo) == 0,
              (rootInfo.st_mode & S_IFMT) == S_IFDIR else { return false }

        var candidateInfo = stat()
        guard lstat(candidate.path, &candidateInfo) == 0,
              (candidateInfo.st_mode & S_IFMT) == S_IFREG else { return false }

        let rootPath = selectedRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let candidatePath = candidate.standardizedFileURL.resolvingSymlinksInPath().path
        return candidatePath != rootPath
            && candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }
}
