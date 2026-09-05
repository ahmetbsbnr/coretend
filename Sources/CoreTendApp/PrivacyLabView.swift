// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import UniformTypeIdentifiers
import DesignSystem
import SystemMetrics

// MARK: - View model

/// Owns one image inspection at a time. Every selection gets a fresh
/// `generation` token; a result whose token no longer matches the current
/// one is dropped, so a slow inspection of an earlier pick can never
/// overwrite a newer one. `clear()` also rotates the token, orphaning any
/// inspection still in flight. Nothing here is persisted.
@MainActor
@Observable
final class PrivacyLabViewModel {
    enum Phase: Equatable { case empty, inspecting, result }

    private(set) var phase: Phase = .empty
    private(set) var inspection: ImageMetadataInspection?
    /// The chosen file's name, for the in-content header only — never shown
    /// in the sidebar or any history surface, never persisted.
    private(set) var displayName: String?
    /// Opt-in: exact coordinates stay hidden until the user asks for them.
    var revealsPreciseLocation = false

    private let inspector: ImageMetadataInspecting
    private var generation = UUID()
    private var task: Task<Void, Never>?

    init(inspector: @escaping ImageMetadataInspecting = PrivacyLabService.live) {
        self.inspector = inspector
    }

    /// Honest, count-based summary of the current inspection — never a score.
    var summary: PrivacyLabSummary? {
        inspection.map(PrivacyLabSummary.init)
    }

    func inspect(url: URL) {
        let token = UUID()
        generation = token
        task?.cancel()
        phase = .inspecting
        inspection = nil
        revealsPreciseLocation = false
        displayName = url.lastPathComponent
        let inspector = inspector
        task = Task { [weak self] in
            let result = await inspector(url)
            guard let self, self.generation == token else { return }
            self.inspection = result
            self.phase = .result
        }
    }

    func clear() {
        generation = UUID()
        task?.cancel()
        task = nil
        phase = .empty
        inspection = nil
        displayName = nil
        revealsPreciseLocation = false
    }
}

// MARK: - View

