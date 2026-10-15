import AppKit
import AppShell

/// A short system sound when a scan or a clean ends, only when the person turned it on in
/// Settings. Nothing waits on it and nothing is delayed for it.
enum CompletionSound {
    @MainActor static func play() {
        guard CoreTendPreferences().soundsEnabled else { return }
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
