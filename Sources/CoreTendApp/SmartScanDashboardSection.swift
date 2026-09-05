// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

// MARK: - Module ↔ sidebar mapping

/// Where each Smart Scan module drills in, and how it is labelled / iconed.
/// One place, so the running list, the result cards and the coverage list
/// never disagree.
extension SmartScanModuleID {
    var sidebarModule: ModuleID {
        switch self {
        case .storage: .cleanup
        case .developer: .developer
        case .duplicates: .duplicates
        case .privacy: .privacyLab
        case .applications: .applications
        case .integrity: .protection
        }
    }

    var displayName: String { sidebarModule.label }
    var icon: String { sidebarModule.systemImage }

    /// Stable order for the lists (disk-heavy first, then cheap metadata).
    var sortRank: Int {
        switch self {
        case .storage: 0
        case .developer: 1
        case .duplicates: 2
        case .privacy: 3
        case .applications: 4
        case .integrity: 5
        }
    }

    static var ordered: [SmartScanModuleID] {
        allCases.sorted { $0.sortRank < $1.sortRank }
    }
}

// MARK: - State → display

struct SmartScanStateDisplay {
    let label: String
    let icon: String
    let tint: Color
    let detail: String?

    init(_ state: SmartScanModuleState) {
        switch state {
        case .queued:
            label = L("smartscan.state.queued"); icon = "clock"; tint = .secondary; detail = nil
        case let .scanning(detail):
            label = L("smartscan.state.scanning"); icon = "magnifyingglass"; tint = MCColor.teal
            self.detail = detail.isEmpty ? nil : detail
        case let .completed(result):
            label = L("smartscan.state.completed"); icon = "checkmark.circle.fill"; tint = MCTheme.success
            detail = result.headline
        case let .unavailable(reason):
            label = L("smartscan.state.unavailable"); icon = "minus.circle"; tint = .secondary
            detail = Self.unavailableCopy(reason)
        case .failed:
            label = L("smartscan.state.failed"); icon = "exclamationmark.triangle.fill"; tint = MCTheme.warning
            detail = L("smartscan.failed.detail")
        case .cancelled:
            label = L("smartscan.state.cancelled"); icon = "xmark.circle"; tint = .secondary; detail = nil
        }
    }

    private static func unavailableCopy(_ reason: String) -> String {
        reason == "not-connected"
            ? L("smartscan.unavailable.not_connected")
            : L("smartscan.unavailable.generic")
    }
}

// MARK: - Reusable module row

struct SmartScanModuleRow: View {
    let module: SmartScanModuleID
    let state: SmartScanModuleState
    /// Non-nil once there is something to open (a completed / failed /
    /// unavailable module still has its own screen).
    var onOpen: (() -> Void)?

