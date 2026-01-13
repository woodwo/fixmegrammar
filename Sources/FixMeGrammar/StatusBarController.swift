import Cocoa

final class StatusBarController {
    private let statusItem: NSStatusItem

    private let onToggleEnabled: (Bool) -> Void
    private let onToggleTranslateToEnglish: (Bool) -> Void
    private let onToggleSkipCode: (Bool) -> Void
    private let onTogglePresentationMode: (Bool) -> Void
    private let onToggleFilterApps: (Bool) -> Void
    private let onFixClipboardNow: () -> Void
    private let onQuit: () -> Void

    private var enabledMenuItem: NSMenuItem!
    private var translateMenuItem: NSMenuItem!
    private var skipCodeMenuItem: NSMenuItem!
    private var presentationMenuItem: NSMenuItem!
    private var filterAppsMenuItem: NSMenuItem!

    init(
        settings: AppSettings,
        onToggleEnabled: @escaping (Bool) -> Void,
        onToggleTranslateToEnglish: @escaping (Bool) -> Void,
        onToggleSkipCode: @escaping (Bool) -> Void,
        onTogglePresentationMode: @escaping (Bool) -> Void,
        onToggleFilterApps: @escaping (Bool) -> Void,
        onFixClipboardNow: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggleEnabled = onToggleEnabled
        self.onToggleTranslateToEnglish = onToggleTranslateToEnglish
        self.onToggleSkipCode = onToggleSkipCode
        self.onTogglePresentationMode = onTogglePresentationMode
        self.onToggleFilterApps = onToggleFilterApps
        self.onFixClipboardNow = onFixClipboardNow
        self.onQuit = onQuit

        print("[StatusBarController] created status item")
        statusItem.button?.title = "📎"
        constructMenu(with: settings)
        print("[StatusBarController] menu constructed")
    }

    private func constructMenu(with settings: AppSettings) {
        let menu = NSMenu()

        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledMenuItem.state = settings.enabled ? .on : .off
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        translateMenuItem = NSMenuItem(title: "Translate to English", action: #selector(toggleTranslate), keyEquivalent: "t")
        translateMenuItem.state = settings.translateToEnglish ? .on : .off
        translateMenuItem.target = self
        menu.addItem(translateMenuItem)

        skipCodeMenuItem = NSMenuItem(title: "Skip Code", action: #selector(toggleSkipCode), keyEquivalent: "s")
        skipCodeMenuItem.state = settings.skipCode ? .on : .off
        skipCodeMenuItem.target = self
        menu.addItem(skipCodeMenuItem)

        presentationMenuItem = NSMenuItem(title: "Presentation Mode", action: #selector(togglePresentationMode), keyEquivalent: "p")
        presentationMenuItem.state = settings.presentationMode ? .on : .off
        presentationMenuItem.target = self
        menu.addItem(presentationMenuItem)

        filterAppsMenuItem = NSMenuItem(title: "Filter Apps", action: #selector(toggleFilterApps), keyEquivalent: "a")
        filterAppsMenuItem.state = settings.filterAppsEnabled ? .on : .off
        filterAppsMenuItem.target = self
        menu.addItem(filterAppsMenuItem)

        menu.addItem(.separator())

        let fixNow = NSMenuItem(title: "Fix Clipboard Now", action: #selector(fixClipboardNow), keyEquivalent: "f")
        fixNow.target = self
        menu.addItem(fixNow)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func flash() {
        let originalTitle = statusItem.button?.title ?? "📎"
        statusItem.button?.title = "✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.statusItem.button?.title = originalTitle
        }
    }

    @objc private func toggleEnabled() {
        enabledMenuItem.state = enabledMenuItem.state == .on ? .off : .on
        onToggleEnabled(enabledMenuItem.state == .on)
    }

    @objc private func toggleTranslate() {
        translateMenuItem.state = translateMenuItem.state == .on ? .off : .on
        onToggleTranslateToEnglish(translateMenuItem.state == .on)
    }

    @objc private func toggleSkipCode() {
        skipCodeMenuItem.state = skipCodeMenuItem.state == .on ? .off : .on
        onToggleSkipCode(skipCodeMenuItem.state == .on)
    }

    @objc private func togglePresentationMode() {
        presentationMenuItem.state = presentationMenuItem.state == .on ? .off : .on
        onTogglePresentationMode(presentationMenuItem.state == .on)
    }

    @objc private func toggleFilterApps() {
        filterAppsMenuItem.state = filterAppsMenuItem.state == .on ? .off : .on
        onToggleFilterApps(filterAppsMenuItem.state == .on)
    }

    @objc private func fixClipboardNow() {
        onFixClipboardNow()
    }

    @objc private func quitApp() {
        onQuit()
    }
}
