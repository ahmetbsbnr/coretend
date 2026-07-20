import SwiftUI

/// Cleanup's visual motif: category fragments, aggregated (never per-file).
/// Each fragment represents one rule group; its width is real (proportional
/// to that group's share of found bytes), never decorative. Selection is
/// shown by fill + outline + checkmark together, never color alone.
/// Static layout — no timers; transitions only follow real phase changes.
public struct MCFragmentSpec: Identifiable, Equatable {
    public enum Selection { case none, partial, all }

    public let id: String
    public let label: String
    public let fraction: Double        // share of total bytes, 0...1
    public let selection: Selection
    public let tint: Color

    public init(id: String, label: String, fraction: Double, selection: Selection, tint: Color) {
        self.id = id
        self.label = label
        self.fraction = min(1, max(0, fraction))
        self.selection = selection
        self.tint = tint
    }

    public static func == (lhs: MCFragmentSpec, rhs: MCFragmentSpec) -> Bool {
        lhs.id == rhs.id && lhs.fraction == rhs.fraction && lhs.selection == rhs.selection
    }
}

/// Lightness state for the "settle" moment after a real action completes.
public enum MCFragmentPhase { case normal, moving, settled }

public struct MCFragmentView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fragments: [MCFragmentSpec]
    private let phase: MCFragmentPhase

    public init(fragments: [MCFragmentSpec], phase: MCFragmentPhase = .normal) {
        self.fragments = fragments
        self.phase = phase
    }

    public var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let minWidth: CGFloat = 8
            HStack(spacing: MCSpacing.xxs) {
                ForEach(fragments) { fragment in
                    fragmentShape(fragment, minWidth: minWidth, totalWidth: totalWidth)
                }
            }
        }
        .frame(height: 44)
        .opacity(phase == .moving ? 0.45 : (phase == .settled ? 0.7 : 1))
        .animation(MCMotion.animation(MCMotion.ease, reduce: reduceMotion), value: phase)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func fragmentShape(_ fragment: MCFragmentSpec, minWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let width = max(minWidth, totalWidth * fragment.fraction)
        RoundedRectangle(cornerRadius: MCRadius.small)
            .fill(fillStyle(for: fragment))
            .overlay(
                RoundedRectangle(cornerRadius: MCRadius.small)
                    .strokeBorder(fragment.tint.opacity(fragment.selection == .none ? 0.5 : 0.9),
                                  style: StrokeStyle(lineWidth: fragment.selection == .partial ? 2 : 1,
                                                      dash: fragment.selection == .none ? [3, 3] : []))
            )
            .overlay(alignment: .topTrailing) {
                if fragment.selection == .all {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white, fragment.tint)
                        .padding(2)
                }
            }
            .frame(width: width)
    }

    private func fillStyle(for fragment: MCFragmentSpec) -> Color {
        switch fragment.selection {
        case .all: return fragment.tint.opacity(reduceTransparency ? 1 : 0.85)
        case .partial: return fragment.tint.opacity(reduceTransparency ? 0.6 : 0.45)
        case .none: return reduceTransparency ? Color.secondary.opacity(0.25) : Color.secondary.opacity(0.12)
        }
    }

    /// VoiceOver-facing summary — the accessible list elsewhere carries the
    /// real detail; this is a one-line orientation cue for the decorative strip.
    public nonisolated static func accessibilityDescription(fragments: [MCFragmentSpec]) -> String {
        guard !fragments.isEmpty else { return "No categories found yet." }
        let selected = fragments.filter { $0.selection != .none }.count
        return "\(fragments.count) categories, \(selected) with items selected."
    }
}
