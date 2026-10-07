import AppKit
import FinderSync

// The Finder's right-click menu: « Analyser avec CoreTend » on a folder (or the folder being shown)
// opens CoreTend's map of it. The extension reads nothing and moves nothing; it only hands the
// folder's path to the app through its link `coretend://scan?path=…`.

@objc(CoreTendFinderSync)
final class CoreTendFinderSync: FIFinderSync {
    override init() {
        super.init()
        // Every folder of every volume, so the menu item is always there.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        guard target(for: menuKind) != nil else { return nil }
        let french = Locale.preferredLanguages.first?.hasPrefix("fr") == true
        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: french ? "Analyser avec CoreTend" : "Analyze with CoreTend",
                              action: #selector(analyze(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil)
        menu.addItem(item)
        return menu
    }

    @objc private func analyze(_ sender: NSMenuItem) {
        let controller = FIFinderSyncController.default()
        let kind: FIMenuKind = (controller.selectedItemURLs()?.isEmpty == false) ? .contextualMenuForItems : .contextualMenuForContainer
        guard let folder = target(for: kind) else { return }
        var components = URLComponents()
        components.scheme = "coretend"
        components.host = "scan"
        components.queryItems = [URLQueryItem(name: "path", value: folder.path)]
        if let link = components.url { NSWorkspace.shared.open(link) }
    }

    /// The one folder the menu is about: a single selected folder, or the folder being shown.
    private func target(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()
        if menuKind == .contextualMenuForItems {
            // The sandbox may not let the extension read the item, so a folder is also known by the
            // trailing slash the Finder gives folder URLs.
            guard let items = controller.selectedItemURLs(), items.count == 1,
                  items[0].hasDirectoryPath || (try? items[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { return nil }
            return items[0]
        }
        return controller.targetedURL()
    }
}
