import Foundation

public enum VisibleSamplingLoop {
    public static func run(interval: Duration, sample: @MainActor @Sendable () async -> Void) async {
        guard interval > .zero else { return }
        while !Task.isCancelled {
            await sample()
            guard !Task.isCancelled else { return }
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }
}
