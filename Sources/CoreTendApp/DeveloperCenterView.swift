// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem
import ScanCore
import FileRules
import SystemMetrics

struct DeveloperCenterView: View {
    @Bindable var model: DeveloperCenterModel
    @State private var showConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MCSpacing.lg) {
                header
                if model.phase == .scanning {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(L("developer.scanning"))
                        Spacer()
                        Button(L("common.cancel")) { model.cancel() }
                            .keyboardShortcut(.cancelAction)
                    }
                } else if let result = model.executionResult {
                    MCCard {
                        VStack(alignment: .leading, spacing: MCSpacing.sm) {
                            Text(L("developer.result", result.executed.count, mcFormatBytes(result.processedBytes), result.skippedCount))
                            Text(L("developer.result.note")).foregroundStyle(.secondary)
                            Button(L("developer.refresh")) { Task { await model.refresh() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else if let snapshot = model.snapshot {
                    overview(snapshot)
                    MCSectionHeader("Xcode", subtitle: L("developer.xcode.scope"))
                    if snapshot.xcode == .absent { Text(L("developer.xcode.not_found")).font(MCFont.caption).foregroundStyle(.secondary) }
                    ruleRows(snapshot, rules: DeveloperStorage.xcodeRules)
                    MCSectionHeader(L("developer.packages"), subtitle: L("developer.packages.scope"))
                    ruleRows(snapshot, rules: PackageCacheRules.all)
                    simulator(snapshot.simulators)
                    docker(snapshot.docker)
                } else {
                    MCEmptyState(icon: "hammer", title: L("developer.title"), message: L("developer.intro"),
                                 actionTitle: L("developer.refresh")) { Task { await model.refresh() } }
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(L("module.developer"))
        .accessibilityIdentifier("developer.root")
        .task { await model.loadIfNeeded() }
        .onDisappear { model.cancel() }
        .confirmationDialog(L("common.trash_confirm.title"), isPresented: $showConfirmation, titleVisibility: .visible) {
            Button(L("common.trash_confirm.action"), role: .destructive) { Task { await model.executeSelection() } }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("developer.confirm", model.selectedFindings.count, mcFormatBytes(model.selectedBytes)))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: MCSpacing.md) {
            VStack(alignment: .leading, spacing: MCSpacing.xs) {
                Text(L("developer.title")).font(MCFont.pageTitle).accessibilityAddTraits(.isHeader)
                Text(L("developer.intro")).font(MCFont.secondaryBody).foregroundStyle(.secondary)
            }
            Spacer(minLength: MCSpacing.sm)
            Button { Task { await model.refresh() } } label: {
                Label(L("developer.refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(model.phase == .scanning || model.phase == .running)
            .keyboardShortcut("r", modifiers: [.command])
            .accessibilityIdentifier("developer.refresh")
        }
    }

    private func overview(_ snapshot: DeveloperScanSnapshot) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                        Text(mcFormatBytes(snapshot.potentiallyRecoverableBytes)).font(MCFont.displayMetric).monospacedDigit()
                        Text(L("developer.recoverable")).font(MCFont.cardTitle)
                    }
                    Spacer()
                    Button(L("cleanup.move_to_trash")) { showConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.selectedIDs.isEmpty || model.phase != .ready)
                        .accessibilityIdentifier("developer.trash")
                }
                Text(L("developer.selected", model.selectedFindings.count, mcFormatBytes(model.selectedBytes)))
                    .font(MCFont.secondaryBody)
                HStack {
                    Text("Xcode")
                    Spacer()
                    Text(mcFormatBytes(snapshot.groups.filter { $0.ruleID.hasPrefix("dev.xcode.") }.reduce(0) { $0 + $1.logicalBytes }))
                        .monospacedDigit()
                }
                HStack {
                    Text(L("developer.packages"))
                    Spacer()
                    Text(mcFormatBytes(snapshot.groups.filter { $0.ruleID.hasPrefix("dev.cache.") }.reduce(0) { $0 + $1.logicalBytes }))
                        .monospacedDigit()
                }
                Text(L("developer.logical_note")).font(MCFont.caption).foregroundStyle(.secondary)
                Text(L("developer.measured_at", snapshot.date.formatted(date: .abbreviated, time: .shortened)))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                if snapshot.omittedCount > 0 {
                    Label(L("developer.limited", DeveloperCenterService.findingLimit, snapshot.omittedCount), systemImage: "exclamationmark.triangle")
                }
                if !snapshot.failedRuleIDs.isEmpty {
                    Label(L("developer.failed_rules"), systemImage: "exclamationmark.triangle")
                }
                if model.phase == .running { ProgressView(L("developer.running")) }
            }
        }
    }

    @ViewBuilder
    private func ruleRows(_ snapshot: DeveloperScanSnapshot, rules: [ScanRule]) -> some View {
        ForEach(rules, id: \.id) { rule in
            if let group = snapshot.groups.first(where: { $0.ruleID == rule.id }) {
                DeveloperRuleRow(model: model, group: group, rule: rule,
                    failed: snapshot.failedRuleIDs.contains(rule.id), excluded: snapshot.excludedRuleIDs.contains(rule.id),
                    rootStates: snapshot.rootStates)
            }
        }
    }

    private func simulator(_ measurement: StorageMeasurement) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                MCSectionHeader(L("developer.simulators"))
                MCStatusBadge(L("developer.inspection_only"), status: .neutral)
                measurementRow(measurement)
                Text(L("developer.simulator.reason")).font(MCFont.secondaryBody)
                Text(L("developer.simulator.unavailable")).font(MCFont.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("developer.simulators.readonly")
    }

    private func docker(_ inspection: DeveloperStorageInspector.DockerInspection) -> some View {
        MCCard {
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                MCSectionHeader("Docker")
                MCStatusBadge(L("developer.inspection_only"), status: .neutral)
                Text(L(inspection.desktop == .available ? "developer.docker.detected" : "developer.docker.not_detected"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                if inspection.availability != .available {
                    Text(DeveloperDisplay.label(inspection.availability))
                }
                ForEach(inspection.disks.filter { $0.availability != .absent }, id: \.path) { measurement in
                    measurementRow(measurement)
                }
                Text(L("developer.docker.reason")).font(MCFont.secondaryBody)
                Text(L("developer.docker.unavailable")).font(MCFont.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("developer.docker.readonly")
    }

    private func measurementRow(_ measurement: StorageMeasurement) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
            if let logical = measurement.logicalBytes {
                Text(L("developer.used.logical", mcFormatBytes(logical))).monospacedDigit()
                Text(L("developer.used.physical", measurement.allocatedBytes.map(mcFormatBytes) ?? L("developer.metric_unknown")))
                    .monospacedDigit().foregroundStyle(.secondary)
            } else {
                Text(DeveloperDisplay.label(measurement.availability))
            }
            Text(measurement.path.path).font(MCFont.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

enum DeveloperDisplay {
    static func label(_ availability: StorageAvailability) -> String {
        L("developer.state.\(availability.rawValue)")
    }
}

private struct DeveloperRuleRow: View {
    @Bindable var model: DeveloperCenterModel
    let group: DeveloperStorage.Group
    let rule: ScanRule
    let failed: Bool
    let excluded: Bool
    let rootStates: [String: StorageAvailability]
    @State private var visibleCount = 100

    var body: some View {
        MCCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: MCSpacing.sm) {
                    AdvisorSummaryRow(finding: group.advisor)
                    Text(group.advisor.reason).font(MCFont.secondaryBody)
                    Text(group.advisor.consequence).font(MCFont.secondaryBody)
                    ForEach(rule.roots(model.home), id: \.path) { root in
                        VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                            Text(root.path).textSelection(.enabled)
                            Text(DeveloperDisplay.label(rootStates[root.path] ?? .unavailable)).foregroundStyle(.secondary)
                        }
                        .font(MCFont.caption)
                        .accessibilityElement(children: .combine)
                    }
                    if excluded { Text(L("developer.excluded")).font(MCFont.caption) }
                    if !group.findings.isEmpty {
                        Toggle(L("developer.select_group", group.advisor.title), isOn: Binding(
                            get: { group.findings.allSatisfy { model.selectedIDs.contains($0.id) } },
                            set: { model.setSelection($0, group: group) }))
                            .toggleStyle(.checkbox)
                            .disabled(model.phase != .ready)
                            .accessibilityValue(L("developer.selection_count", group.findings.filter { model.selectedIDs.contains($0.id) }.count,
                                                  group.findings.count))
                        if rule.id == UserCleanupRules.xcodeDerivedData.id, let root = rule.roots(model.home).first {
                            DisclosureGroup(L("developer.folder_breakdown")) {
                                ForEach(group.breakdown(under: root)) { folder in
                                    HStack { Text(folder.name); Spacer(); Text(mcFormatBytes(folder.logicalBytes)).monospacedDigit() }
                                }
                            }
                        }
                        DisclosureGroup(L("developer.review_files", group.findings.count)) {
                            LazyVStack(alignment: .leading, spacing: MCSpacing.xs) {
                                ForEach(group.findings.prefix(visibleCount)) { finding in
                                    fileRow(finding)
                                }
                                if visibleCount < group.findings.count {
                                    Button(L("developer.show_more")) { visibleCount += 100 }
                                }
                            }
                        }
                    }
                }
                .padding(.top, MCSpacing.sm)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: MCSpacing.sm) {
                    VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                        Text(group.advisor.title).font(MCFont.cardTitle)
                        Text(L(rule.risk == .low ? "developer.regenerable" : "developer.review_required"))
                            .font(MCFont.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(failed ? L("developer.state.unavailable") : group.findings.isEmpty
                         ? L(excluded ? "developer.excluded" : "developer.no_candidates") : mcFormatBytes(group.logicalBytes))
                        .font(MCFont.secondaryBody).monospacedDigit()
                    MCStatusBadge(AdvisorDisplay.label(rule.risk), status: AdvisorDisplay.status(rule.risk))
                }
            }
        }
        .accessibilityIdentifier("developer.rule.\(rule.id)")
    }

    private func fileRow(_ finding: ScanFinding) -> some View {
        HStack {
            Toggle(finding.url.lastPathComponent, isOn: Binding(
                get: { model.selectedIDs.contains(finding.id) },
                set: { on in
                    if on { model.selectedIDs.insert(finding.id) } else { model.selectedIDs.remove(finding.id) }
                }))
                .toggleStyle(.checkbox)
                .disabled(model.phase != .ready)
                .accessibilityLabel(L("cleanup.select_item", finding.url.path))
                .help(finding.url.path)
            Spacer()
            Text(mcFormatBytes(finding.logicalSize)).monospacedDigit()
        }
        .font(MCFont.caption)
    }
}
