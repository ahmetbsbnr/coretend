// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Permission UI localization")
struct PermissionLocalizationTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func keys(_ rel: String) throws -> [String: String] {
        let text = try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf16)
        var out: [String: String] = [:]
        let re = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"(.*)";\s*$"#, options: [.anchorsMatchLines])
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out[ns.substring(with: m.range(at: 1))] = ns.substring(with: m.range(at: 2))
        }
        return out
    }

    @Test func everyPermKeyExistsInBothLanguages() throws {
        let base = try keys("Sources/CoreTendApp/Resources/Base.lproj/Localizable.strings")
        let fr = try keys("Sources/CoreTendApp/Resources/fr.lproj/Localizable.strings")
        let bk = Set(base.keys.filter { $0.hasPrefix("perm.") })
        let fk = Set(fr.keys.filter { $0.hasPrefix("perm.") })
        #expect(bk.count >= 25)
        #expect(bk == fk, "perm.* mismatch: fr missing \(bk.subtracting(fk)), base missing \(fk.subtracting(bk))")
        // Every PermissionState + NotificationPermission case has a label.
        for s in PermissionState.allCases { #expect(base["perm.state.\(s.rawValue)"] != nil, "missing perm.state.\(s.rawValue)") }
        for n in ["notRequested","allowed","denied","provisional","unavailable"] {
            #expect(base["perm.notif.\(n)"] != nil)
        }
        for k in ["perm.section","perm.check_again","perm.last_checked","perm.last_verified","perm.fda.why"] {
            #expect(base[k] != fr[k], "\(k) not translated")
        }
    }
}

// MARK: - Fake filesystem probing

private final class FakeProbing: PermissionFileProbing, @unchecked Sendable {
    /// path -> outcome
    enum Outcome { case readable, permissionDenied, missing, otherError(Int) }
    var map: [String: Outcome]
    private(set) var listCalls = 0
    init(_ map: [String: Outcome]) { self.map = map }

    func fileExists(_ path: String) -> Bool {
        if case .missing = (map[path] ?? .missing) { return false }
        return map[path] != nil
    }
    func listDirectory(_ path: String) throws -> [String] {
        listCalls += 1
        switch map[path] ?? .missing {
        case .readable: return ["x", "y"]
        case .permissionDenied:
            throw NSError(domain: NSCocoaErrorDomain, code: 257, userInfo: [
                NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))])
        case .missing:
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
        case .otherError(let c):
            throw NSError(domain: NSPOSIXErrorDomain, code: c)
        }
    }
}

private func targets(_ home: String) -> [String] { FullDiskAccessProbe.targets(home: home) }

// MARK: - Probe state machine

@Suite("FullDiskAccessProbe state machine")
struct FDAProbeTests {
    let home = "/Users/fake"

    private func probe(_ outcomes: [FakeProbing.Outcome]) -> FullDiskAccessProbe.Result {
        var m: [String: FakeProbing.Outcome] = [:]
        for (t, o) in zip(targets(home), outcomes) { m[t] = o }
        return FullDiskAccessProbe().probe(home: home, fs: FakeProbing(m))
    }

    @Test func allReadableIsGranted() {
        let r = probe(Array(repeating: .readable, count: 8))
        #expect(r.state == .granted)
        #expect(r.readable == 8 && r.permissionDenied == 0)
    }

    @Test func someReadableSomeDeniedIsPartial() {
        let r = probe([.readable, .readable, .permissionDenied, .missing, .missing, .missing, .missing, .missing])
        #expect(r.state == .partial)
        #expect(r.failureReason != nil)
    }

    @Test func noneReadableWithDenialsIsDenied() {
        let r = probe([.permissionDenied, .permissionDenied, .missing, .missing, .missing, .missing, .missing, .missing])
        #expect(r.state == .denied)
    }

    @Test func everythingMissingIsUnavailableNotDenied() {
        let r = probe(Array(repeating: .missing, count: 8))
        #expect(r.state == .unavailable)   // MUST NOT be .denied
        #expect(r.missing == 8)
    }

    @Test func onlyNonPosixErrorsIsProbeError() {
        let r = probe([.otherError(5), .otherError(5), .missing, .missing, .missing, .missing, .missing, .missing])
        #expect(r.state == .error)
    }

