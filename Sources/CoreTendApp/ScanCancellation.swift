// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore

/// Shared cancellation contract for every scan-backed view model.
///
/// Why this exists rather than each view model cancelling its own way:
/// `AsyncStream.Iterator.next()` is cancellation-aware. When the consuming task
/// is cancelled it returns `nil` immediately, so the `for await` loop exits
/// *before* the producer's `.cancelled` event is ever delivered. A
/// `case .cancelled: phase = .idle` arm inside that loop is therefore dead code
/// — verified empirically with a standalone reproduction:
///
/// ```
/// boucle sortie — dernier évènement reçu: progress
/// le consommateur a-t-il reçu .cancelled ? NON
/// ```
///
/// The visible consequence was that Cancel appeared not to work: the CPU work
/// did stop, but the UI stayed in its scanning phase forever — spinner running,
/// Cancel still on screen, and the scan impossible to restart because of guards
/// like `guard phase != .scanning else { return }`.
///
/// So the phase must be reset *synchronously by the canceller*, never by an
/// event the canceller has already guaranteed it will not receive. Conforming
/// types supply only the one step that depends on their own `Phase` type.
@MainActor
protocol CancellableScan: AnyObject {
    /// The task running the `for await` loop over the engine's event stream.
    var scanTask: Task<Void, Never>? { get set }

    /// The controller the scan is parked on when paused. It must be resumed as
    /// part of cancelling, otherwise a scan cancelled while paused leaves the
    /// producer suspended forever.
    var pauseController: ScanPauseController? { get set }

    /// Reset the view model's own phase to its idle state, but only if a scan
    /// is actually in progress — cancelling is a no-op on a finished or never
    /// started scan, and must not throw away results already on screen.
    ///
    /// Implemented per conformer because each module's `Phase` carries
    /// different associated values.
    func resetPhaseAfterCancellation()
}

extension CancellableScan {
    /// Cancel the running scan and leave the view model immediately usable
    /// again. Safe to call in any phase, and idempotent.
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil

        // Hand the controller off before resuming: the `Task` below outlives
        // this call, and the property must not still point at a controller the
        // next scan would overwrite.
        let controller = pauseController
        pauseController = nil
        Task { await controller?.resume() }

        resetPhaseAfterCancellation()
    }
}
