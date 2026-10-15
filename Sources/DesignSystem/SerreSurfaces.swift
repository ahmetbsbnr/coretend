import SwiftUI

/// A parcel: the Serre card (UI guide § 7). Surface fill, leaf corners, a decorative outline.
/// Never nest one parcel in another; use a separator inside instead.
public struct SerreParcel<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A parcel takes one breath when it appears: it settles into the page.
    @State private var settled = false

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Decision 0008: tinted glass, never a flat white card.
            .serreGlass()
            .scaleEffect(settled ? 1 : 0.985)
            .onAppear {
                guard !settled else { return }
                if reduceMotion { settled = true; return }
                withAnimation(MotionCurve.sprout.animation(duration: 0.6)) { settled = true }
            }
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
                // The words read as one element; the action stays its own button for VoiceOver.
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                    if let message {
                        Text(message).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                action
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tone.opacity(0.1), in: shape)
        .overlay(shape.strokeBorder(tone.opacity(0.55), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
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

/// An empty or initial view (decision 0008): a seed of light at the centre of a glass stage,
/// waves rising from it and motes orbiting, with an invitation below. Still under Reduce Motion
/// or when ambient motion is paused.
public struct SerreEmptyState<Action: View>: View {
    let title: String
    let message: String
    let action: Action
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.serreAmbientAllowed) private var allowed
    @State private var grown = false

    public init(title: String, message: String, @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !allowed)) { timeline in
                    let t = allowed ? timeline.date.timeIntervalSinceReferenceDate : 0
                    Canvas { context, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        for ring in 0..<4 {
                            let p = (t * 0.35 + Double(ring) / 4).truncatingRemainder(dividingBy: 1)
                            let r = 20 + p * min(size.width, size.height) * 0.48
                            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                           with: .color(Palette.accent.color.opacity(0.35 * (1 - p))), lineWidth: 1.5)
                        }
                        context.fill(Path(ellipseIn: CGRect(x: c.x - 70, y: c.y - 70, width: 140, height: 140)),
                                     with: .radialGradient(Gradient(colors: [Palette.accent.color.opacity(0.35), .clear]), center: c, startRadius: 0, endRadius: 70))
                        for mote in 0..<10 {
                            let a = t * (0.4 + Double(mote) * 0.05) + Double(mote) * 0.63
                            let r = 46 + Double(mote % 4) * 14
                            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.6)
                            context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(Palette.accent.color.opacity(0.7)))
                        }
                    }
                }
                SerreGlyphShape(glyph: .overview)
                    .trim(from: 0, to: grown ? 1 : 0)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 64, height: 64)
                    .shadow(color: Palette.accent.color.opacity(0.6), radius: 10)
            }
            .frame(height: 170)
            .accessibilityHidden(true)
            Text(title).font(.custom("IowanOldStyle-Bold", size: 28, relativeTo: .title)).foregroundStyle(Palette.ink.color)
                .multilineTextAlignment(.center)
            Text(message).font(CoreTendTypography.lede).foregroundStyle(Palette.secondaryInk.color)
                .multilineTextAlignment(.center).frame(maxWidth: 520)
            action
        }
        .padding(.vertical, 28)
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
