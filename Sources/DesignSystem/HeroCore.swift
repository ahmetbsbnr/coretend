import SwiftUI

/// State of the Hero Core. Mirrors real orchestration states only.
public enum MCHeroState: Equatable {
    case idle
    case scanning(storage: Double?, protection: Double?, performance: Double?)
    case review
    case running
    case success
    case error
}

/// The Smart Care centerpiece: nucleus + three orbital arcs that reflect the
/// real state of the scan. Not a button — the primary action lives below it.
public struct MCHeroCoreView: View {
    private let state: MCHeroState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: MCHeroState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            // Halo — success only, brief and calm.
            Circle()
                .fill(MCColor.success.opacity(state == .success ? MCOpacity.halo : 0))
                .blur(radius: 18)
                .animation(MCMotion.animation(MCMotion.settle, reduce: reduceMotion), value: state)

            OrbitalProgressView(tracks: tracks, animating: isAnimating)

            nucleus
        }
        .frame(width: MCSize.heroCore, height: MCSize.heroCore)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var isAnimating: Bool {
        if case .scanning = state { return true }
        return state == .running
    }

    private var tracks: [OrbitalProgressView.Track] {
        switch state {
        case .idle, .review:
            return [
                .init(id: "Storage", color: MCColor.storage, progress: 1),
                .init(id: "Protection", color: MCColor.protection, progress: 1),
                .init(id: "Performance", color: MCColor.performance, progress: 1),
            ]
        case let .scanning(s, p, f):
            return [
                .init(id: "Storage", color: MCColor.storage, progress: s),
                .init(id: "Protection", color: MCColor.protection, progress: p),
                .init(id: "Performance", color: MCColor.performance, progress: f),
            ]
        case .running:
            return [
                .init(id: "Storage", color: MCColor.storage, progress: nil),
                .init(id: "Protection", color: MCColor.protection, progress: 1),
                .init(id: "Performance", color: MCColor.performance, progress: 1),
            ]
        case .success:
            return [
                .init(id: "Storage", color: MCColor.success, progress: 1),
                .init(id: "Protection", color: MCColor.success, progress: 1),
                .init(id: "Performance", color: MCColor.success, progress: 1),
            ]
        case .error:
            return [
                .init(id: "Storage", color: MCColor.attention, progress: 1),
                .init(id: "Protection", color: MCColor.attention, progress: 0.5),
                .init(id: "Performance", color: MCColor.attention, progress: 0.5),
            ]
        }
    }

    @ViewBuilder
    private var nucleus: some View {
        let side = MCSize.heroCore * MCBloomGeometry.nucleusFraction * 1.6
        ZStack {
            Circle()
                .fill(nucleusColor.gradient)
                .frame(width: side, height: side)
            Image(systemName: nucleusSymbol)
                .font(.system(size: side * 0.42, weight: .medium))
                .foregroundStyle(.white)
        }
        .animation(MCMotion.animation(MCMotion.snappy, reduce: reduceMotion), value: state)
    }

    private var nucleusColor: Color {
        switch state {
        case .success: MCColor.success
        case .error: MCColor.attention
        default: MCColor.coreMint
        }
    }

    private var nucleusSymbol: String {
        switch state {
        case .idle: "circle.hexagonpath"
        case .scanning: "rays"
        case .review: "list.bullet.clipboard"
        case .running: "arrow.triangle.2.circlepath"
        case .success: "checkmark"
        case .error: "exclamationmark"
        }
    }

    private var accessibilityText: String {
        switch state {
        case .idle: "System overview, idle"
        case .scanning: "Scan in progress"
        case .review: "Scan complete, results ready for review"
        case .running: "Cleaning in progress"
        case .success: "Care finished successfully"
        case .error: "Care finished with errors"
        }
    }
}
