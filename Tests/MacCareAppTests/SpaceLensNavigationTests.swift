import Testing
import Foundation
import ScanCore
@testable import MacCareApp

@Suite("Space Lens navigation")
@MainActor
struct SpaceLensNavigationTests {
    private func tree() -> SpaceNode {
        let leaf = SpaceNode(name: "leaf.bin", path: "/root/a/leaf.bin", isDirectory: false, size: 100)
        let a = SpaceNode(name: "a", path: "/root/a", isDirectory: true, size: 100, children: [leaf])
        let emptyDir = SpaceNode(name: "empty", path: "/root/empty", isDirectory: true, size: 0)
        return SpaceNode(name: "root", path: "/root", isDirectory: true, size: 100, children: [a, emptyDir])
    }

    @Test func currentFollowsPathStackThenRoot() {
        let m = SpaceLensViewModel()
        m.root = tree()
        #expect(m.current?.name == "root")
        m.descend(into: m.root!.children[0]) // "a"
        #expect(m.current?.name == "a")
    }

    @Test func descendIgnoresLeafAndEmptyDirectories() {
        let m = SpaceLensViewModel()
        m.root = tree()
        let a = m.root!.children[0]
        let empty = m.root!.children[1]
        m.descend(into: a.children[0])   // a file — no push
        #expect(m.current?.name == "root")
        m.descend(into: empty)           // directory with no children — no push
        #expect(m.current?.name == "root")
        m.descend(into: a)               // real directory — pushes
        #expect(m.current?.name == "a")
    }

    @Test func popToIndexAndToRoot() {
        let m = SpaceLensViewModel()
        m.root = tree()
        m.descend(into: m.root!.children[0])
        #expect(m.pathStack.count == 1)
        m.pop(to: nil)
        #expect(m.pathStack.isEmpty)
        #expect(m.current?.name == "root")
    }
}
