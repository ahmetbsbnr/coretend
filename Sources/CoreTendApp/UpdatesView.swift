// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// The update surface: check, report, link out. It never downloads or
/// installs anything — see UpdateChecker for why that boundary exists.
@MainActor
@Observable
final class UpdatesViewModel {
    enum Phase: Equatable {
        case idle
        case checking
        case result(UpdateStatus)
    }

    var phase: Phase = .idle
    var channel: UpdateChannel {
        didSet {
            UserDefaults.standard.set(channel.rawValue, forKey: Self.channelKey)
            // Switching channel invalidates the throttle: a stable user opting
            // into prereleases expects an answer now, not in 24 hours.
            lastCheck = nil
        }
    }

    /// Off by default, and stays off until the user turns it on. Checking is a
    /// network request to a third party's server; doing it unasked is not a
    /// default an app that advertises working fully offline gets to take.
    var automatic: Bool {
        didSet { UserDefaults.standard.set(automatic, forKey: Self.automaticKey) }
    }

    /// When the last successful check ran. Persisted so the throttle survives
    /// relaunches — otherwise "once a day" becomes "every launch".
    private(set) var lastCheck: Date? {
        didSet {
            if let lastCheck {
                UserDefaults.standard.set(lastCheck.timeIntervalSince1970, forKey: Self.lastCheckKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastCheckKey)
            }
        }
    }

    /// The file the user picked for checksum verification, and the verdict.
    var verification: DownloadVerification.Outcome?
    var isVerifying = false

    static let channelKey = "updateChannel"
    static let automaticKey = "updatesAutomatic"
    static let lastCheckKey = "updatesLastCheck"

    /// One check a day is enough for an app released a handful of times a
    /// year, and it keeps the request rare enough to stay unremarkable.
    nonisolated static let automaticInterval: TimeInterval = 24 * 60 * 60

    /// The published manifest for the current release. Static and HTTPS: the
    /// app never discovers an endpoint at runtime.
    static let manifestURL = URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!

    init() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: Self.channelKey) ?? UpdateChannel.stable.rawValue
        channel = UpdateChannel(rawValue: raw) ?? .stable
        automatic = defaults.bool(forKey: Self.automaticKey)
        let stamp = defaults.double(forKey: Self.lastCheckKey)
        lastCheck = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// Whether an automatic check is due. Pure, so the throttle is testable
    /// without waiting a day.
    nonisolated static func isDue(automatic: Bool, lastCheck: Date?, now: Date) -> Bool {
        guard automatic else { return false }
        guard let lastCheck else { return true }
        // A clock that moved backwards (timezone edit, NTP correction) must not
        // suppress checks until it catches up.
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= automaticInterval
    }

    /// Called on launch. Does nothing unless the user opted in and the throttle
    /// has expired, and never reports an error to the UI: an automatic check
    /// that fails is not an event the user asked to be told about.
    func checkAutomaticallyIfDue(now: Date = Date()) async {
        guard Self.isDue(automatic: automatic, lastCheck: lastCheck, now: now) else { return }
        await check(now: now, surfaceFailures: false)
    }

    var installedVersion: String {
        AppMetadata.marketingVersion
    }

    func check(now: Date = Date(), surfaceFailures: Bool = true) async {
        phase = .checking
        verification = nil
        guard let checker = UpdateChecker(
            manifestURL: Self.manifestURL,
            currentVersion: installedVersion,
            channel: channel)
        else {
            phase = .result(.failed(.notConfigured))
            return
        }
        let status = await checker.check()
        if case .failed = status {
            // Only a successful check advances the throttle, so a week offline
            // does not silently consume the day's allowance.
            phase = surfaceFailures ? .result(status) : .idle
            return
        }
        lastCheck = now
        phase = .result(status)
    }

    /// The artifact the current result publishes, if any — what a picked file
    /// gets compared against.
    var verifiableRelease: ReleaseInfo? {
        if case .result(.updateAvailable(let info)) = phase { return info }
        return nil
    }

    /// Hashes the picked file off the main actor and records the verdict.
    func verify(fileAt url: URL) async {
        guard let release = verifiableRelease,
              let artifact = DownloadVerification.artifact(for: url, in: release)
        else {
            verification = .unreadable(url.lastPathComponent)
            return
        }
        isVerifying = true
        defer { isVerifying = false }
        verification = await Task.detached {
            DownloadVerification.verify(fileAt: url, against: artifact)
        }.value
    }
}

struct UpdatesView: View {
    @State private var model = UpdatesViewModel()

