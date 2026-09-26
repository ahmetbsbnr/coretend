import Foundation
import SafetyCore
import Persistence

public struct FileActionSelection: Sendable, Equatable {
    public let url: URL
    public let ruleID: String
    public let isProtectedKeeper: Bool
    public init(url: URL, ruleID: String, isProtectedKeeper: Bool = false) {
        self.url = url; self.ruleID = ruleID; self.isProtectedKeeper = isProtectedKeeper
    }
}

public enum ActionReviewError: Error, Equatable { case empty, duplicateTarget, protectedKeeperSelected, ruleNotAllowed, declined }

public struct ActionReview: Sendable {
    public let id: UUID
    public let items: [FileActionSelection]
    fileprivate init(items: [FileActionSelection]) { id = UUID(); self.items = items }
}

public struct ConfirmedActionBatch: Sendable {
    public let reviewID: UUID
    fileprivate let items: [FileActionSelection]
    fileprivate init(review: ActionReview) { reviewID = review.id; items = review.items }
}

public struct ActionItemResult: Sendable, Equatable {
    public let targetURL: URL
    public let outcome: ActionOutcome
    public let historyRecorded: Bool
}

public struct ActionBatchReport: Sendable, Equatable {
    public let reviewID: UUID
    public let items: [ActionItemResult]
    public var movedCount: Int { items.filter { if case .movedToTrash = $0.outcome { true } else { false } }.count }
}

public struct FileActionService: Sendable {
    private let validator: PathValidator
    private let executor: any FileOperationExecutor
    private let store: SQLiteStore
    private let allowedRoots: [URL]
    private let allowedRuleIDs: Set<String>
    private let clock: @Sendable () -> Date

    public init(validator: PathValidator, executor: any FileOperationExecutor, store: SQLiteStore,
                allowedRoots: [URL], allowedRuleIDs: Set<String>,
                clock: @escaping @Sendable () -> Date = { .now }) {
        self.validator = validator; self.executor = executor; self.store = store
        self.allowedRoots = allowedRoots; self.allowedRuleIDs = allowedRuleIDs; self.clock = clock
    }

    public func prepareReview(_ selections: [FileActionSelection]) throws -> ActionReview {
        guard !selections.isEmpty else { throw ActionReviewError.empty }
        guard selections.allSatisfy({ allowedRuleIDs.contains($0.ruleID) }) else { throw ActionReviewError.ruleNotAllowed }
        guard !selections.contains(where: \.isProtectedKeeper) else { throw ActionReviewError.protectedKeeperSelected }
        let paths = selections.map { $0.url.standardizedFileURL.path }
        guard Set(paths).count == paths.count else { throw ActionReviewError.duplicateTarget }
        return ActionReview(items: selections)
    }

    @discardableResult
    public func recordProposal(_ review: ActionReview) async -> Bool {
        var allRecorded = true
        for selection in review.items {
            do { try await store.append(ActivityEvent(id: UUID(), occurredAt: clock(), kind: .proposed, detail: selection.url.path)) }
            catch { allRecorded = false }
        }
        return allRecorded
    }

    public func confirm(_ review: ActionReview, accepted: Bool) throws -> ConfirmedActionBatch {
        guard accepted else { throw ActionReviewError.declined }
        return ConfirmedActionBatch(review: review)
    }

    @discardableResult
    public func recordRefusal(_ review: ActionReview) async -> Bool {
        await record(review, kind: .refused)
    }

    @discardableResult
    public func recordCancellation(_ review: ActionReview) async -> Bool {
        await record(review, kind: .cancelled)
    }

    private func record(_ review: ActionReview, kind: ActivityKind) async -> Bool {
        var allRecorded = true
        for selection in review.items {
            do { try await store.append(ActivityEvent(id: UUID(), occurredAt: clock(), kind: kind, detail: selection.url.path)) }
            catch { allRecorded = false }
        }
        return allRecorded
    }

    public func execute(_ batch: ConfirmedActionBatch) async -> ActionBatchReport {
        var results: [ActionItemResult] = []
        for selection in batch.items {
            let approved: ApprovedFileOperation
            do {
                approved = try validator.approve(target: selection.url, allowedRoots: allowedRoots,
                                                 ruleID: selection.ruleID, allowedRuleIDs: allowedRuleIDs,
                                                 now: clock())
            } catch let refusal as PathRefusal {
                let recorded = await recordFailure(for: selection.url)
                results.append(ActionItemResult(targetURL: selection.url, outcome: .failed(.revalidation(refusal)), historyRecorded: recorded))
                continue
            } catch {
                let recorded = await recordFailure(for: selection.url)
                results.append(ActionItemResult(targetURL: selection.url, outcome: .failed(.revalidation(.missingTarget)), historyRecorded: recorded))
                continue
            }

            do {
                try await store.append(ActivityEvent(id: UUID(), occurredAt: clock(), kind: .approved, detail: selection.url.path))
            } catch {
                results.append(ActionItemResult(targetURL: selection.url, outcome: .failed(.auditUnavailable), historyRecorded: false))
                continue
            }

            let outcome = await executor.execute(approved)
            let event = ActivityEvent(id: UUID(), occurredAt: clock(), kind: activityKind(for: outcome), detail: selection.url.path)
            let recorded: Bool
            do { try await store.append(event); recorded = true }
            catch { recorded = false }
            results.append(ActionItemResult(targetURL: selection.url, outcome: outcome, historyRecorded: recorded))
        }
        return ActionBatchReport(reviewID: batch.reviewID, items: results)
    }

    private func activityKind(for outcome: ActionOutcome) -> ActivityKind {
        switch outcome {
        case .movedToTrash: .movedToTrash
        case .refused: .refused
        case .failed: .failed
        case .cancelled: .cancelled
        }
    }

    private func recordFailure(for url: URL) async -> Bool {
        do {
            try await store.append(ActivityEvent(id: UUID(), occurredAt: clock(), kind: .failed, detail: url.path))
            return true
        } catch { return false }
    }
}
