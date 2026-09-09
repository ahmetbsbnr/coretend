// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// PermissionQA — a fresh process that runs the real FullDiskAccessProbe once
// and prints the outcome as one line. The 5-relaunch and rebuild-persistence
// regression checks (Scripts run it repeatedly) rely on every fresh process
// reporting the SAME state for the same actual access — the historical bug was
// a single-signal probe that flip-flopped between launches.
//
//   swift run PermissionQA
//   -> state=granted readable=8 denied=0 missing=0 other=0 targets=8

import Foundation
import CoreTendApp

let r = FullDiskAccessProbe().probe()
print("state=\(r.state.rawValue) readable=\(r.readable) denied=\(r.permissionDenied) "
      + "missing=\(r.missing) other=\(r.otherErrors) targets=\(r.targetsTried)"
      + (r.failureReason.map { " reason=\"\($0)\"" } ?? ""))
// Exit code encodes the state so a shell loop can compare without parsing.
switch r.state {
case .granted: exit(0)
case .partial: exit(10)
case .denied: exit(11)
case .unavailable: exit(12)
case .error: exit(13)
default: exit(20)
}
