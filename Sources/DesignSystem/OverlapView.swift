// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// My Clutter's shared motif: near-duplicate/similar items shown slightly
/// overlapping, separating on hover or selection. Purely a decorative
/// arrangement of real content views the caller supplies (thumbnails, icons)
/// — no synthesized data, no timers. The overlap state is driven by genuine
/// hover/selection, never an automatic animation loop.
public struct MCOverlapStack<Item: Identifiable, ItemContent: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private let items: [Item]
    private let markedID: Item.ID?
    private let content: (Item) -> ItemContent

    public init(items: [Item], markedID: Item.ID? = nil,
                @ViewBuilder content: @escaping (Item) -> ItemContent) {
        self.items = items
        self.markedID = markedID
        self.content = content
    }

    private var expanded: Bool { isHovering || reduceMotion }

    public var body: some View {
        HStack(spacing: expanded ? MCSpacing.xs : -28) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .zIndex(Double(items.count - index))
                    .overlay(alignment: .topTrailing) {
                        if item.id == markedID {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white, MCColor.teal)
                                .offset(x: 4, y: -4)
                        }
                    }
            }
        }
        .animation(MCMotion.animation(MCMotion.snappy, reduce: reduceMotion), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityHidden(true)
    }
}
