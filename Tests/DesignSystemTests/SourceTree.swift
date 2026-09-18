// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Every Swift file under a directory, as paths relative to it.
///
/// Source-scanning tests used `contentsOfDirectory`, which is not recursive.
/// The day CoreTendApp.swift was split into App/ and Shell/ every one of those
/// tests silently stopped seeing a third of the module — and kept passing.
enum SourceTree {
    static func swiftFiles(under dir: URL) throws -> [String] {
        guard let e = FileManager.default.enumerator(atPath: dir.path) else { return [] }
        var out: [String] = []
        while let rel = e.nextObject() as? String {
            if rel.hasSuffix(".swift") { out.append(rel) }
        }
        return out.sorted()
    }
}
