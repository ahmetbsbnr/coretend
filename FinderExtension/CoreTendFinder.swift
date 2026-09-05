// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

//
// CoreTend's Finder Sync extension: a USER-INITIATED, READ-ONLY entry point
// into CoreTend.
//
// It does almost nothing. On a right-click it obtains the current Finder
// selection, decides which CoreTend actions apply *from single-item attributes*
// (`FinderSelectionClassifier` — no file is opened, no EXIF parsed, no
// Mach-O read, no directory sized, no signature checked), and, when the user
// picks one, opens a single `coretend://finder/...` URL so the host can do
// the real work. That is the entire contract.
//
// It links ONLY `FinderShared` (+ the FinderSync / AppKit system
// frameworks). By construction it cannot reach ScanCore, SafetyCore,
// FileRules, Persistence, AppDiscovery, IntegrityCore, RecoveryPlanService,
// RestoreService, or CleanupExecution — there is no destructive code path to
// hide. `FinderExtensionSafetyTests` re-checks that at the source and
// dependency level.
//
// No badges, no recursive filesystem observation: only `menu(for:)` is
// implemented.
//

import Foundation
import Darwin
import FinderSync
import AppKit
import FinderShared

final class CoreTendFinderSync: FIFinderSync {

    override init() {
        super.init()
        // Register the narrowest set of roots that still makes all three
        // actions useful:
        //   • the user's home  — Desktop / Documents / Downloads / anywhere
        //     the user keeps files and images;
        //   • /Applications    — "Inspect Application Integrity" on installed
        //     apps (apps in ~/Applications are already covered by home);
        //   • /Volumes         — external and network drives.
        // The CoreTend context menu does NOT appear for selections outside
        // these three roots — a documented coverage limit, chosen over
        // registering "/" (the whole filesystem). Registering a path that
        // does not exist is harmless, so there is no filesystem probe here.
        guard let account = getpwuid(getuid()), let homePath = account.pointee.pw_dir else { return }
        let home = URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
        FIFinderSyncController.default().directoryURLs = [
            home,
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
        ]
    }

    // MARK: Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        let selection = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard selection.count == 1 else { return nil }
        let menu = NSMenu(title: "CoreTend")

        // v1 offers no action for empty, unsupported, or multiple selections.
        if selection.count == 1, let url = selection.first {
            for action in FinderSelectionClassifier.actions(for: url) {
                let item = NSMenuItem(title: label(for: action),
                                      action: selector(for: action),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.image = NSImage(systemSymbolName: symbol(for: action),
                                     accessibilityDescription: nil)
                menu.addItem(item)
            }
        }

        guard menu.numberOfItems > 0 else { return nil }

        return menu
    }

    // MARK: Actions — each only builds and opens a coretend:// URL.

    @objc private func scanFolderAction(_ sender: NSMenuItem) { hand(.scanFolder, sender) }
    @objc private func inspectImageAction(_ sender: NSMenuItem) { hand(.inspectImage, sender) }
    @objc private func inspectApplicationAction(_ sender: NSMenuItem) { hand(.inspectApplication, sender) }

    private func hand(_ action: FinderAction, _ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let handoff = FinderHandoffURL.make(action: action, path: url.path)
        else { return }
        // A single well-formed custom-scheme URL. LaunchServices routes it to
        // the containing CoreTend host (launching it if needed). No payload leaves this
        // Mac; no App Group, no security-scoped bookmark.
        guard let host = hostApplicationURL() else { return }
        NSWorkspace.shared.open([handoff], withApplicationAt: host,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Helpers

    private func label(for action: FinderAction) -> String {
        switch action {
        case .scanFolder: return FL("finder.menu.scan_folder")
        case .inspectImage: return FL("finder.menu.inspect_image")
        case .inspectApplication: return FL("finder.menu.inspect_application")
        }
    }

    private func selector(for action: FinderAction) -> Selector {
        switch action {
        case .scanFolder: return #selector(scanFolderAction(_:))
        case .inspectImage: return #selector(inspectImageAction(_:))
        case .inspectApplication: return #selector(inspectApplicationAction(_:))
        }
    }

    private func symbol(for action: FinderAction) -> String {
        switch action {
        case .scanFolder: return "circle.hexagongrid"
        case .inspectImage: return "photo"
        case .inspectApplication: return "checkmark.seal"
        }
    }

    /// …/CoreTend.app/Contents/PlugIns/CoreTendFinder.appex → …/CoreTend.app
    private func hostApplicationURL() -> URL? {
        Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns
            .deletingLastPathComponent()   // Contents
            .deletingLastPathComponent()   // CoreTend.app
    }
}