    var body: some View {
        let display = SmartScanStateDisplay(state)
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            Image(systemName: module.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MCSpacing.xs) {
                    Text(module.displayName).font(MCFont.cardTitle)
                    Spacer(minLength: MCSpacing.xs)
                    Label {
                        Text(display.label).font(MCFont.badge)
                    } icon: {
                        Image(systemName: display.icon).font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(display.tint)
                    .labelStyle(.titleAndIcon)
                }
                if let detail = display.detail {
                    Text(detail)
                        .font(MCFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if onOpen != nil {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, MCSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.displayName), \(display.label)"
                            + (display.detail.map { ", \($0)" } ?? ""))
        .accessibilityAddTraits(onOpen != nil ? .isButton : [])
    }
}

// MARK: - Elapsed formatting

func smartScanElapsedText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - The section

struct SmartScanDashboardSection: View {
    let smartScan: SmartScanModel
    let navigate: (ModuleID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: MCSpacing.md) {
            switch smartScan.phase {
            case .idle:      idleHero
            case .running:   runningView
            case .completed: resultView
            case .cancelled: cancelledView
            }
        }
        .padding(MCSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [MCColor.teal.opacity(0.12), MCColor.teal.opacity(0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: MCRadius.card))
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: MCRadius.card)
                .strokeBorder(MCColor.teal.opacity(0.45), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.smartscan")
    }

    // MARK: Idle

    private var idleHero: some View {
        HStack(alignment: .top, spacing: MCSpacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MCColor.teal)
                .frame(width: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MCSpacing.sm) {
                Text(L("smartscan.title")).font(MCFont.pageTitle)
                Text(L("smartscan.idle.tagline"))
                    .font(MCFont.secondaryBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("smartscan.idle.coverage_title"))
                        .font(MCFont.badge).textCase(.uppercase).kerning(0.4)
                        .foregroundStyle(.secondary)
                    ForEach(SmartScanModuleID.ordered, id: \.self) { module in
                        HStack(spacing: MCSpacing.xs) {
                            Image(systemName: module.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(module.displayName).font(MCFont.caption)
                        }
                    }
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L("smartscan.idle.coverage_title") + ": "
                    + SmartScanModuleID.ordered.map(\.displayName).joined(separator: ", "))

                Button {
                    smartScan.start()
                } label: {
                    Label {
                        Text(L("smartscan.start"))
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .padding(.vertical, MCSpacing.sm)
                    .padding(.horizontal, MCSpacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, MCSpacing.xs)
                .accessibilityIdentifier("dashboard.smartscan.start")
                .accessibilityLabel(L("smartscan.start"))
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: Running

    private var runningView: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            HStack(spacing: MCSpacing.sm) {
                ProgressView().controlSize(.small)
                Text(L("smartscan.running.title")).font(MCFont.pageTitle)
                Spacer()
                Text(L("smartscan.elapsed", smartScanElapsedText(smartScan.elapsed)))
                    .font(MCFont.badge).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L("smartscan.elapsed", smartScanElapsedText(smartScan.elapsed)))
            }
            moduleList(openable: false)
            Button(role: .cancel) {
                smartScan.cancel()
            } label: {
                Text(L("smartscan.cancel"))
            }
            .accessibilityIdentifier("dashboard.smartscan.cancel")
            .padding(.top, MCSpacing.xs)
        }
    }

    // MARK: Result

    private var resultView: some View {
        let report = smartScan.report ?? SmartScanReport()
        return VStack(alignment: .leading, spacing: MCSpacing.md) {
            HStack {
                Text(L("smartscan.result.title")).font(MCFont.pageTitle)
                Spacer()
                Text(L("smartscan.elapsed", smartScanElapsedText(smartScan.elapsed)))
                    .font(MCFont.badge).foregroundStyle(.secondary).monospacedDigit()
            }

            if report.modules.values.contains(where: { if case .failed = $0 { return true } else { return false } }) {
                Label(L("smartscan.result.partial"), systemImage: "exclamationmark.triangle")
                    .font(MCFont.caption).foregroundStyle(MCTheme.warning)
            }

            categorySummary(report)

            moduleList(openable: true)

            HStack(spacing: MCSpacing.sm) {
                Button {
                    navigate(.recoveryPlan)
                } label: {
                    Label(L("smartscan.review_recovery_plan"), systemImage: "target")
                        .font(.body.weight(.semibold))
                        .padding(.vertical, MCSpacing.xs)
                        .padding(.horizontal, MCSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("dashboard.smartscan.recoveryPlan")

                Button(L("smartscan.new_scan")) { smartScan.reset() }
                    .accessibilityIdentifier("dashboard.smartscan.newScan")
            }
            .padding(.top, MCSpacing.xs)
        }
    }

    /// The four dimensions — never merged into one synthetic metric.
    private func categorySummary(_ report: SmartScanReport) -> some View {
        VStack(alignment: .leading, spacing: MCSpacing.xs) {
            if report.isGlobalRecoverableExact {
                metricRow(L("smartscan.category.recoverable"),
                          value: mcFormatBytes(report.globalRecoverableBytes),
                          icon: "arrow.down.circle", tint: MCTheme.success)
            } else {
                metricRow(L("smartscan.category.recoverable"),
                          value: perCategoryRecoverableText(report),
                          icon: "arrow.down.circle", tint: MCTheme.success)
                Text(L("smartscan.recoverable.inexact_note"))
                    .font(MCFont.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            metricRow(L("smartscan.category.review"),
                      value: mcFormatBytes(report.needsReviewBytes),
                      icon: "questionmark.circle", tint: MCColor.teal)
            metricRow(L("smartscan.category.attention"),
                      value: L("smartscan.count_items", report.attentionCount),
                      icon: "exclamationmark.triangle", tint: MCTheme.warning)
            metricRow(L("smartscan.category.informational"),
                      value: L("smartscan.count_items", report.informationalCount),
                      icon: "info.circle", tint: .secondary)
        }
        .padding(MCSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.small))
        .overlay(RoundedRectangle(cornerRadius: MCRadius.small)
            .strokeBorder(MCColor.separator.opacity(0.8), lineWidth: 1))
    }

    private func perCategoryRecoverableText(_ report: SmartScanReport) -> String {
        let parts: [String] = SmartScanModuleID.ordered.compactMap { module in
            guard case let .completed(result) = report.modules[module],
                  result.totals.potentiallyRecoverableBytes > 0 else { return nil }
            return "\(module.displayName) \(mcFormatBytes(result.totals.potentiallyRecoverableBytes))"
        }
        return parts.isEmpty ? mcFormatBytes(0) : parts.joined(separator: " · ")
    }

    private func metricRow(_ title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 18)
            Text(title).font(MCFont.secondaryBody)
            Spacer()
            Text(value).font(MCFont.secondaryBody.weight(.semibold)).monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: Cancelled

    private var cancelledView: some View {
        VStack(alignment: .leading, spacing: MCSpacing.sm) {
            Label(L("smartscan.cancelled.title"), systemImage: "xmark.circle")
                .font(MCFont.pageTitle)
            Text(L("smartscan.cancelled.detail"))
                .font(MCFont.secondaryBody).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !smartScan.modules.isEmpty {
                moduleList(openable: false)
            }
            Button(L("smartscan.start_again")) { smartScan.reset(); smartScan.start() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("dashboard.smartscan.startAgain")
                .padding(.top, MCSpacing.xs)
        }
    }

    // MARK: Shared module list

    private func moduleList(openable: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(SmartScanModuleID.ordered.enumerated()), id: \.element) { index, module in
                let state = smartScan.modules[module] ?? .queued
                SmartScanModuleRow(
                    module: module,
                    state: state,
                    onOpen: openable && Self.isOpenable(state) ? { navigate(module.sidebarModule) } : nil)
                if index < SmartScanModuleID.ordered.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .accessibilityIdentifier("dashboard.smartscan.modules")
    }

    private static func isOpenable(_ state: SmartScanModuleState) -> Bool {
        switch state {
        case .completed, .failed: return true
        case .unavailable, .queued, .scanning, .cancelled: return false
        }
    }
}
