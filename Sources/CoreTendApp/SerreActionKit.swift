import DesignSystem
import SwiftUI
import AppShell
import Domain
import SafetyCore

// Pieces shared by the destinations that read a folder and may move files to the Trash
// (Cleanup, Explore, Duplicates, Applications): their banners, the leaf that falls from a moved
// file's row to the Trash indicator, and a move that reports each file as it goes.

/// A banner of a destination and the recovery it offers.
struct PageNotice: Equatable {
    enum Kind: Equatable { case note, partial, denied, error }
    enum Recovery: Equatable { case chooseAgain, retryScan }

    let kind: Kind
    let title: String
    var message: String?
    var recovery: Recovery?
    /// Outcomes of a review or a move are shown under the Trash, where the action happened.
    var nearActions = false

    /// What a finished move did, said under the Trash.
    static func moveOutcome(_ report: ActionBatchReport, french: Bool) -> PageNotice {
        let moved = report.movedCount
        let stayed = report.items.count - moved
        if stayed > 0 {
            return PageNotice(kind: .error,
                              title: french ? "\(moved) déplacé\(ProductFormat.frenchPlural(moved)) vers la Corbeille ; \(stayed) resté\(ProductFormat.frenchPlural(stayed)) en place."
                                            : "\(moved) moved to Trash; \(stayed) left in place.",
                              message: french ? "Chaque fichier resté en place dit pourquoi ; aucun n’a été effacé." : "Each file left in place says why; none was erased.",
                              nearActions: true)
        }
        return PageNotice(kind: .note,
                          title: french ? "\(moved) déplacé\(ProductFormat.frenchPlural(moved)) vers la Corbeille." : "\(moved) moved to Trash.",
                          message: french ? "Ils restent récupérables depuis la Corbeille de macOS." : "They can be restored from the macOS Trash.",
                          nearActions: true)
    }

    var bannerKind: SerreBannerKind {
        switch kind {
        case .note: .note
        case .partial: .partial
        case .denied: .denied
        case .error: .error
        }
    }
}

/// A PageNotice as a Serre banner, with its recovery button.
struct PageNoticeBanner: View {
    let notice: PageNotice
    let french: Bool
    let disabled: Bool
    let chooseAgain: () -> Void
    let retryScan: (() -> Void)?

    var body: some View {
        SerreBanner(notice.bannerKind, title: notice.title, message: notice.message) {
            switch notice.recovery {
            case .chooseAgain:
                Button(ProductCopy.value(for: "cleanup.denied.retry", french: french), action: chooseAgain)
                    .buttonStyle(.serre(.secondary)).disabled(disabled).padding(.top, 6)
            case .retryScan:
                if let retryScan {
                    Button(ProductCopy.value(for: "scan.retry", french: french), action: retryScan)
                        .buttonStyle(.serre(.secondary)).disabled(disabled).padding(.top, 6)
                }
            case nil:
                EmptyView()
            }
        }
    }
}

// MARK: - Leaf flight

struct FallingToken: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
}

private struct LeafRowFrames: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) { value.merge(nextValue()) { $1 } }
}

private struct LeafAnchorFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// Where the rows and the Trash indicator are, the leaves in the air, and how many files have
/// landed in the Trash during the current move.
@MainActor @Observable
final class LeafFlight {
    static let space = "leafFlight"

    var rowFrames: [URL: CGRect] = [:]
    var anchors: [String: CGRect] = [:]
    var falling: [FallingToken] = []
    /// Files counted by the Trash indicator for the current move.
    var landed = 0

    /// A moved file: its leaf falls from its row to the Trash, which counts it on landing. Without
    /// a known row or under Reduce Motion, the Trash counts it at once.
    func send(_ url: URL, reduceMotion: Bool) {
        guard !reduceMotion, let frame = rowFrames[url], let trash = anchors["trash"] else {
            landed += 1
            return
        }
        let list = anchors["list"] ?? frame
        // From the file's name, not from the selection mark it would hide behind.
        let start = CGPoint(x: frame.minX + 90, y: min(max(frame.midY, list.minY + 12), list.maxY - 12))
        let token = FallingToken(from: start, to: CGPoint(x: trash.minX + 18, y: trash.midY))
        falling.append(token)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FallingLeaf.duration))
            falling.removeAll { $0.id == token.id }
            withAnimation(MotionCurve.sprout.animation(duration: 0.3)) { landed += 1 }
        }
    }
}

extension View {
    /// The layer the leaves fall in; put it on the destination's whole content.
    func leafFlightLayer(_ flight: LeafFlight) -> some View {
        coordinateSpace(name: LeafFlight.space)
            .onPreferenceChange(LeafRowFrames.self) { flight.rowFrames = $0 }
            .onPreferenceChange(LeafAnchorFrames.self) { flight.anchors = $0 }
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(flight.falling) { FallingLeaf(from: $0.from, to: $0.to) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
            }
    }

    /// A result row a leaf may fall from.
    func leafFlightRow(_ url: URL) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: LeafRowFrames.self, value: [url: proxy.frame(in: .named(LeafFlight.space))])
        })
    }

    /// A named place in the layer: "list" (leaves start inside it) or "trash" (they land there).
    func leafFlightAnchor(_ name: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: LeafAnchorFrames.self, value: [name: proxy.frame(in: .named(LeafFlight.space))])
        })
    }
}

/// The Trash indicator: leaves land on it, it counts them and takes each with a small start.
struct TrashIndicator: View {
    let landed: Int
    let moving: Bool
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trash").foregroundStyle(Palette.ink.color)
                Text(ProductCopy.value(for: "cleanup.trash", french: french)).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                if landed > 0 {
                    Text(ProductFormat.count(landed, french: french))
                        .font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.onAccent.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Palette.accent.color, in: LeafCorner.control.shape)
                        .contentTransition(.numericText(value: Double(landed)))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
            .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : landed) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(1.12, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.3)
            }
            .leafFlightAnchor("trash")
            .accessibilityElement(children: .combine)
            .accessibilityLabel(landed > 0
                ? "\(ProductCopy.value(for: "cleanup.moved", french: french)) : \(landed)"
                : ProductCopy.value(for: "cleanup.trash", french: french))
            if moving {
                Text(ProductCopy.value(for: "cleanup.moving", french: french))
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
        }
    }
}

/// Runs a confirmed batch and hands each item to `each` on the main actor as soon as its outcome
/// is final (the first 24 a little apart, so each leaf can be seen leaving).
@MainActor
func executeShowingEachItem(_ service: FileActionService, _ batch: ConfirmedActionBatch, reduceMotion: Bool,
                            each: @MainActor (ActionItemResult) -> Void) async -> ActionBatchReport {
    let (outcomes, continuation) = AsyncStream.makeStream(of: ActionItemResult.self)
    let worker = Task {
        let report = await service.execute(batch) { _ = continuation.yield($0) }
        continuation.finish()
        return report
    }
    var shown = 0
    for await item in outcomes {
        each(item)
        shown += 1
        if shown <= 24 && !reduceMotion { try? await Task.sleep(for: .milliseconds(90)) }
    }
    return await worker.value
}
