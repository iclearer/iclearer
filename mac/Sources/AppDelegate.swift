import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var mainController: MainViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ship dark by default (prototype default); Settings can later follow system.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Refresh signed license when online (offline grace still applies).
        LicenseStore.heartbeatIfNeeded()

        buildMenus()
        let controller = MainViewController()
        mainController = controller
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "iClearer"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 980, height: 640)
        window.contentViewController = controller
        window.center()
        // Avoid macOS “unexpectedly quit / reopen windows?” after a crash.
        window.isRestorable = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenus() {
        let main = NSMenu()

        // iClearer
        let appMenu = NSMenu(title: "iClearer")
        appMenu.addItem(withTitle: "About iClearer", action: #selector(MainViewController.menuAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(MainViewController.menuSettings), keyEquivalent: ",")
        appMenu.addItem(withTitle: "Account…", action: #selector(MainViewController.menuAccount), keyEquivalent: "")
        appMenu.addItem(withTitle: "Unlock iClearer…", action: #selector(MainViewController.menuUpgrade), keyEquivalent: "")
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: "Quit iClearer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)

        // File
        let file = NSMenu(title: "File")
        file.addItem(withTitle: "Rescan", action: #selector(MainViewController.menuRescan), keyEquivalent: "r")
        file.addItem(withTitle: "Export Report…", action: #selector(MainViewController.menuExport), keyEquivalent: "e").keyEquivalentModifierMask = [.command, .shift]
        file.addItem(.separator())
        file.addItem(withTitle: "Add Folder to Never Touch…", action: #selector(MainViewController.menuAddProtected), keyEquivalent: "")
        file.addItem(.separator())
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem()
        fileItem.submenu = file
        main.addItem(fileItem)

        // Edit
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo Last Cleanup", action: #selector(MainViewController.menuUndo), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Select All", action: #selector(MainViewController.menuSelectAll), keyEquivalent: "a")
        let safe = edit.addItem(withTitle: "Select Safe Only", action: #selector(MainViewController.menuSelectSafe), keyEquivalent: "s")
        safe.keyEquivalentModifierMask = [.command, .shift]
        let clear = edit.addItem(withTitle: "Clear Picks", action: #selector(MainViewController.menuClearPicks), keyEquivalent: "d")
        clear.keyEquivalentModifierMask = [.command, .shift]
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)

        // View
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Overview", action: #selector(MainViewController.menuGoOverview), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Clean", action: #selector(MainViewController.menuGoClean), keyEquivalent: "2")
        viewMenu.addItem(withTitle: "Storage Map", action: #selector(MainViewController.menuGoMap), keyEquivalent: "3")
        viewMenu.addItem(withTitle: "Large & Old Files", action: #selector(MainViewController.menuGoLarge), keyEquivalent: "4")
        viewMenu.addItem(withTitle: "Apps", action: #selector(MainViewController.menuGoApps), keyEquivalent: "5")
        viewMenu.addItem(withTitle: "Builders", action: #selector(MainViewController.menuGoBuilders), keyEquivalent: "6")
        viewMenu.addItem(withTitle: "History", action: #selector(MainViewController.menuGoHistory), keyEquivalent: "7")
        viewMenu.addItem(.separator())
        let sbar = viewMenu.addItem(withTitle: "Show or Hide Sidebar", action: #selector(MainViewController.menuToggleSidebar), keyEquivalent: "s")
        sbar.keyEquivalentModifierMask = [.command, .option]
        let insp = viewMenu.addItem(withTitle: "Show or Hide Inspector", action: #selector(MainViewController.menuToggleInspector), keyEquivalent: "i")
        insp.keyEquivalentModifierMask = [.command, .option]
        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        // Window
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        // Help
        let help = NSMenu(title: "Help")
        help.addItem(withTitle: "iClearer Help", action: #selector(MainViewController.menuHelp), keyEquivalent: "")
        help.addItem(withTitle: "Cleanup Rules…", action: #selector(MainViewController.menuRules), keyEquivalent: "")
        help.addItem(withTitle: "Keyboard Shortcuts", action: #selector(MainViewController.menuKeys), keyEquivalent: "")
        let helpItem = NSMenuItem()
        helpItem.submenu = help
        main.addItem(helpItem)

        NSApp.mainMenu = main
    }
}
