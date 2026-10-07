import Foundation
import HelperProtocol
import Observation
import ServiceManagement

/// CoreTend's side of the optional system helper (decision 0006): installs it with launchd when the
/// person turns it on, removes it when they turn it off, and asks it, over XPC, only the requests
/// of `CoreTendHelperProtocol`.
@MainActor @Observable
final class SystemHelper {
    enum State: Equatable { case off, needsApproval, on, unavailable }

    private(set) var state: State = .off
    private let service = SMAppService.daemon(plistName: HelperIdentity.plistName)

    /// Only the signed public build carries the helper; a local build has no daemon to install.
    var isPackaged: Bool {
        FileManager.default.fileExists(atPath: Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons/\(HelperIdentity.plistName)").path)
    }

    func refresh() {
        guard isPackaged else { state = .unavailable; return }
        switch service.status {
        case .enabled: state = .on
        case .requiresApproval: state = .needsApproval
        case .notRegistered, .notFound: state = .off
        @unknown default: state = .off
        }
    }

    /// Registers the daemon; macOS then asks the person to allow it in Login Items.
    func turnOn() throws {
        do {
            try service.register()
        } catch {
            // Registered but waiting for the person's approval is reported as an error too.
            refresh()
            guard state == .needsApproval else { throw error }
        }
        refresh()
        if state == .needsApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    func turnOff() async throws {
        try await service.unregister()
        refresh()
    }

    func openApproval() { SMAppService.openSystemSettingsLoginItems() }

    // MARK: - Requests

    func systemCaches() async throws -> [SystemCacheItem] {
        let data: Data = try await call { proxy, done in
            proxy.systemCaches { data, failure in done(data.map { .success($0) } ?? .failure(HelperFailure.refused(failure ?? "no-data"))) }
        }
        return try JSONDecoder().decode([SystemCacheItem].self, from: data).sorted { $0.bytes > $1.bytes }
    }

    func trash(_ item: SystemCacheItem) async throws -> String {
        try await call { proxy, done in
            proxy.trashSystemCache(path: item.path) { moved, failure in
                done(moved.map { .success($0) } ?? .failure(HelperFailure.refused(failure ?? "refused")))
            }
        }
    }

    func restore(trashPath: String, originalPath: String) async throws {
        try await call { proxy, done in
            proxy.restoreSystemCache(trashPath: trashPath, originalPath: originalPath) { failure in
                done(failure.map { .failure(HelperFailure.refused($0)) } ?? .success(()))
            }
        }
    }

    func launchDaemons() async throws -> [LaunchDaemonItem] {
        let data: Data = try await call { proxy, done in
            proxy.launchDaemons { data, failure in done(data.map { .success($0) } ?? .failure(HelperFailure.refused(failure ?? "no-data"))) }
        }
        return try JSONDecoder().decode([LaunchDaemonItem].self, from: data)
    }

    func setLaunchDaemon(_ label: String, enabled: Bool) async throws {
        try await call { proxy, done in
            proxy.setLaunchDaemon(label: label, enabled: enabled) { failure in
                done(failure.map { .failure(HelperFailure.refused($0)) } ?? .success(()))
            }
        }
    }

    /// One request on a fresh connection to the privileged Mach service, which must be the helper
    /// signed by CoreTend's team.
    private func call<Value: Sendable>(_ body: @escaping (CoreTendHelperProtocol, @escaping @Sendable (Result<Value, Error>) -> Void) -> Void) async throws -> Value {
        let connection = NSXPCConnection(machServiceName: HelperIdentity.machService, options: .privileged)
        connection.remoteObjectInterface = HelperIdentity.interface()
        connection.setCodeSigningRequirement(HelperIdentity.helperRequirement)
        connection.resume()
        defer { connection.invalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            let once = OnceGate()
            let finish: @Sendable (Result<Value, Error>) -> Void = { result in
                if once.claim() { continuation.resume(with: result) }
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in finish(.failure(error)) }) as? CoreTendHelperProtocol else {
                finish(.failure(HelperFailure.unreachable))
                return
            }
            body(proxy, finish)
        }
    }
}

enum HelperFailure: Error, Equatable {
    case unreachable
    case refused(String)
}

/// Resumes a continuation once, whichever of the reply and the error handler comes first.
private final class OnceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
