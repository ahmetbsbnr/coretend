import SwiftUI
import AppShell
import DesignSystem
import Domain
import ScanCore

/// Where each destination's row sits in the window, so the content can grow from the row that
/// was chosen (UI guide § 8, "changement de destination").
struct SidebarRowFrames: PreferenceKey {
    static let defaultValue: [Destination: CGRect] = [:]
    static func reduce(value: inout [Destination: CGRect], nextValue: () -> [Destination: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The Serre sidebar, drawn by CoreTend instead of the system list: the germinating logo, the four
/// spaces, History at the foot, and a leaf marker that glides to the chosen row whatever chose it (click, command
/// palette, ⌘1…⌘5, arrow keys, menu bar). A vine then draws from the marker to the content edge
/// and fades; nothing moves at rest.
struct SerreSidebar: View {
    @Binding var selection: Destination?
    let french: Bool
    /// Shared with SearchLayer, so the palette grows out of the Search button.
    let searchNamespace: Namespace.ID
    let openSearch: () -> Void
    let openSettings: () -> Void

    @Environment(CoreTendNavigation.self) private var navigation
    @Namespace private var markerSpace
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vine = 0.0
    @State private var vineOpacity = 0.0
    @State private var hovered: Destination?
    @State private var snapshot: SystemSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            brand
            searchButton
            Color.clear.frame(height: 8)
            ForEach(Destination.sidebarOrder) { destination in row(destination) }
            Spacer(minLength: 16)
            terrarium
            HStack(spacing: 8) {
                footButton(ProductCopy.value(for: Destination.record.titleKey, french: french), glyph: Destination.record.glyph,
                           selected: selection == .record) { selection = .record }
                footButton(ProductCopy.value(for: "settings.title", french: french), glyph: .settings, selected: false, action: openSettings)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                AtmosphereBackdrop()
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(colors: [Palette.sidebar.color.opacity(0.55), Palette.sidebar.color.opacity(0.25)], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
        .overlayPreferenceValue(SidebarRowFrames.self) { frames in vineOverlay(frames) }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78), value: selection)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
        .onChange(of: selection) { _, _ in growVine() }
        .task {
            // The Clean figure is read once even when the app opens on another space.
            if navigation.cleanupReport == nil {
                let home = HomeFolder.url
                let exclusions = (try? await LocalStoreAccess.exclusions()) ?? []
                if let found = try? await Task.detached(priority: .utility, operation: { try await CleanupSurvey(home: home).run(exclusions: exclusions) }).value,
                   navigation.cleanupReport == nil {
                    navigation.cleanupReport = found
                    navigation.cleanupReportDate = .now
                }
            }
        }
        .task {
            while !Task.isCancelled {
                snapshot = await Task.detached(priority: .utility) { MacOSSystemSnapshotReader().read() }.value
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 11) {
            SerreLogo(size: 34, germinates: true).ambientSway(degrees: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text("CoreTend").font(.custom("IowanOldStyle-Bold", size: 21, relativeTo: .title3)).foregroundStyle(Palette.ink.color).lineLimit(1)
                Text(ProductCopy.inline("entretien local", "local care", french: french)).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
            }
        }
        .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }

    private var searchButton: some View {
        Button(action: openSearch) {
            HStack(spacing: 9) {
                SerreIcon(.search, size: 15)
                Text(ProductCopy.inline("Rechercher", "Search", french: french)).font(CoreTendTypography.body).lineLimit(1)
                Spacer(minLength: 4)
                Text("⌘K").font(CoreTendTypography.caption.monospaced())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Palette.ink.color.opacity(0.07), in: Capsule())
                    .foregroundStyle(Palette.tertiaryInk.color)
            }
            .foregroundStyle(Palette.secondaryInk.color)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .serreGlass(cornerRadius: 12, glow: false)
        }
        .buttonStyle(.serre(.bare))
        .matchedGeometryEffect(id: "search.button", in: searchNamespace, properties: .frame, isSource: true)
        .keyboardShortcut("k", modifiers: [.command])
        .help(ProductCopy.inline("Accéder à… (⌘K)", "Go to or open… (⌘K)", french: french))
        .accessibilityLabel(ProductCopy.value(for: "command.palette.title", french: french))
        .padding(.bottom, 4)
    }

    /// What each space measures right now, in a few words.
    private func metric(_ destination: Destination) -> String {
        switch destination {
        case .home:
            if let snapshot, case .known(let free) = snapshot.availableBytes {
                return ProductCopy.inline("%1$@ libres", "%1$@ free", french: french, ProductFormat.bytes(free, french: french))
            }
            return ProductCopy.inline("État du Mac", "Your Mac at a glance", french: french)
        case .space: return ProductCopy.inline("Carte, gros fichiers, doublons", "Map, large files, duplicates", french: french)
        case .clean:
            if let report = navigation.cleanupReport {
                return report.bytes > 0
                    ? ProductCopy.inline("%1$@ à récupérer", "%1$@ to give back", french: french, ProductFormat.bytes(report.bytes, french: french))
                    : ProductCopy.inline("Rien à nettoyer", "Nothing to clean", french: french)
            }
            return ProductCopy.inline("Lecture en cours…", "Reading…", french: french)
        case .apps: return ProductCopy.inline("Désinstaller, mises à jour", "Uninstall, updates", french: french)
        case .record: return ""
        }
    }

    private func row(_ destination: Destination) -> some View {
        let selected = selection == destination
        let hover = hovered == destination
        return Button {
            selection = destination
            focused = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected
                              ? AnyShapeStyle(LinearGradient(colors: [Palette.accent.color, Palette.accent.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Palette.ink.color.opacity(hover ? 0.10 : 0.06)))
                        .shadow(color: selected ? Palette.accent.color.opacity(0.45) : .clear, radius: 8, y: 3)
                    SerreIcon(destination.glyph, size: 17)
                        .foregroundStyle(selected ? Palette.onAccent.color : Palette.secondaryInk.color)
                        .ambientSway(degrees: selected ? 6 : 3, phase: Double(destination.shortcutNumber) * 0.61)
                }
                .frame(width: 34, height: 34)
                .scaleEffect(hover && !selected ? 1.06 : 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ProductCopy.value(for: destination.titleKey, french: french))
                        .lineLimit(1)
                        .font(CoreTendTypography.body.weight(selected ? .semibold : .medium))
                        .foregroundStyle(Palette.ink.color)
                    Text(metric(destination))
                        .font(CoreTendTypography.caption.monospacedDigit())
                        .foregroundStyle(selected ? Palette.accent.color : Palette.tertiaryInk.color)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                Text("⌘\(destination.shortcutNumber)").font(CoreTendTypography.caption.monospaced())
                    .foregroundStyle(Palette.tertiaryInk.color.opacity(hover ? 1 : 0))
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.serre(.bare))
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.accent.color.opacity(0.13))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Palette.accent.color.opacity(0.7), Palette.accent.color.opacity(0.1)], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                    .overlay { if focused { RoundedRectangle(cornerRadius: 16, style: .continuous).inset(by: -3).stroke(Palette.focus.color, lineWidth: 2) } }
                    .shadow(color: Palette.accent.color.opacity(0.25), radius: 12, y: 4)
                    .matchedGeometryEffect(id: "leaf-marker", in: markerSpace)
            } else if hover {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ink.color.opacity(0.05))
            }
        }
        .onHover { inside in withAnimation(.easeOut(duration: 0.15)) { hovered = inside ? destination : (hovered == destination ? nil : hovered) } }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: SidebarRowFrames.self, value: [destination: proxy.frame(in: .global)])
        })
        .keyboardShortcut(KeyEquivalent(Character(String(destination.shortcutNumber))), modifiers: .command)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    /// The disk as a terrarium: free space as a living liquid, measured by macOS.
    @ViewBuilder private var terrarium: some View {
        if let snapshot, case .known(let free) = snapshot.availableBytes, case .known(let total) = snapshot.totalBytes, total > 0 {
            Button { selection = .home } label: {
                HStack(spacing: 12) {
                    LiquidGauge(fraction: Double(free) / Double(total), tint: Palette.accent.color)
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProductFormat.bytes(free, french: french))
                            .font(.custom("IowanOldStyle-Bold", size: 18, relativeTo: .headline)).foregroundStyle(Palette.ink.color).lineLimit(1)
                            .contentTransition(.numericText())
                        Text(ProductCopy.inline("libres sur %1$@", "free of %1$@", french: french, ProductFormat.bytes(total, french: french)))
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color).lineLimit(1)
                        if case .known(let purgeable) = snapshot.purgeableBytes, purgeable > 0 {
                            Text(ProductCopy.inline("+ %1$@ purgeables", "+ %1$@ purgeable", french: french, ProductFormat.bytes(purgeable, french: french)))
                                .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .serreGlass(cornerRadius: 16)
            }
            .buttonStyle(.serre(.bare))
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private func footButton(_ title: String, glyph: SerreGlyph, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                SerreIcon(glyph, size: 14)
                Text(title).font(CoreTendTypography.secondary.weight(.medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? Palette.accent.color : Palette.secondaryInk.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .serreGlass(cornerRadius: 12, glow: false)
        }
        .buttonStyle(.serre(.bare))
        .accessibilityLabel(title)
    }

    /// A short vine from the marker to the sidebar's edge, towards the content that grows.
    @ViewBuilder
    private func vineOverlay(_ frames: [Destination: CGRect]) -> some View {
        GeometryReader { proxy in
            if let selection, let row = frames[selection], row != .zero {
                let local = proxy.frame(in: .global)
                let y = row.midY - local.minY
                let start = row.maxX - local.minX
                VeinLine(from: start, to: proxy.size.width, y: y, progress: vine)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .opacity(vineOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func growVine() {
        guard !reduceMotion else { return }
        vine = 0
        vineOpacity = 1
        withAnimation(MotionToken.quick.animation(reduceMotion: false)?.delay(0.2)) { vine = 1 }
        withAnimation(MotionToken.standard.animation(.retreat, reduceMotion: false)?.delay(0.7)) { vineOpacity = 0 }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        selection = (selection ?? .home).step(offset)
        return .handled
    }
}

/// A horizontal vine with a slight curl at its end, drawn up to `progress`.
private struct VeinLine: Shape {
    let from: CGFloat
    let to: CGFloat
    let y: CGFloat
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: from, y: y))
        path.addCurve(to: CGPoint(x: to, y: y - 3), control1: CGPoint(x: from + (to - from) * 0.4, y: y + 3), control2: CGPoint(x: from + (to - from) * 0.7, y: y - 5))
        return path.trimmedPath(from: 0, to: progress)
    }
}
