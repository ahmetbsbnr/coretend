// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppIntents
import CoreTendApp

/// The small, deliberately non-duplicative App Shortcuts catalog CoreTend
/// exposes to the Shortcuts app and Spotlight. Six entries, each backed by a
/// read-only intent. Every phrase includes `\(.applicationName)` as Apple
/// requires. Phrases and short titles are English string literals — the App
/// Intents metadata extractor requires main-bundle literals (see the note in
/// `CoreTendIntents.swift`); all spoken/returned results remain EN + FR.
struct CoreTendAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetCoreTendSummaryIntent(),
            phrases: [
                "Check \(.applicationName) storage",
                "\(.applicationName) storage summary",
            ],
            shortTitle: "CoreTend Summary",
            systemImageName: "internaldrive")

        AppShortcut(
            intent: GetStorageChangeIntent(),
            phrases: [
                "What changed on my Mac in \(.applicationName)",
                "\(.applicationName) what changed",
            ],
            shortTitle: "What Changed",
            systemImageName: "chart.xyaxis.line")

        AppShortcut(
            intent: GetFreeDiskSpaceIntent(),
            phrases: [
                "Check disk space with \(.applicationName)",
                "How much free space does \(.applicationName) see",
            ],
            shortTitle: "Free Disk Space",
            systemImageName: "externaldrive")

        AppShortcut(
            intent: GetReclaimableDeveloperStorageIntent(),
            phrases: [
                "Check developer storage with \(.applicationName)",
                "\(.applicationName) developer cache size",
            ],
            shortTitle: "Developer Storage",
            systemImageName: "hammer")

        AppShortcut(
            intent: InspectImageMetadataIntent(),
            phrases: [
                "Inspect image metadata with \(.applicationName)",
                "Check an image's metadata in \(.applicationName)",
            ],
            shortTitle: "Inspect Image Metadata",
            systemImageName: "eye.trianglebadge.exclamationmark")

        AppShortcut(
            intent: OpenCoreTendModuleIntent(),
            phrases: [
                "Open \(.applicationName) \(\.$module)",
                "Open the \(\.$module) screen in \(.applicationName)",
            ],
            shortTitle: "Open CoreTend Screen",
            systemImageName: "arrow.up.forward.app")
    }
}
