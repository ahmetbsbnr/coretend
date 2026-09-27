import SwiftUI

/// A parcel: the Serre card (UI guide § 7). Surface fill, leaf corners, a decorative outline.
/// Never nest one parcel in another; use a separator inside instead.
public struct SerreParcel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        let shape = LeafCorner.parcel.shape
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.color, in: shape)
            .overlay(shape.strokeBorder(Palette.separator.color, lineWidth: 1))
    }
}

/// What a banner reports (UI guide § 7, view states).
public enum SerreBannerKind: Sendable {
    /// Some items could not be read; their absence proves nothing.
    case partial
    /// Access to the chosen folder was refused.
    case denied
    /// Something failed; the message says what and how to retry.
    case error
    /// Neutral information.
    case note
}

/// A banner that slides in from the top of the content (`standard`, never a bounce).
public struct SerreBanner<Action: View>: View {
    let kind: SerreBannerKind
    let title: String
    let message: String?
    let action: Action

    public init(_ kind: SerreBannerKind, title: String, message: String? = nil, @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.kind = kind
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        let shape = LeafCorner.control.shape
        HStack(alignment: .top, spacing: 12) {
            marker
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                if let message {
                    Text(message).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                action
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tone.opacity(0.1), in: shape)
        .overlay(shape.strokeBorder(tone.opacity(0.55), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private var tone: Color {
        switch kind {
        case .partial, .denied: Palette.caution.color
        case .error: Palette.danger.color
        case .note: Palette.accent.color
        }
    }

    @ViewBuilder private var marker: some View {
        switch kind {
        case .partial: RiskLeaf(.medium, size: 16)
        case .denied: RiskLeaf(.medium, size: 16)
        case .error: WiltedLeaf().frame(width: 16, height: 16)
        case .note: SerreIcon(.overview, size: 16).foregroundStyle(Palette.accent.color)
        }
    }
}

/// An error leaf: drooping and still. Failure never bounces.
struct WiltedLeaf: View {
    var body: some View {
        RiskLeafShape(level: .low)
            .fill(Palette.danger.color)
            .rotationEffect(.degrees(35), anchor: .bottom)
            .accessibilityHidden(true)
    }
}

/// An empty or initial view: a seed with an invitation. The seed sprouts once when the view
/// appears; under Reduce Motion it is shown sprouted.
public struct SerreEmptyState<Action: View>: View {
    let title: String
    let message: String
    let action: Action
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    public init(title: String, message: String, @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: 14) {
            SerreGlyphShape(glyph: .overview)
                .trim(from: 0, to: grown ? 1 : 0)
                .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text(title).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
            Text(message).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            action
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(MotionToken.bloom.animation(.sap, reduceMotion: false)) { grown = true }
            }
        }
    }
}

/// The dimmed ground behind a layer drawn over the window (the command palette). It covers the
/// whole window; tapping it is how the layer is dismissed with the pointer.
public struct SerreScrim: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.45))
            .ignoresSafeArea()
            .contentShape(Rectangle())
    }
}
