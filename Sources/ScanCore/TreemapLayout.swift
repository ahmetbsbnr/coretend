import Foundation
import CoreGraphics

public struct TreemapInput: Sendable, Equatable, Identifiable {
    public let id: String
    public let bytes: Int64
    public init(id: String, bytes: Int64) { self.id = id; self.bytes = bytes }
}

public struct TreemapTile: Sendable, Identifiable {
    public let id: String
    public let bytes: Int64
    public let frame: CGRect
    public var areaShare: Double
    public init(id: String, bytes: Int64, frame: CGRect, areaShare: Double) {
        self.id = id; self.bytes = bytes; self.frame = frame; self.areaShare = areaShare
    }
}

/// Binary slice-and-dice treemap: each known byte contributes area in exact proportion.
public enum TreemapLayout {
    public static func tiles(for input: [TreemapInput], size: CGSize) -> [TreemapTile] {
        let items = input.filter { $0.bytes > 0 }.sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
        guard !items.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let total = items.reduce(0.0) { $0 + Double($1.bytes) }
        var output: [TreemapTile] = []
        split(items, rect: CGRect(origin: CGPoint(x: 0, y: 0), size: size), total: total, into: &output)
        return output
    }

    private static func split(_ items: [TreemapInput], rect: CGRect, total: Double, into output: inout [TreemapTile]) {
        guard !items.isEmpty else { return }
        if items.count == 1 {
            let item = items[0]
            output.append(TreemapTile(id: item.id, bytes: item.bytes, frame: rect,
                                      areaShare: Double(item.bytes) / total))
            return
        }
        let sum = items.reduce(0.0) { $0 + Double($1.bytes) }
        var running = 0.0
        var splitIndex = 1
        for index in 0..<(items.count - 1) {
            running += Double(items[index].bytes)
            splitIndex = index + 1
            if running * 2 >= sum { break }
        }
        let first = Array(items[..<splitIndex])
        let second = Array(items[splitIndex...])
        let ratio = CGFloat(first.reduce(0.0) { $0 + Double($1.bytes) }) / CGFloat(sum)
        if rect.size.width >= rect.size.height {
            let width = rect.size.width * ratio
            split(first, rect: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.size.height), total: total, into: &output)
            split(second, rect: CGRect(x: rect.minX + width, y: rect.minY, width: rect.size.width - width, height: rect.size.height), total: total, into: &output)
        } else {
            let height = rect.size.height * ratio
            split(first, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.size.width, height: height), total: total, into: &output)
            split(second, rect: CGRect(x: rect.minX, y: rect.minY + height, width: rect.size.width, height: rect.size.height - height), total: total, into: &output)
        }
    }
}