struct PrivacyLabView: View {
    @State private var model = PrivacyLabViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.lg) {
                header
                localNotice
                switch model.phase {
                case .empty:
                    emptyState
                case .inspecting:
                    inspectingState
                case .result:
                    if let inspection = model.inspection {
                        resultContent(inspection)
                    }
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(L("module.privacy_lab"))
        .accessibilityIdentifier("privacylab.root")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    chooseImage()
                } label: {
                    Label(L("privacylab.choose_image"), systemImage: "photo")
                }
                .help(L("privacylab.choose_image"))
                .accessibilityIdentifier("privacylab.choose")
                if model.phase != .empty {
                    Button {
                        model.clear()
                    } label: {
                        Label(L("privacylab.clear"), systemImage: "xmark.circle")
                    }
                    .help(L("privacylab.clear"))
                    .accessibilityIdentifier("privacylab.clear")
                }
            }
        }
    }

    // MARK: Header / notices

    private var header: some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            Text(L("privacylab.title")).font(MCFont.pageTitle).accessibilityAddTraits(.isHeader)
            Text(L("privacylab.intro")).font(MCFont.secondaryBody).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var localNotice: some View {
        Label(L("privacylab.local_note"), systemImage: "lock.laptopcomputer")
            .font(MCFont.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("privacylab.local_note")
    }

    // MARK: Empty / inspecting

    private var emptyState: some View {
        MCEmptyState(icon: "photo.on.rectangle.angled",
                     title: L("privacylab.empty.title"),
                     message: L("privacylab.empty.message"),
                     actionTitle: L("privacylab.choose_image")) { chooseImage() }
            .accessibilityIdentifier("privacylab.empty")
    }

    private var inspectingState: some View {
        MCCard {
            HStack(spacing: MCSpacing.sm) {
                ProgressView().controlSize(.small)
                Text(model.displayName.map { L("privacylab.inspecting_named", $0) } ?? L("privacylab.inspecting"))
                Spacer()
                Button(L("common.cancel")) { model.clear() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .accessibilityIdentifier("privacylab.inspecting")
    }

    // MARK: Result

    @ViewBuilder
    private func resultContent(_ inspection: ImageMetadataInspection) -> some View {
        if let name = model.displayName {
            Text(L("privacylab.inspected_named", name))
                .font(MCFont.cardTitle)
                .textSelection(.enabled)
                .accessibilityIdentifier("privacylab.result.name")
        }

        summaryCard(inspection)

        switch inspection.status {
        case .inspected:
            categoriesSection(inspection)
            structuralSection(inspection)
        case let .unsupported(detail):
            statusNotice(icon: "doc.questionmark",
                         title: L("privacylab.status.unsupported"),
                         detail: L("privacylab.status.unsupported.detail", detail))
        case let .unreadable(reason):
            statusNotice(icon: "exclamationmark.triangle",
                         title: L("privacylab.status.unreadable"),
                         detail: L("privacylab.status.unreadable.detail", reason))
        case .fileMissing:
            statusNotice(icon: "questionmark.folder",
                         title: L("privacylab.status.file_missing"),
                         detail: L("privacylab.status.file_missing.detail"))
        }

        Button(L("privacylab.choose_different")) { chooseImage() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("privacylab.choose_different")
    }

    private func summaryCard(_ inspection: ImageMetadataInspection) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                MCSectionHeader(L("privacylab.summary.header"))
                switch PrivacyLabSummary(inspection) {
                case let .cannotInspect(headlineKey):
                    summaryLine(icon: "exclamationmark.triangle.fill", tint: MCTheme.warning,
                                text: L(headlineKey))
                case let .metadataPresent(count, incompleteCount):
                    summaryLine(icon: "exclamationmark.circle.fill", tint: MCTheme.warning,
                                text: L("privacylab.summary.present", count))
                    if incompleteCount > 0 {
                        summaryLine(icon: "questionmark.circle", tint: .secondary,
                                    text: L("privacylab.summary.incomplete", incompleteCount))
                    }
                case let .noSupportedMetadataDetected(incompleteCount):
                    summaryLine(icon: "minus.circle", tint: .secondary,
                                text: L("privacylab.summary.none_detected"))
                    if incompleteCount > 0 {
                        summaryLine(icon: "questionmark.circle", tint: .secondary,
                                    text: L("privacylab.summary.incomplete", incompleteCount))
                    }
                }
                if let format = inspection.formatIdentifier {
                    Text(L("privacylab.format", format))
                        .font(MCFont.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                }
                Text(L("privacylab.summary.not_a_score"))
                    .font(MCFont.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("privacylab.summary")
    }

    private func summaryLine(icon: String, tint: Color, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
        .font(MCFont.secondaryBody)
        .accessibilityElement(children: .combine)
    }

    // MARK: Categories

    private func categoriesSection(_ inspection: ImageMetadataInspection) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            MCSectionHeader(L("privacylab.section.categories"), subtitle: L("privacylab.section.categories.subtitle"))
            ForEach(inspection.findings, id: \.category.rawValue) { finding in
                categoryRow(finding, precise: inspection.preciseLocation)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ finding: MetadataFinding, precise: PreciseLocation?) -> some View {
        MCCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: MCSpacing.xs) {
                    Text(PrivacyLabCatalog.explanation(for: finding.category))
                        .font(MCFont.secondaryBody).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if case .present = finding.field.presence,
                       let value = finding.field.displayValue,
                       finding.category != .location {
                        valueRow(value)
                    }

                    if finding.category == .location {
                        locationDisclosure(present: isPresent(finding.field), precise: precise)
                    }

                    if case let .unavailable(reason) = finding.field.presence {
                        Text(L("privacylab.state.unavailable.reason", reason))
                            .font(MCFont.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, MCSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                    Text(PrivacyLabCatalog.title(for: finding.category)).font(MCFont.cardTitle)
                    Spacer(minLength: MCSpacing.sm)
                    stateBadge(finding.field.presence)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("privacylab.category.\(finding.category.rawValue)")
    }

    private func valueRow(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("privacylab.embedded_value")).font(MCFont.caption).foregroundStyle(.tertiary)
            Text(value).font(MCFont.secondaryBody).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func locationDisclosure(present: Bool, precise: PreciseLocation?) -> some View {
        if present {
            Text(L("privacylab.location.no_geocode"))
                .font(MCFont.caption).foregroundStyle(.tertiary)
            if let precise {
                Toggle(L("privacylab.location.reveal"), isOn: $model.revealsPreciseLocation)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("privacylab.location.reveal")
                if model.revealsPreciseLocation {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("privacylab.location.precise_label")).font(MCFont.caption).foregroundStyle(.tertiary)
                        Text(precise.decimalDegrees).font(MCFont.secondaryBody).monospacedDigit().textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(L("privacylab.location.no_coordinate"))
                    .font(MCFont.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Structural

    @ViewBuilder
    private func structuralSection(_ inspection: ImageMetadataInspection) -> some View {
        if !inspection.presentMetadataBlocks.isEmpty {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                MCSectionHeader(L("privacylab.section.blocks"))
                Text(inspection.presentMetadataBlocks.joined(separator: " · "))
                    .font(MCFont.secondaryBody)
                Text(L("privacylab.section.blocks.note"))
                    .font(MCFont.caption).foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("privacylab.blocks")
        }
    }

    private func statusNotice(icon: String, title: String, detail: String) -> some View {
        MCCard {
            HStack(alignment: .top, spacing: MCSpacing.sm) {
                Image(systemName: icon).foregroundStyle(MCTheme.warning).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(MCFont.cardTitle)
                    Text(detail).font(MCFont.secondaryBody).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("privacylab.status_notice")
    }

    // MARK: State rendering (never color alone)

    private func stateBadge(_ presence: MetadataPresence) -> some View {
        switch presence {
        case .present:
            return MCStatusBadge(L("privacylab.state.present"), status: .attention)
        case .notDetected:
            return MCStatusBadge(L("privacylab.state.not_detected"), status: .neutral)
        case .unavailable:
            return MCStatusBadge(L("privacylab.state.unavailable"), status: .neutral)
        }
    }

    private func isPresent(_ field: MetadataField) -> Bool {
        if case .present = field.presence { return true }
        return false
    }

    // MARK: File selection

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = L("privacylab.choose_image")
        if panel.runModal() == .OK, let url = panel.url {
            model.inspect(url: url)
        }
    }
}