    var body: some View {
        Section(L("updates.title")) {
            LabeledContent(L("updates.installed"), value: model.installedVersion)

            Toggle(L("updates.automatic"), isOn: Binding(
                get: { model.automatic },
                set: { model.automatic = $0 }))
                .accessibilityIdentifier("updates.automatic")
            Text(L("updates.automatic_detail"))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
            if let last = model.lastCheck {
                LabeledContent(L("updates.last_checked"),
                               value: AppDateFormatting.string(last, style: .dayMonthYearWithTime))
            }

            Picker(L("updates.channel"), selection: Binding(
                get: { model.channel },
                set: { model.channel = $0 })) {
                Text(L("updates.channel_stable")).tag(UpdateChannel.stable)
                Text(L("updates.channel_prerelease")).tag(UpdateChannel.prerelease)
            }
            Text(L("updates.channel_detail"))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)

            HStack {
                Button(L("updates.check_now")) {
                    Task { await model.check() }
                }
                .disabled(model.phase == .checking)
                if model.phase == .checking {
                    ProgressView().controlSize(.small)
                }
            }

            resultRow

            // Stated here rather than only on the website: the app must not
            // imply it can update itself safely when it cannot.
            Text(L("updates.no_autoinstall"))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
        }
    }

    @ViewBuilder
    private var resultRow: some View {
        if case .result(let status) = model.phase {
            switch status {
            case .upToDate(let current):
                Label(L("updates.up_to_date", current), systemImage: "checkmark.circle")
                    .foregroundStyle(MCTheme.accent)
            case .updateAvailable(let info):
                VStack(alignment: .leading, spacing: 6) {
                    Label(L("updates.available", info.version), systemImage: "arrow.down.circle")
                    if info.prerelease {
                        Text(L("updates.is_prerelease")).font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                    }
                    // Never softened: an unsigned build stays labelled as one
                    // at the exact moment the user is deciding to fetch it.
                    if !info.signed || !info.notarized {
                        Text(L("updates.unsigned_warning"))
                            .font(MCFont.caption).foregroundStyle(MCTheme.warning)
                    }
                    if let notes = info.notes, !notes.isEmpty {
                        Text(notes).font(MCFont.caption).foregroundStyle(MCColor.textSecondary).lineLimit(6)
                    }
                    if let url = info.releaseURL {
                        Button(L("updates.open_release")) { NSWorkspace.shared.open(url) }
                    }
                    verificationControls(for: info)
                }
            case .failed(let error):
                Label(message(for: error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(MCTheme.warning)
            }
        }
    }

    /// Checksum verification of a file the user already downloaded. Offered
    /// only when the release actually publishes a checksum to compare against:
    /// a verify button that cannot verify anything is worse than none.
    @ViewBuilder
    private func verificationControls(for info: ReleaseInfo) -> some View {
        if info.dmg != nil || info.zip != nil {
            HStack {
                Button(L("updates.verify_download")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false
                    panel.message = L("updates.verify_prompt")
                    panel.directoryURL = FileManager.default.urls(
                        for: .downloadsDirectory, in: .userDomainMask).first
                    if panel.runModal() == .OK, let url = panel.url {
                        Task { await model.verify(fileAt: url) }
                    }
                }
                .disabled(model.isVerifying)
                .accessibilityIdentifier("updates.verify")
                if model.isVerifying { ProgressView().controlSize(.small) }
            }
            if let outcome = model.verification {
                verdict(outcome)
            }
            Text(L("updates.verify_detail"))
                .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
        }
    }

    /// Each outcome says what it means, not just pass/fail. "The checksum does
    /// not match" with two 64-character hex strings tells a user nothing they
    /// can act on.
    @ViewBuilder
    private func verdict(_ outcome: DownloadVerification.Outcome) -> some View {
        switch outcome {
        case .verified(let artifact):
            Label(L("updates.verify_ok", artifact), systemImage: "checkmark.seal.fill")
                .foregroundStyle(MCTheme.success)
        case .wrongSize(let expected, let actual):
            Label(L("updates.verify_wrong_size", mcFormatBytes(expected), mcFormatBytes(actual)),
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(MCTheme.warning)
        case .mismatch:
            Label(L("updates.verify_mismatch"), systemImage: "xmark.seal.fill")
                .foregroundStyle(MCTheme.danger)
        case .unreadable(let name):
            Label(L("updates.verify_unreadable", name), systemImage: "questionmark.circle")
                .foregroundStyle(MCColor.textSecondary)
        }
    }

    private func message(for error: UpdateCheckError) -> String {
        switch error {
        case .offline: L("updates.error_offline")
        case .notConfigured: L("updates.error_not_configured")
        case .cancelled: L("updates.error_cancelled")
        case .malformedManifest: L("updates.error_malformed")
        case .badResponse(let code): L("updates.error_response", String(code))
        }
    }
}
