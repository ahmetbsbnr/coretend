import SwiftUI
import AppShell
import DesignSystem
import Domain
import SafetyCore

/// Apps already dragged to the Trash whose files are still in the Library. Their leftovers go to
/// the Trash after the same review and confirmation as everything else; nothing is erased.
struct TrashedAppsSection: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var apps: [TrashedApp] = []
    @State private var loaded = false
    @State private var busy = false
    @State private var pending: (app: TrashedApp, review: ActionReview, service: FileActionService)?
    @State private var confirming = false
    @State private var notice: PageNotice?

    var body: some View {
        Group {
            if !apps.isEmpty || notice != nil {
                SerreParcel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy("apps.trashed.title")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                        Text(copy("apps.trashed.help")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                        if let notice { SerreBanner(notice.kind == .error ? .partial : .note, title: notice.title, message: notice.message) }
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in row(app).serreRise(min(index + 1, 8)) }
                    }
                }
            }
        }
        .task { if !loaded { await load() } }
        .confirmationDialog(copy("clean.confirm.title"), isPresented: $confirming, titleVisibility: .visible) {
            Button(copy("clean.confirm.action"), role: .destructive) { execute() }
            Button(copy("common.cancel"), role: .cancel) { cancel() }.keyboardShortcut(.defaultAction)
        } message: {
            if let pending {
                Text(String(format: copy("apps.trashed.confirm"),
                            ProductFormat.items(pending.app.leftovers.count, french: french), pending.app.name))
            }
        }
    }

    private func row(_ app: TrashedApp) -> some View {
        HStack(spacing: 12) {
            SerreIcon(.applications, size: 18).foregroundStyle(Palette.secondaryInk.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                Text("\(ProductFormat.items(app.leftovers.count, french: french)) · \(ProductFormat.bytes(app.bytes, french: french))")
                    .font(CoreTendTypography.caption.monospacedDigit()).foregroundStyle(Palette.secondaryInk.color)
            }
            Spacer(minLength: 8)
            Button(copy("apps.trashed.action")) { Task { await review(app) } }
                .buttonStyle(.serre(.secondary)).disabled(busy)
        }
    }

    @MainActor private func load() async {
        let home = HomeFolder.url
        apps = await Task.detached(priority: .utility) {
            TrashedAppFinder(home: home, isInstalledElsewhere: CareAlertMonitor.isInstalledElsewhere).find()
        }.value
        loaded = true
    }

    @MainActor private func review(_ app: TrashedApp) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let store = try await LocalStoreAccess.open()
            let rule = "apps.leftovers", allowed: Set<String> = [rule]
            let roots = [AppLeftoverFinder(home: HomeFolder.url).root]
            let executor = SafeActionExecutor(allowedRoots: roots, allowedRules: allowed, trash: AppTrashClient.make())
            let service = FileActionService(validator: .init(), executor: executor, store: store, allowedRoots: roots, allowedRuleIDs: allowed)
            let review = try service.prepareReview(app.leftovers.map { FileActionSelection(url: $0.url, ruleID: rule) })
            guard await service.recordProposal(review) else {
                notice = PageNotice(kind: .error, title: copy("clean.reviewFailed")); return
            }
            pending = (app, review, service)
            confirming = true
        } catch {
            notice = PageNotice(kind: .error, title: copy("clean.reviewFailed"))
        }
    }

    private func execute() {
        guard let pending else { return }
        self.pending = nil
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard let batch = try? pending.service.confirm(pending.review, accepted: true) else {
                notice = PageNotice(kind: .error, title: copy("clean.reviewFailed")); return
            }
            let result = await executeShowingEachItem(pending.service, batch, reduceMotion: reduceMotion) { _ in }
            notice = result.movedCount == result.items.count
                ? PageNotice(kind: .note, title: ProductCopy.inline("%1$@ dans la Corbeille.", "%1$@ in the Trash.", french: french, "\(ProductFormat.items(result.movedCount, french: french))"))
                : .moveOutcome(result, french: french)
            await load()
            CompletionSound.play()
        }
    }

    private func cancel() {
        guard let pending else { return }
        self.pending = nil
        Task { _ = await pending.service.recordCancellation(pending.review) }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
