import DesignSystem
import SwiftUI
import UniformTypeIdentifiers
import ScanCore
import ProductContract
import AppShell
import SafetyCore
import Domain

/// Where each result row and the Trash indicator sit, so a moved file's leaf can fall from its
/// row to the Trash.
private struct CleanupRowFrames: PreferenceKey {
    static let defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) { value.merge(nextValue()) { $1 } }
}

private struct CleanupAnchorFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// A banner of the Cleanup view and the recovery it offers.
private struct CleanupNotice: Equatable {
    enum Recovery: Equatable { case chooseAgain, retryScan }
    let kind: Kind
    let title: String
    var message: String?
    var recovery: Recovery?
    /// Outcomes of a review or a move are shown under the Trash, where the action happened.
    var nearActions = false

    enum Kind: Equatable { case note, partial, denied, error }
    var bannerKind: SerreBannerKind {
        switch kind {
        case .note: .note
        case .partial: .partial
        case .denied: .denied
        case .error: .error
        }
    }
}

private struct FallingToken: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
}

/// Cleanup, "la taille": known rules, the exact folder, a read-only scan whose roots follow the
/// real progress, then a review, a confirmation and a move to the macOS Trash where each moved
/// file falls as a leaf and each file that stays says why.
struct CleanupView: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRule: ScanRule?
    @State private var selectedRoot: URL?
    @State private var choosingFolder = false
    @State private var results: [ScanResult] = []
    @State private var notice: CleanupNotice?
    @State private var scanning = false
    @State private var scanFoundNothing = false
    @State private var scanCompletedFiles = 0
    @State private var rootsPhase: ScanRootsPhase?
    @State private var task: Task<Void, Never>?
    @State private var activeScanID: UUID?
    @State private var selectedItems: Set<URL> = []
    @State private var actionReview: ActionReview?
    @State private var actionDialogPresented = false
    @State private var actionService: FileActionService?
    @State private var actionBusy = false
    @State private var moving = false
    @State private var actionScopeHeld = false
    @State private var actionScopedRoot: URL?
    /// Files that stayed where they were after a move, with the copy key saying why.
    @State private var failures: [URL: String] = [:]
    @State private var movedInAction = 0
    @State private var rowFrames: [URL: CGRect] = [:]
    @State private var anchors: [String: CGRect] = [:]
    @State private var falling: [FallingToken] = []

    private static let space = "cleanup"

    private var descriptor: CleanupRuleDescriptor? {
        selectedRule.flatMap(CleanupRuleCatalog.rule)
    }

    private var locked: Bool { scanning || actionBusy || actionReview != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            rules
            if let descriptor { expectedFolder(descriptor) }
            if let notice, !notice.nearActions { banner(notice) }
            if let rootsPhase { roots(rootsPhase) }
            if scanFoundNothing {
                SerreEmptyState(title: copy("cleanup.none"), message: copy("cleanup.none.help"))
            }
            if !results.isEmpty || movedInAction > 0 { resultsSection }
            if let notice, notice.nearActions { banner(notice) }
            Text(copy("cleanup.noAction"))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.tertiaryInk.color)
        }
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(CleanupRowFrames.self) { rowFrames = $0 }
        .onPreferenceChange(CleanupAnchorFrames.self) { anchors = $0 }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(falling) { FallingLeaf(from: $0.from, to: $0.to) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .motion(.standard, value: notice)
        .motion(.standard, value: rootsPhase)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { outcome in
            guard case .success(let urls) = outcome else { return }
            guard let url = urls.first, let descriptor, descriptor.isExpectedRoot(url) else {
                selectedRoot = nil
                notice = CleanupNotice(kind: .denied, title: copy("cleanup.rootMismatch"), recovery: .chooseAgain)
                return
            }
            selectedRoot = url
            notice = nil
        }
        .onDisappear { task?.cancel(); activeScanID = nil; scanning = false; if actionReview != nil { cancelAction() } }
        .confirmationDialog(french ? "Déplacer vers la Corbeille macOS ?" : "Move to macOS Trash?", isPresented: $actionDialogPresented, titleVisibility: .visible) {
            Button(french ? "Déplacer vers la Corbeille" : "Move to Trash", role: .destructive) { beginExecution() }
            Button(copy("common.cancel"), role: .cancel) { cancelAction() }
                // Return cancels: a move to the Trash is only ever a deliberate click.
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(reviewMessage)
        }
        .onChange(of: actionDialogPresented) { _, presented in
            if !presented && actionReview != nil { cancelAction() }
        }
    }

    // MARK: - Sections

    private var rules: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 6) {
                Text(copy("cleanup.rules")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text(copy("cleanup.intro")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                    .padding(.bottom, 6)
                ForEach(CleanupRuleCatalog.rules, id: \.id) { rule in
                    let selected = selectedRule == rule.id
                    Button { choose(rule.id) } label: {
                        HStack(spacing: 12) {
                            SerreCheck(isOn: selected)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(copy(rule.titleKey)).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                                Text(copy(rule.explanationKey)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            }
                            Spacer(minLength: 8)
                            SerreRiskBadge(riskLevel(rule.risk), label: riskLabel(rule.risk))
                        }
                    }
                    .buttonStyle(.serre(.row(selected: selected)))
                    .disabled(locked)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .motion(.quick, value: selectedRule)
    }

    private func expectedFolder(_ descriptor: CleanupRuleDescriptor) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 10) {
                Text(copy("cleanup.expected")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Text("~/" + descriptor.relativePath.joined(separator: "/"))
                    .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color).textSelection(.enabled)
                Text(copy("cleanup.expected.help"))
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let selectedRoot {
                    HStack(spacing: 8) {
                        SerreIcon(.explore, size: 14).foregroundStyle(Palette.accent.color)
                        Text(selectedRoot.path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
                HStack(spacing: 10) {
                    Button(copy("cleanup.choose")) { choosingFolder = true }
                        .buttonStyle(.serre(.secondary))
                        .disabled(locked)
                        .accessibilityHint(copy("cleanup.choose.hint"))
                    if let selectedRoot {
                        Button { startScan(descriptor, root: selectedRoot) } label: {
                            Label { Text(copy("cleanup.scan")) } icon: { SerreIcon(.search, size: 15) }
                        }
                        .buttonStyle(.serre(.primary))
                        .disabled(locked)
                        .accessibilityHint(copy("cleanup.scan.hint"))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func roots(_ phase: ScanRootsPhase) -> some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                ScanRoots(completed: scanCompletedFiles,
                          count: ProductFormat.count(scanCompletedFiles, french: french),
                          caption: ProductFormat.filesExamined(scanCompletedFiles, french: french) + "\n"
                              + copy(phase == .finished ? "scan.finished" : "scan.reading"),
                          phase: phase)
                if phase == .reading {
                    Button(copy("scan.cancel")) { cancelScan() }
                        .buttonStyle(.serre(.secondary))
                }
            }
        }
        .transition(.opacity)
    }

    private func banner(_ notice: CleanupNotice) -> some View {
        SerreBanner(notice.bannerKind, title: notice.title, message: notice.message) {
            switch notice.recovery {
            case .chooseAgain:
                Button(copy("cleanup.denied.retry")) { choosingFolder = true }
                    .buttonStyle(.serre(.secondary)).disabled(locked).padding(.top, 6)
            case .retryScan:
                if let descriptor, let selectedRoot {
                    Button(copy("scan.retry")) { startScan(descriptor, root: selectedRoot) }
                        .buttonStyle(.serre(.secondary)).disabled(locked).padding(.top, 6)
                }
            case nil:
                EmptyView()
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(french ? "\(ProductFormat.items(results.count, french: true)) mesuré\(ProductFormat.frenchPlural(results.count))" : "\(ProductFormat.items(results.count, french: false)) measured")
                    .font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                Spacer()
                Text(french ? "Aucune sélection automatique" : "Nothing selected automatically")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                if !selectedItems.isEmpty {
                    Button(copy("cleanup.selectNone")) { selectedItems = [] }
                        .buttonStyle(.serre(.icon)).disabled(locked)
                }
            }
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results, id: \.url) { row($0) }
                }
                .padding(8)
            }
            .frame(height: min(CGFloat(max(results.count, 1)) * 50 + 16, 340))
            .background(Palette.surface.color, in: LeafCorner.parcel.shape)
            .overlay(LeafCorner.parcel.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
            .background(anchorReader("list"))
            actionBar
        }
    }

    private func row(_ item: ScanResult) -> some View {
        let selected = selectedItems.contains(item.url)
        let failure = failures[item.url]
        return Button { toggle(item.url) } label: {
            HStack(spacing: 12) {
                SerreCheck(isOn: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.url.lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        .lineLimit(1).truncationMode(.middle)
                    Text(french ? "Modifié : \(modified(item))" : "Modified: \(modified(item))")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    if let failure {
                        Text(copy(failure)).font(CoreTendTypography.caption).foregroundStyle(Palette.danger.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(size(item.allocatedBytes)).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                    Text(french ? "logique \(size(item.logicalBytes))" : "logical \(size(item.logicalBytes))")
                        .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                }
                .monospacedDigit()
                SerreRiskBadge(riskLevel(item.risk), label: riskLabel(item.risk))
            }
        }
        .buttonStyle(.serre(.row(selected: selected)))
        .overlay {
            if failure != nil { LeafCorner.control.shape.strokeBorder(Palette.danger.color, lineWidth: 1) }
        }
        .disabled(locked)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: CleanupRowFrames.self, value: [item.url: proxy.frame(in: .named(Self.space))])
        })
        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
        .accessibilityLabel(ProductCopy.scanResultAccessibilitySummary(
            name: item.url.lastPathComponent,
            source: descriptor.map { copy($0.titleKey) } ?? item.ruleID.rawValue,
            state: riskLabel(item.risk),
            allocated: size(item.allocatedBytes), logical: size(item.logicalBytes),
            modified: modified(item), french: french
        ))
        .accessibilityValue(failure.map(copy) ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The Trash indicator (leaves fall into it, its count grows) and the review button.
    private var actionBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trash").foregroundStyle(Palette.ink.color)
                Text(copy("cleanup.trash")).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                if movedInAction > 0 {
                    Text(ProductFormat.count(movedInAction, french: french))
                        .font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.onAccent.color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Palette.accent.color, in: LeafCorner.control.shape)
                        .contentTransition(.numericText(value: Double(movedInAction)))
                        .scaleEffect(1)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
            .background(anchorReader("trash"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(movedInAction > 0 ? "\(copy("cleanup.moved")) : \(movedInAction)" : copy("cleanup.trash"))
            if moving {
                Text(copy("cleanup.moving")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            Spacer()
            Button { Task { await prepareAction() } } label: {
                Text(french ? "Examiner \(ProductFormat.items(selectedItems.count, french: true))" : "Review \(ProductFormat.items(selectedItems.count, french: false))")
            }
            .buttonStyle(.serre(.primary))
            .disabled(selectedItems.isEmpty || locked || selectedRoot == nil)
            .accessibilityHint(french ? "Les éléments choisis seront revérifiés avant d’être déplacés vers la Corbeille." : "Chosen items are revalidated before moving to Trash.")
        }
        .motion(.quick, value: movedInAction)
    }

    private func anchorReader(_ name: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: CleanupAnchorFrames.self, value: [name: proxy.frame(in: .named(Self.space))])
        }
    }

    // MARK: - Choosing

    private func choose(_ rule: ScanRule) {
        selectedRule = rule
        selectedRoot = nil
        results = []; selectedItems = []; failures = [:]; movedInAction = 0
        notice = nil; scanFoundNothing = false; rootsPhase = nil
    }

    private func toggle(_ url: URL) {
        guard !locked else { return }
        if selectedItems.contains(url) { selectedItems.remove(url) } else { selectedItems.insert(url) }
    }

    // MARK: - Scanning

    private func startScan(_ rule: CleanupRuleDescriptor, root: URL) {
        task?.cancel()
        let scanID = UUID()
        activeScanID = scanID
        results = []; selectedItems = []; failures = [:]; movedInAction = 0
        scanCompletedFiles = 0; notice = nil; scanFoundNothing = false
        scanning = true; rootsPhase = .reading
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            var rootFailure: String?
            var partialFailures = Set<String>()
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                if activeScanID == scanID { scanning = false; activeScanID = nil }
            }
            do {
                let exclusions = try await LocalStoreAccess.exclusions()
                for try await event in LocalScanEngine().scan(.init(roots: [.init(url: root, ruleID: rule.id)], exclusions: exclusions)) {
                    guard !Task.isCancelled, activeScanID == scanID else { return }
                    switch event {
                    case .result(let result): results.append(result)
                    case .itemFailure(let path, let reason):
                        if path == root.path { rootFailure = reason } else { partialFailures.insert(reason) }
                    case .finished:
                        if let rootFailure {
                            rootsPhase = nil
                            notice = CleanupNotice(kind: .denied, title: ProductCopy.scanRootFailure(reason: rootFailure, french: french),
                                                   recovery: .chooseAgain)
                        } else {
                            rootsPhase = .finished
                            // Largest known allocation first; unknown sizes last, never guessed.
                            results.sort { allocated($0) > allocated($1) }
                            if !partialFailures.isEmpty {
                                notice = CleanupNotice(kind: .partial, title: copy("cleanup.partial"),
                                                       message: ProductCopy.scanPartialFailure(reasons: partialFailures, french: french))
                            }
                            scanFoundNothing = results.isEmpty && partialFailures.isEmpty
                        }
                    case .progress(let completed): scanCompletedFiles = completed
                    }
                }
            } catch is CancellationError {
                if activeScanID == scanID { notice = CleanupNotice(kind: .note, title: copy("scan.cancelled")) }
            } catch {
                if activeScanID == scanID {
                    rootsPhase = nil
                    notice = CleanupNotice(kind: .error, title: copy("scan.failed"), recovery: .retryScan)
                }
            }
        }
    }

    private func cancelScan() {
        task?.cancel()
        activeScanID = nil
        scanning = false
        results = []
        selectedItems = []
        notice = CleanupNotice(kind: .note, title: copy("scan.cancelled"))
        // The roots withdraw, then their parcel goes.
        rootsPhase = .retracted
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            if rootsPhase == .retracted { rootsPhase = nil; scanCompletedFiles = 0 }
        }
    }

    // MARK: - Review and move

    @MainActor private func prepareAction() async {
        guard let root = selectedRoot, let rule = descriptor, !selectedItems.isEmpty, !scanning, !actionBusy, actionReview == nil else { return }
        actionBusy = true
        defer { actionBusy = false; if actionReview == nil { releaseActionScope() } }
        do {
            actionScopeHeld = root.startAccessingSecurityScopedResource()
            actionScopedRoot = root
            let store = try await LocalStoreAccess.open()
            let ruleID = rule.id.rawValue
            let allowed = Set([ruleID])
            let executor = SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: MacOSTrashClient())
            let service = FileActionService(validator: .init(), executor: executor, store: store, allowedRoots: [root], allowedRuleIDs: allowed)
            let selections = selectedItems.sorted { $0.path < $1.path }.map { FileActionSelection(url: $0, ruleID: ruleID) }
            let review = try service.prepareReview(selections)
            guard await service.recordProposal(review) else {
                notice = CleanupNotice(kind: .error, title: french ? "Journal indisponible; action bloquée." : "History unavailable; action blocked.", nearActions: true)
                return
            }
            actionReview = review
            actionService = service
            actionDialogPresented = true
        } catch {
            notice = CleanupNotice(kind: .error, title: french ? "Revue impossible; aucun fichier déplacé." : "Review failed; no files moved.", nearActions: true)
        }
    }

    private func beginExecution() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { await executeAction(review, service) }
    }

    @MainActor private func executeAction(_ review: ActionReview, _ service: FileActionService) async {
        moving = true
        defer { moving = false; actionBusy = false; releaseActionScope() }
        let batch: ConfirmedActionBatch
        do { batch = try service.confirm(review, accepted: true) } catch {
            notice = CleanupNotice(kind: .error, title: french ? "Action refusée; aucun fichier déplacé." : "Action refused; no files moved.", nearActions: true)
            return
        }
        failures = [:]; movedInAction = 0; notice = nil
        // Each item arrives when its outcome is final, so a leaf falls only for a file that moved.
        let (outcomes, continuation) = AsyncStream.makeStream(of: ActionItemResult.self)
        let worker = Task {
            let report = await service.execute(batch) { _ = continuation.yield($0) }
            continuation.finish()
            return report
        }
        var shown = 0
        for await item in outcomes {
            await show(item, paced: shown < 24)
            shown += 1
        }
        let report = await worker.value
        let stayed = report.items.count - report.movedCount
        if stayed > 0 {
            notice = CleanupNotice(kind: .error,
                                   title: french ? "\(report.movedCount) déplacé\(ProductFormat.frenchPlural(report.movedCount)) vers la Corbeille ; \(stayed) resté\(ProductFormat.frenchPlural(stayed)) en place."
                                                 : "\(report.movedCount) moved to Trash; \(stayed) left in place.",
                                   message: french ? "Chaque fichier resté en place dit pourquoi ; aucun n’a été effacé." : "Each file left in place says why; none was erased.",
                                   nearActions: true)
        } else {
            notice = CleanupNotice(kind: .note, title: french ? "\(report.movedCount) déplacé\(ProductFormat.frenchPlural(report.movedCount)) vers la Corbeille." : "\(report.movedCount) moved to Trash.",
                                   message: french ? "Ils restent récupérables depuis la Corbeille de macOS." : "They can be restored from the macOS Trash.",
                                   nearActions: true)
        }
    }

    @MainActor private func show(_ item: ActionItemResult, paced: Bool) async {
        let url = item.targetURL
        guard item.moved else {
            failures[url] = item.failureKey
            selectedItems.remove(url)
            return
        }
        if !reduceMotion, let frame = rowFrames[url], let trash = anchors["trash"] {
            let list = anchors["list"] ?? frame
            let start = CGPoint(x: frame.minX + 30, y: min(max(frame.midY, list.minY + 12), list.maxY - 12))
            let token = FallingToken(from: start, to: CGPoint(x: trash.minX + 18, y: trash.midY))
            falling.append(token)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(FallingLeaf.duration + 0.05))
                falling.removeAll { $0.id == token.id }
            }
        }
        withAnimation(reduceMotion ? nil : MotionCurve.retreat.animation(duration: 0.18)) {
            results.removeAll { $0.url == url }
            selectedItems.remove(url)
        }
        withAnimation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.3).delay(FallingLeaf.duration * 0.8)) {
            movedInAction += 1
        }
        if paced && !reduceMotion { try? await Task.sleep(for: .milliseconds(90)) }
    }

    private func cancelAction() {
        guard let review = actionReview, let service = actionService else { return }
        actionBusy = true
        actionDialogPresented = false
        actionReview = nil; actionService = nil
        Task { @MainActor in
            let saved = await service.recordCancellation(review)
            notice = CleanupNotice(kind: .note, title: saved ? (french ? "Action annulée; annulation journalisée." : "Action cancelled; cancellation recorded.")
                                                            : (french ? "Action annulée; journal indisponible." : "Action cancelled; history unavailable."), nearActions: true)
            releaseActionScope()
            actionBusy = false
        }
    }

    private var reviewMessage: String {
        let names = actionReview?.items.prefix(5).map { $0.url.lastPathComponent }.joined(separator: "\n") ?? ""
        let count = actionReview?.items.count ?? 0
        let extra = max(0, count - 5)
        let suffix = extra > 0 ? (french ? "\n… et \(extra) autres" : "\n… and \(extra) more") : ""
        return french ? "\(ProductFormat.items(count, french: true)) sélectionné\(ProductFormat.frenchPlural(count)) :\n\(names)\(suffix)\nAction journalisée puis revalidée. Aucun effacement définitif." : "\(ProductFormat.items(count, french: false)) selected:\n\(names)\(suffix)\nAction is logged and revalidated. No permanent deletion."
    }

    private func releaseActionScope() {
        if actionScopeHeld, let actionScopedRoot { actionScopedRoot.stopAccessingSecurityScopedResource() }
        actionScopeHeld = false
        actionScopedRoot = nil
    }

    // MARK: - Formatting

    private func riskLevel(_ risk: CandidateRisk) -> RiskLevel {
        switch risk {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
    private func riskLabel(_ risk: CandidateRisk) -> String {
        switch risk {
        case .low: copy("cleanup.risk.low")
        case .medium: copy("cleanup.risk.medium")
        case .high: copy("cleanup.risk.high")
        }
    }
    private func size(_ measurement: ProductMeasurement<Int64>) -> String {
        switch measurement {
        case .known(let bytes): ProductFormat.bytes(bytes, french: french)
        case .unknown: copy("metrics.unknown")
        }
    }
    private func modified(_ result: ScanResult) -> String {
        guard let date = result.modifiedAt else { return copy("metrics.unknown") }
        return date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: french ? "fr_FR" : "en_US")))
    }
    private func allocated(_ result: ScanResult) -> Int64 {
        if case .known(let bytes) = result.allocatedBytes { return bytes }
        return -1
    }
    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
