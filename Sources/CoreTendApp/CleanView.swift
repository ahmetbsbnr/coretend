import DesignSystem
import AppKit
import SwiftUI
import ScanCore
import ProductContract
import AppShell
import SafetyCore
import Domain

/// The Clean space: every rule read at once, grouped by what it is, safe items already ticked,
/// one review, one move to the Trash, and an Undo that puts everything back.
struct CleanView: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CoreTendNavigation.self) private var navigation

    enum Phase: Equatable { case idle, scanning, ready, failed }

    @State private var phase = Phase.idle
    @State private var filesRead = 0
    @State private var report: CleanupSurveyReport?
    @State private var selected: Set<URL> = []
    @State private var expanded: Set<ScanRule> = []
    @State private var task: Task<Void, Never>?
    @State private var notice: PageNotice?
    @State private var confirming = false
    @State private var pending: (review: ActionReview, service: FileActionService)?
    @State private var busy = false
    @State private var moving = false
    @State private var flight = LeafFlight()
    @State private var failures: [URL: String] = [:]
    /// What the last move put in the Trash, so Undo can put it back.
    @State private var lastMoved: [(trash: URL, original: URL)] = []

    private var groups: [CleanupGroup] { report?.groups ?? [] }
    private var allItems: [CleanupItem] { groups.flatMap(\.items) }
    private var selectedBytes: Int64 { allItems.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            summary
            switch phase {
            case .idle, .scanning: scanningState
            case .failed:
                SerreBanner(.error, title: copy("clean.failed")) {
                    Button(copy("clean.rescan")) { start() }.padding(.top, 6)
                }
            case .ready:
                if groups.isEmpty {
                    SerreEmptyState(title: copy("clean.empty.title"), message: copy("clean.empty.message"))
                } else {
                    VStack(spacing: 10) { ForEach(groups) { group($0) } }
                }
            }
            if let notice { PageNoticeBanner(notice: notice, french: french, disabled: busy, chooseAgain: {}, retryScan: { start() }) }
            if !lastMoved.isEmpty { undoBar }
        }
        .leafFlightLayer(flight)
        .preference(key: PlantActivityKey.self, value: phase == .scanning ? .growing : (phase == .ready ? .blooming : .resting))
        .task {
            guard report == nil else { return }
            // A read made by the Home a few minutes ago is used as is.
            if let shared = navigation.cleanupReport, let date = navigation.cleanupReportDate, date > .now - 300 {
                adopt(shared)
            } else {
                start()
            }
        }
        .onDisappear { task?.cancel() }
        .confirmationDialog(copy("clean.confirm.title"), isPresented: $confirming, titleVisibility: .visible) {
            Button(copy("clean.confirm.action"), role: .destructive) { execute() }
            Button(copy("common.cancel"), role: .cancel) { cancelReview() }.keyboardShortcut(.defaultAction)
        } message: {
            Text(confirmMessage)
        }
        .onChange(of: confirming) { _, shown in if !shown && pending != nil { cancelReview() } }
    }

    // MARK: - Sections

    /// The answer first: how much can go, and the one button that does it.
    private var summary: some View {
        SerreParcel {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ProductFormat.bytes(phase == .ready ? selectedBytes : 0, french: french))
                        .font(CoreTendTypography.hero).foregroundStyle(Palette.ink.color)
                        .contentTransition(.numericText())
                        .motion(.standard, value: selectedBytes)
                    Text(summaryCaption)
                        .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    TrashIndicator(landed: flight.landed, moving: moving, french: french)
                    HStack(spacing: 8) {
                        Button { start() } label: { Label(copy("clean.rescan"), systemImage: "arrow.clockwise") }
                            .buttonStyle(.serre(.secondary))
                            .disabled(phase == .scanning || busy)
                        Button { Task { await review() } } label: { Text(copy("clean.review")) }
                            .buttonStyle(.serre(.primary))
                            .keyboardShortcut(.defaultAction)
                            .disabled(selected.isEmpty || phase != .ready || busy)
                    }
                }
            }
        }
    }

    private var summaryCaption: String {
        switch phase {
        case .idle, .scanning: copy("clean.reading")
        case .failed: copy("clean.failed")
        case .ready:
            if groups.isEmpty { copy("clean.empty.title") }
            else if selected.isEmpty { copy("clean.noneSelected") }
            else { french ? "sélectionnés sur \(ProductFormat.bytes(report?.bytes ?? 0, french: true)) trouvés · tout part à la Corbeille"
                          : "selected of \(ProductFormat.bytes(report?.bytes ?? 0, french: false)) found · everything goes to the Trash" }
        }
    }

    private var scanningState: some View {
        SerreParcel {
            HStack(spacing: 14) {
                ProgressView().controlSize(.small)
                Text(french ? "\(ProductFormat.count(filesRead, french: true)) fichiers lus…" : "\(ProductFormat.count(filesRead, french: false)) files read…")
                    .font(CoreTendTypography.body.monospacedDigit()).foregroundStyle(Palette.secondaryInk.color)
                    .contentTransition(.numericText())
                Spacer()
                Button(copy("scan.cancel")) { task?.cancel(); phase = report == nil ? .idle : .ready }
                    .buttonStyle(.serre(.secondary))
            }
        }
    }

    private func group(_ group: CleanupGroup) -> some View {
        let ids = Set(group.items.map(\.url))
        let chosen = ids.intersection(selected).count
        let open = expanded.contains(group.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button { toggleGroup(ids) } label: {
                    SerreCheck(isOn: chosen == ids.count)
                        .opacity(chosen > 0 && chosen < ids.count ? 0.55 : 1)
                }
                .buttonStyle(.serre(.icon))
                .accessibilityLabel(copy(group.rule.titleKey))
                .accessibilityValue(chosen == ids.count ? copy("clean.all") : (chosen == 0 ? copy("clean.none") : "\(chosen)/\(ids.count)"))
                Button { withAnimation(reduceMotion ? nil : .snappy) { toggleExpanded(group.id) } } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy(group.rule.titleKey)).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                            Text(copy(group.rule.explanationKey)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        SerreRiskBadge(riskLevel(group.rule.risk), label: copy("cleanup.risk.\(group.rule.risk.rawValue)"))
                        Text(ProductFormat.bytes(group.bytes, french: french))
                            .font(CoreTendTypography.body.monospacedDigit()).foregroundStyle(Palette.ink.color)
                            .frame(minWidth: 80, alignment: .trailing)
                        Image(systemName: "chevron.right").rotationEffect(.degrees(open ? 90 : 0))
                            .foregroundStyle(Palette.tertiaryInk.color)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.serre(.row(selected: false)))
                .accessibilityHint(copy("clean.expand.hint"))
            }
            .padding(14)
            if open {
                Palette.separator.color.frame(height: 1)
                LazyVStack(spacing: 2) {
                    ForEach(group.items.prefix(200)) { item in itemRow(item) }
                    if group.items.count > 200 {
                        Text(french ? "… et \(group.items.count - 200) autres" : "… and \(group.items.count - 200) more")
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color).padding(8)
                    }
                }
                .padding(8)
            }
        }
        .background(Palette.surface.color, in: LeafCorner.parcel.shape)
        .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
        .disabled(busy)
    }

    private func itemRow(_ item: CleanupItem) -> some View {
        let isOn = selected.contains(item.url)
        return Button { toggle(item.url) } label: {
            HStack(spacing: 12) {
                SerreCheck(isOn: isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.url.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        .lineLimit(1).truncationMode(.middle)
                    if let failure = failures[item.url] {
                        Text(copy(failure)).font(CoreTendTypography.caption).foregroundStyle(Palette.danger.color)
                    } else {
                        Text(HomeFolder.displayPath(item.url.deletingLastPathComponent()))
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                Text(ProductFormat.bytes(item.bytes, french: french) + (item.unknownFiles > 0 ? "+" : ""))
                    .font(CoreTendTypography.secondary.monospacedDigit()).foregroundStyle(Palette.secondaryInk.color)
            }
        }
        .buttonStyle(.serre(.row(selected: isOn)))
        .leafFlightRow(item.url)
        .contextMenu {
            Button(copy("clean.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }

    private var undoBar: some View {
        SerreBanner(.note, title: french ? "\(ProductFormat.items(lastMoved.count, french: true)) dans la Corbeille." : "\(ProductFormat.items(lastMoved.count, french: false)) in the Trash.") {
            Button(copy("clean.undo")) { undo() }.padding(.top, 6).disabled(busy)
        }
    }

    // MARK: - Actions

    private func start() {
        task?.cancel()
        phase = .scanning; filesRead = 0; notice = nil; failures = [:]
        let home = HomeFolder.url
        task = Task {
            do {
                let exclusions = (try? await LocalStoreAccess.exclusions()) ?? []
                let counter = ProgressRelay { count in Task { @MainActor in filesRead = count } }
                let found = try await Task.detached(priority: .userInitiated) {
                    try await CleanupSurvey(home: home).run(exclusions: exclusions, progress: counter.send)
                }.value
                guard !Task.isCancelled else { return }
                navigation.cleanupReport = found
                navigation.cleanupReportDate = .now
                adopt(found)
            } catch is CancellationError {
            } catch {
                phase = .failed
            }
        }
    }

    private func adopt(_ found: CleanupSurveyReport) {
        report = found
        // Safe items are ticked; anything to check first is left for the person to choose.
        selected = Set(found.groups.flatMap(\.items).filter { $0.risk == .low }.map(\.url))
        expanded = []
        phase = .ready
    }

    private func toggle(_ url: URL) {
        if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
    }

    private func toggleGroup(_ ids: Set<URL>) {
        if ids.isSubset(of: selected) { selected.subtract(ids) } else { selected.formUnion(ids) }
    }

    private func toggleExpanded(_ rule: ScanRule) {
        if expanded.contains(rule) { expanded.remove(rule) } else { expanded.insert(rule) }
    }

    @MainActor private func review() async {
        guard !selected.isEmpty, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let store = try await LocalStoreAccess.open()
            let items = allItems.filter { selected.contains($0.url) }
            let roots = CleanupSurvey(home: HomeFolder.url).presentRoots().map(\.root)
            let rules = Set(items.map(\.ruleID.rawValue))
            let executor = SafeActionExecutor(allowedRoots: roots, allowedRules: rules, trash: AppTrashClient.make())
            let service = FileActionService(validator: .init(), executor: executor, store: store, allowedRoots: roots, allowedRuleIDs: rules)
            let review = try service.prepareReview(items.map { FileActionSelection(url: $0.url, ruleID: $0.ruleID.rawValue) })
            guard await service.recordProposal(review) else {
                notice = PageNotice(kind: .error, title: copy("spacelens.delete.blocked"), nearActions: true)
                return
            }
            pending = (review, service)
            confirming = true
        } catch {
            notice = PageNotice(kind: .error, title: copy("clean.reviewFailed"), nearActions: true)
        }
    }

    private var confirmMessage: String {
        let count = pending?.review.items.count ?? 0
        let size = ProductFormat.bytes(selectedBytes, french: french)
        return french ? "\(ProductFormat.items(count, french: true)), \(size). Tout part à la Corbeille et peut être remis en place avec Annuler."
                      : "\(ProductFormat.items(count, french: false)), \(size). Everything goes to the Trash and can be put back with Undo."
    }

    private func execute() {
        guard let pending else { return }
        self.pending = nil
        confirming = false
        busy = true; moving = true
        Task { @MainActor in
            defer { busy = false; moving = false }
            let batch: ConfirmedActionBatch
            do { batch = try pending.service.confirm(pending.review, accepted: true) } catch {
                notice = PageNotice(kind: .error, title: copy("clean.reviewFailed"), nearActions: true); return
            }
            flight.landed = 0; failures = [:]; notice = nil; lastMoved = []
            let result = await executeShowingEachItem(pending.service, batch, reduceMotion: reduceMotion) { item in
                if case .movedToTrash(let original, let trash) = item.outcome {
                    lastMoved.append((URL(fileURLWithPath: trash), URL(fileURLWithPath: original)))
                    flight.send(item.targetURL, reduceMotion: reduceMotion)
                    remove(item.targetURL)
                } else {
                    failures[item.targetURL] = item.failureKey
                    selected.remove(item.targetURL)
                }
            }
            if result.movedCount < result.items.count { notice = .moveOutcome(result, french: french) }
        }
    }

    private func remove(_ url: URL) {
        selected.remove(url)
        guard let current = report else { return }
        let groups = current.groups.compactMap { group -> CleanupGroup? in
            var copy = group
            copy.items.removeAll { $0.url == url }
            return copy.items.isEmpty ? nil : copy
        }
        let updated = CleanupSurveyReport(groups: groups, issues: current.issues)
        navigation.cleanupReport = updated
        withAnimation(reduceMotion ? nil : .snappy) { report = updated }
    }

    private func cancelReview() {
        guard let pending else { return }
        self.pending = nil
        Task { _ = await pending.service.recordCancellation(pending.review) }
    }

    private func undo() {
        let moved = lastMoved
        busy = true
        Task { @MainActor in
            defer { busy = false }
            var putBack = 0
            for entry in moved {
                if (try? TrashRestorer().restore(entry.trash, to: entry.original)) != nil { putBack += 1 }
            }
            lastMoved = []
            notice = PageNotice(kind: putBack == moved.count ? .note : .partial,
                                title: french ? "\(putBack) remis en place sur \(moved.count)." : "\(putBack) of \(moved.count) put back.",
                                nearActions: true)
            start()
        }
    }

    private func riskLevel(_ risk: CandidateRisk) -> RiskLevel {
        switch risk {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}

/// Hands a scan's file count to the main actor at most ten times a second.
final class ProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var last = Date.distantPast
    private let deliver: @Sendable (Int) -> Void

    init(_ deliver: @escaping @Sendable (Int) -> Void) { self.deliver = deliver }

    func send(_ count: Int) {
        lock.lock()
        let now = Date()
        let due = now.timeIntervalSince(last) >= 0.1
        if due { last = now }
        lock.unlock()
        if due { deliver(count) }
    }
}
