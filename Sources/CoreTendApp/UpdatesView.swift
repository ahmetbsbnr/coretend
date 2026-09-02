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
        didSet { UserDefaults.standard.set(channel.rawValue, forKey: Self.channelKey) }
    }

    static let channelKey = "updateChannel"

    /// The published manifest for the current release. Static and HTTPS: the
    /// app never discovers an endpoint at runtime.
    static let manifestURL = URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.channelKey) ?? UpdateChannel.stable.rawValue
        channel = UpdateChannel(rawValue: raw) ?? .stable
    }

    var installedVersion: String {
        AppMetadata.marketingVersion
    }

    func check() async {
        phase = .checking
        guard let checker = UpdateChecker(
            manifestURL: Self.manifestURL,
            currentVersion: installedVersion,
            channel: channel)
        else {
            phase = .result(.failed(.notConfigured))
            return
        }
        phase = .result(await checker.check())
    }
}

struct UpdatesView: View {
    @State private var model = UpdatesViewModel()

    var body: some View {
        Section(L("updates.title")) {
            LabeledContent(L("updates.installed"), value: model.installedVersion)

            Picker(L("updates.channel"), selection: Binding(
                get: { model.channel },
                set: { model.channel = $0 })) {
                Text(L("updates.channel_stable")).tag(UpdateChannel.stable)
                Text(L("updates.channel_prerelease")).tag(UpdateChannel.prerelease)
            }
            Text(L("updates.channel_detail"))
                .font(.caption).foregroundStyle(.secondary)

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
                .font(.caption).foregroundStyle(.secondary)
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
                        Text(L("updates.is_prerelease")).font(.caption).foregroundStyle(.secondary)
                    }
                    // Never softened: an unsigned build stays labelled as one
                    // at the exact moment the user is deciding to fetch it.
                    if !info.signed || !info.notarized {
                        Text(L("updates.unsigned_warning"))
                            .font(.caption).foregroundStyle(MCTheme.warning)
                    }
                    if let notes = info.notes, !notes.isEmpty {
                        Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(6)
                    }
                    if let url = info.releaseURL {
                        Button(L("updates.open_release")) { NSWorkspace.shared.open(url) }
                        Button(L("updates.how_to_verify")) {
                            NSWorkspace.shared.open(
                                URL(string: "https://coretend.ahmetbsbnr.com/support#releases")!)
                        }
                    }
                }
            case .failed(let error):
                Label(message(for: error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(MCTheme.warning)
            }
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
