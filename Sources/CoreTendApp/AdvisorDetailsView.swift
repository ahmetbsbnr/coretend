// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import SafetyCore
import DesignSystem

/// Localized display text for the three Advisor axes. Kept together so every
/// call site (badges, full details, any future summary) reads the same
/// words for the same value — never re-derived ad hoc in a View.
enum AdvisorDisplay {
    static func label(_ risk: RiskLevel) -> String {
        switch risk {
        case .low: L("advisor.risk.low")
        case .medium: L("advisor.risk.medium")
        case .high: L("advisor.risk.high")
        }
    }

    static func label(_ confidence: AdvisorConfidence) -> String {
        switch confidence {
        case .exact: L("advisor.confidence.exact")
        case .high: L("advisor.confidence.high")
        case .probable: L("advisor.confidence.probable")
        case .uncertain: L("advisor.confidence.uncertain")
        }
    }

    static func label(_ reversibility: AdvisorReversibility) -> String {
        switch reversibility {
        case .readOnly: L("advisor.reversibility.readOnly")
        case .trash: L("advisor.reversibility.trash")
        case .restorableByCoreTend: L("advisor.reversibility.restorableByCoreTend")
        case .partial: L("advisor.reversibility.partial")
        case .irreversible: L("advisor.reversibility.irreversible")
        }
    }

    /// `MCStatusBadge` already pairs color with an icon and text, so this
    /// status choice is never the only signal — it just picks which of the
    /// three existing tones a given value reads as.
    static func status(_ risk: RiskLevel) -> MCStatus {
        switch risk {
        case .low: .success
        case .medium: .attention
        case .high: .error
        }
    }

    static func status(_ confidence: AdvisorConfidence) -> MCStatus {
        switch confidence {
        case .exact, .high: .success
        case .probable: .attention
        case .uncertain: .error
        }
    }
}

/// The "disclosure" level of detail: Risk / Confidence / Reversible as three
/// compact badges, one line. Every badge carries text, never color alone.
struct AdvisorBadgeRow: View {
    let finding: AdvisorFinding

    var body: some View {
        HStack(spacing: MCSpacing.xs) {
            MCStatusBadge(AdvisorDisplay.label(finding.risk), status: AdvisorDisplay.status(finding.risk))
            MCStatusBadge(AdvisorDisplay.label(finding.confidence), status: AdvisorDisplay.status(finding.confidence))
            MCStatusBadge(AdvisorDisplay.label(finding.reversibility), status: .neutral)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(L("advisor.risk_label")): \(AdvisorDisplay.label(finding.risk)). "
            + "\(L("advisor.confidence_label")): \(AdvisorDisplay.label(finding.confidence)). "
            + "\(L("advisor.reversible")): \(AdvisorDisplay.label(finding.reversibility)).")
    }
}

/// The full inspector: everything an `AdvisorFinding` carries, laid out for a
/// popover or sheet — not a giant always-visible card.
struct AdvisorDetailsView: View {
    let finding: AdvisorFinding

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MCSpacing.md) {
                Text(finding.title).font(MCFont.pageTitle)
                AdvisorBadgeRow(finding: finding)
                labeledSection(L("advisor.why_flagged"), finding.reason)
                labeledSection(L("advisor.what_happens"), finding.consequence)
                if let bytes = finding.reclaimableBytes {
                    labeledSection(L("advisor.recoverable"), mcFormatBytes(bytes))
                }
                if !finding.notRemoved.isEmpty {
                    labeledSection(L("advisor.not_removed_label"), finding.notRemoved.joined(separator: ", "))
                }
                if let recommendation = finding.recommendation {
                    labeledSection(L("advisor.recommendation_label"), recommendation)
                }
            }
            .padding(MCSpacing.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("advisor.details")
    }

    private func labeledSection(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(MCFont.badge).foregroundStyle(.secondary).textCase(.uppercase).kerning(0.4)
            Text(value).font(MCFont.secondaryBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The compact + disclosure levels together, meant to sit inline in an
/// existing list row: a one-line summary, the badge row, and an info button
/// that opens `AdvisorDetailsView` in a popover for the full inspector level
/// — never all three levels shown at once as one giant card.
struct AdvisorSummaryRow: View {
    let finding: AdvisorFinding
    @State private var showingDetails = false

    var body: some View {
        HStack(alignment: .top, spacing: MCSpacing.sm) {
            VStack(alignment: .leading, spacing: MCSpacing.xxs) {
                Text(finding.summary).font(.caption).foregroundStyle(.secondary)
                AdvisorBadgeRow(finding: finding)
            }
            Spacer(minLength: 0)
            Button {
                showingDetails = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("advisor.details_button.a11y", finding.title))
            .accessibilityIdentifier("advisor.details.\(finding.id)")
            .popover(isPresented: $showingDetails) {
                AdvisorDetailsView(finding: finding)
                    .frame(minWidth: 320, idealWidth: 360, minHeight: 260, idealHeight: 320)
            }
        }
    }
}
