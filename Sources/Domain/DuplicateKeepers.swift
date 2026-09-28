import Foundation

/// Which file of each exact-duplicate group the person keeps. It starts at the engine's
/// suggestion and changes only when the person picks another file of the same group. A kept file
/// is never among the copies chosen for the Trash: keeping a file deselects it, and the kept files
/// of the groups a move touches are passed to the review as protected keepers.
public struct DuplicateKeepers: Equatable, Sendable {
    private var chosen: [String: URL] = [:]

    public init() {}

    /// The kept file of a group.
    public func keeper(of digest: String, suggested: URL) -> URL {
        chosen[digest] ?? suggested
    }

    /// Keeps `file` in its group (it must belong to it) and takes it out of `selection`.
    public mutating func keep(_ file: URL, of digest: String, files: [URL], selection: inout Set<URL>) {
        guard files.contains(file) else { return }
        chosen[digest] = file
        selection.remove(file)
    }

    /// The kept files of the groups that have at least one selected copy.
    public func protectedKeepers(groups: [(digest: String, files: [URL], suggested: URL)], selection: Set<URL>) -> [URL] {
        groups.compactMap { group in
            group.files.contains(where: selection.contains) ? keeper(of: group.digest, suggested: group.suggested) : nil
        }
    }
}
