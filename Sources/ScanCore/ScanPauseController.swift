import Foundation

/// Lets a caller pause and resume a running `ScanEngine.run(rules:)` walk from
/// the outside.
///
/// An earlier version of this type blocked the calling OS thread with
/// `NSCondition.wait` while paused. That deadlocked for real: `ScanEngine`'s
/// walk runs as a child task on Swift Concurrency's shared cooperative
/// executor, which has a small, fixed thread pool. A thread genuinely blocked
/// (not suspended) inside that pool cannot be reclaimed to run anything else —
/// including the very `resume()` call needed to unblock it — under any
/// scheduling pressure that leaves few free pool threads. This actor suspends
/// paused scans on continuations instead, so threads return to the pool and a
/// later resume or cancellation can always make progress.
public actor ScanPauseController {
    private var paused = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    public init() {}

    public var isPaused: Bool { paused }

    public func pause() { paused = true }

    public func resume() {
        guard paused else { return }
        paused = false
        let continuations = Array(waiters.values)
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    /// Suspends while paused without polling or blocking an executor thread.
    /// If the scan task is cancelled while paused, its waiter is released so
    /// teardown does not need a matching `resume()`.
    func waitWhilePaused() async {
        guard paused else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled || !paused {
                    continuation.resume()
                } else {
                    waiters[id] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume()
    }
}
