// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppIntents

/// The small, deliberately non-duplicative App Shortcuts catalog CoreTend
/// exposes to the Shortcuts app and Spotlight. Six entries, each backed by a
/// read-only intent. Every phrase includes `\(.applicationName)` as Apple
/// requires; phrases and titles resolve from CoreTend's own string table
/// (EN + FR).
struct CoreTendAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetCoreTendSummaryIntent(),
            phrases: [
                "Check \(.applicationName) storage",
                "\(.applicationName) storage summary",
            ],
            shortTitle: .ct("shortcut.summary.short"),
            systemImageName: "internaldrive")

        AppShortcut(
            intent: GetStorageChangeIntent(),
            phrases: [
                "What changed on my Mac in \(.applicationName)",
                "\(.applicationName) what changed",
            ],
            shortTitle: .ct("shortcut.change.short"),
            systemImageName: "chart.xyaxis.line")

        AppShortcut(
            intent: GetFreeDiskSpaceIntent(),
            phrases: [
                "Check disk space with \(.applicationName)",
                "How much free space does \(.applicationName) see",
            ],
            shortTitle: .ct("shortcut.freespace.short"),
            systemImageName: "externaldrive")

        AppShortcut(
            intent: GetReclaimableDeveloperStorageIntent(),
            phrases: [
                "Check developer storage with \(.applicationName)",
                "\(.applicationName) developer cache size",
            ],
            shortTitle: .ct("shortcut.devstorage.short"),
            systemImageName: "hammer")

        AppShortcut(
            intent: InspectImageMetadataIntent(),
            phrases: [
                "Inspect image metadata with \(.applicationName)",
                "Check an image's metadata in \(.applicationName)",
            ],
            shortTitle: .ct("shortcut.imagemeta.short"),
            systemImageName: "eye.trianglebadge.exclamationmark")

        AppShortcut(
            intent: OpenCoreTendModuleIntent(),
            phrases: [
                "Open \(.applicationName) \(\.$module)",
                "Open the \(\.$module) screen in \(.applicationName)",
            ],
            shortTitle: .ct("shortcut.open.short"),
            systemImageName: "arrow.up.forward.app")
    }
}