    @Test func oneReadableRestMissingStillGranted() {
        // A machine where the user never ran Mail/Safari but /Library/.../TCC is readable.
        let r = probe([.readable, .missing, .missing, .missing, .missing, .missing, .missing, .missing])
        #expect(r.state == .granted)
    }

    /// Informational: the REAL probe against this machine, run twice in the
    /// same process. Both passes must agree (the historical bug was a
    /// single-signal probe that flip-flopped). Does not assert a specific
    /// state — that depends on whether the test host has Full Disk Access.
    @Test func realProbeIsDeterministicWithinAProcess() {
        let a = FullDiskAccessProbe().probe()
        let b = FullDiskAccessProbe().probe()
        print("[perm] real FDA probe: \(a.state.rawValue) " +
              "(readable=\(a.readable) denied=\(a.permissionDenied) missing=\(a.missing) other=\(a.otherErrors) of \(a.targetsTried))")
        #expect(a.state == b.state, "two probes in one process must agree")
        #expect(a.state != .error, "the multi-signal probe should not hard-error on a normal Mac")
    }
}

// MARK: - Coordinator behaviour

@MainActor
@Suite("PermissionCoordinator")
struct PermissionCoordinatorTests {
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "coretend.perm.tests.\(UUID().uuidString)")!
        return d
    }
    private func coord(_ outcomes: [FakeProbing.Outcome], _ defaults: UserDefaults) -> (PermissionCoordinator, FakeProbing) {
        var m: [String: FakeProbing.Outcome] = [:]
        for (t, o) in zip(FullDiskAccessProbe.targets(home: NSHomeDirectory()), outcomes) { m[t] = o }
        let fs = FakeProbing(m)
        return (PermissionCoordinator(probe: FullDiskAccessProbe(), fs: fs, defaults: defaults,
                                      notificationStatusProvider: { .notDetermined }), fs)
    }

    @Test func freshProbeWinsOverPersistedState() async {
        let d = makeDefaults()
        // Seed a stale "denied" diagnostic, then probe a granted machine.
        let (c1, _) = coord([.permissionDenied, .missing, .missing, .missing, .missing, .missing, .missing, .missing], d)
        _ = await c1.refreshNow(.launch)
        #expect(c1.fullDiskAccess == .denied)

        // New coordinator (simulated relaunch), same defaults, but now access is real.
        let (c2, _) = coord(Array(repeating: .readable, count: 8), d)
        let state = await c2.refreshNow(.launch)
        #expect(state == .granted, "a fresh probe must override the persisted 'denied'")
        #expect(c2.lastSuccessfulCheckAt != nil)
    }

    @Test func relaunchWithRealAccessNeverShowsDeniedFiveTimes() async {
        let d = makeDefaults()
        for i in 1...5 {
            let (c, _) = coord(Array(repeating: .readable, count: 8), d)
            let s = await c.refreshNow(.launch)
            #expect(s == .granted, "relaunch #\(i) must report Granted, not stale Unverified/Denied")
        }
    }

    @Test func transientErrorDoesNotClobberKnownGoodState() async {
        let d = makeDefaults()
        let (c, fs) = coord(Array(repeating: .readable, count: 8), d)
        _ = await c.refreshNow(.launch)
        #expect(c.fullDiskAccess == .granted)
        // Simulate a transient probe failure on the next refresh.
        for t in FullDiskAccessProbe.targets(home: NSHomeDirectory()) { fs.map[t] = .otherError(5) }
        let s = await c.refreshNow(.appActive)
        #expect(s == .granted, "a transient error must not flip a known-good Granted to Error")
        #expect(c.lastFailureReason != nil)
    }

    @Test func legacyVerifiedKeysAreRetiredAndNeverConsulted() async {
        let d = makeDefaults()
        d.set(true, forKey: "fdaVerified")
        d.set(false, forKey: "permissionsUnverified")
        d.set(true, forKey: "hasFullDiskAccess")
        let (c, _) = coord([.permissionDenied, .missing, .missing, .missing, .missing, .missing, .missing, .missing], d)
        #expect(d.object(forKey: "fdaVerified") == nil)
        #expect(d.object(forKey: "hasFullDiskAccess") == nil)
        let s = await c.refreshNow(.launch)
        #expect(s == .denied, "the retired 'hasFullDiskAccess=true' must not override a real denial")
    }

    @Test func diagnosticsRecordCheckTimestamps() async {
        let d = makeDefaults()
        let (c, _) = coord(Array(repeating: .readable, count: 8), d)
        #expect(c.lastCheckedAt == nil)
        _ = await c.refreshNow(.manual)
        #expect(c.lastCheckedAt != nil)
        #expect(c.lastSuccessfulCheckAt != nil)
        let text = c.diagnosticsText(appVersion: "1.2.0-beta.1", buildNumber: "1200", channel: "beta",
            bundleID: "com.ahmetbsbnr.coretend", signingMode: "developer", teamID: "NSCUV5G738")
        #expect(text.contains("full disk access: granted"))
        #expect(text.contains("bundle id: com.ahmetbsbnr.coretend"))
        #expect(!text.lowercased().contains("token"))
    }

    @Test func settingsAndDeepScanDeriveSameStateFromCoordinator() async {
        // Both surfaces read PermissionCoordinator.shared; assert the Deep Scan
        // mapping is a pure function of the coordinator state (no independent probe).
        for state in PermissionState.allCases {
            let mapped = DeepScanViewModel.mapPermission(state)
            switch state {
            case .granted: #expect(mapped == .fullDiskAccess)
            case .error: #expect(mapped == .scanError)
            case .unavailable: #expect(mapped == .protectedByOS)
            default: #expect(mapped == .partialAccess)   // never claims Full when Settings wouldn't
            }
            // Settings never shows "Full" for a non-granted state either.
            if state != .granted { #expect(PermissionFormatting.fdaLabel(state) != PermissionFormatting.fdaLabel(.granted)) }
        }
    }

    @Test func revokedWhileOpenFlipsToDeniedOnNextRefresh() async {
        let d = makeDefaults()
        let (c, fs) = coord(Array(repeating: .readable, count: 8), d)
        _ = await c.refreshNow(.launch)
        #expect(c.fullDiskAccess == .granted)
        // User revokes FDA in System Settings while CoreTend is open.
        for t in FullDiskAccessProbe.targets(home: NSHomeDirectory()) { fs.map[t] = .permissionDenied }
        let s = await c.refreshNow(.returnFromSystemSettings)
        #expect(s == .denied, "a real revocation must be reflected, not masked as Granted")
    }

    @Test func staleGrantedNeverSurvivesAFailedProbe_butErrorDoesNotClobberIt() async {
        // "A stale 'Granted' state must never survive a failed current probe."
        // We distinguish a *denial* (must flip to denied) from a *probe error*
        // (keep last good, surface the reason).
        let d = makeDefaults()
        let (c, fs) = coord(Array(repeating: .readable, count: 8), d)
        _ = await c.refreshNow(.launch)
        // genuine denial -> must NOT stay granted
        for t in FullDiskAccessProbe.targets(home: NSHomeDirectory()) { fs.map[t] = .permissionDenied }
        #expect(await c.refreshNow(.manual) == .denied)
        // probe error after a good state -> keeps the good state + reason
        let (c2, fs2) = coord(Array(repeating: .readable, count: 8), makeDefaults())
        _ = await c2.refreshNow(.launch)
        for t in FullDiskAccessProbe.targets(home: NSHomeDirectory()) { fs2.map[t] = .otherError(5) }
        #expect(await c2.refreshNow(.manual) == .granted)
        #expect(c2.lastFailureReason != nil)
    }

    @Test func debouncedRefreshCoalesces() async {
        let d = makeDefaults()
        let (c, fs) = coord(Array(repeating: .readable, count: 8), d)
        c.refresh(.appActive, debounce: .milliseconds(80))
        c.refresh(.appActive, debounce: .milliseconds(80))
        c.refresh(.settingsAppear, debounce: .milliseconds(80))
        try? await Task.sleep(for: .milliseconds(300))
        #expect(fs.listCalls <= FullDiskAccessProbe.targets(home: NSHomeDirectory()).count + 2,
                "three rapid triggers must collapse to ~one probe pass")
        #expect(c.fullDiskAccess == .granted)
    }
}
