import AppKit
import ApplicationServices
import DialogJumperCore

/// Intentionally NOT @MainActor on the class — AppKit delegate callbacks must run reliably.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let trustReader: any AccessibilityTrustReading
    private let fileDialogDetector: any FileDialogDetecting
    private let folderJumper: any FolderJumping
    private let recents: RecentsRepository
    private let favorites: FavoritesRepository

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var authorization: AccessibilityAuthorization = .paused
    /// Once true, a later pause is presented as mid-session revoke until ready again.
    private var accessibilityHadBeenReady = false
    private var detectionState: FileDialogDetectionState = .accessibilityPaused
    private var lastJumpSummary = "Last jump: —"
    private var pollTimer: Timer?
    private var chromeWasShown = false
    private let attachedToolbar = AttachedPathToolbarController()

    private enum MenuIndex {
        static let accessibility = 0
        static let folderJump = 1
        static let lastJump = 2
        // 3 separator
        static let focusPath = 4
        // 5 separator
        static let recheckAccess = 6
        static let openSettings = 7
        static let relaunch = 8
    }

    init(
        trustReader: any AccessibilityTrustReading,
        fileDialogDetector: any FileDialogDetecting = FileDialogDetector(),
        folderJumper: any FolderJumping = FolderJumpExecutor(),
        recents: RecentsRepository = RecentsRepository(),
        favorites: FavoritesRepository = FavoritesRepository()
    ) {
        self.trustReader = trustReader
        self.fileDialogDetector = fileDialogDetector
        self.folderJumper = folderJumper
        self.recents = recents
        self.favorites = favorites
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateOtherInstances()
        installMainMenuWithStandardEdit()
        configureStatusItem()
        attachedToolbar.onJump = { [weak self] raw in
            self?.performJump(rawPath: raw)
        }
        attachedToolbar.onUnavailableRecent = { [weak self] reason in
            self?.explainUnavailableRecent(reason)
        }
        attachedToolbar.onUnavailableFavorite = { [weak self] reason in
            self?.explainUnavailableFavorite(reason)
        }
        attachedToolbar.onAddFavoriteFromPath = { [weak self] raw in
            self?.addFavorite(rawPath: raw)
        }
        attachedToolbar.onRemoveFavorite = { [weak self] path in
            self?.removeFavorite(path: path)
        }
        attachedToolbar.onMoveFavoriteUp = { [weak self] path in
            self?.moveFavoriteUp(path: path)
        }
        attachedToolbar.onMoveFavoriteDown = { [weak self] path in
            self?.moveFavoriteDown(path: path)
        }
        refreshListChrome()
        // Hide/show chrome as soon as the user switches apps (don't wait for poll).
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        refreshFromSystem()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshFromSystem()
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
#if DEBUG
        NSLog("[DialogJumper] launched, initial auth refresh done")
#endif
    }

    @objc private func frontAppChanged(_ note: Notification) {
        refreshFromSystem()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshFromSystem()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshFromSystem()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshFromSystem()
    }

    private func terminateOtherInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myBundle = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications {
            let sameBundle = myBundle != nil && app.bundleIdentifier == myBundle
            let samePath = app.bundleURL == Bundle.main.bundleURL
            if (sameBundle || samePath), app.processIdentifier != myPID {
                app.terminate()
            }
        }
    }

    private func installMainMenuWithStandardEdit() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Dialog Jumper", action: #selector(quit), keyEquivalent: "q")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.button?.title = "DJ"

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        menu.addItem(disabled("Accessibility: starting…"))
        menu.addItem(disabled("Folder Jump: starting…"))
        menu.addItem(disabled(lastJumpSummary))
        menu.addItem(.separator())

        let focus = NSMenuItem(title: "Focus Path on Toolbar…", action: #selector(jumpToPath), keyEquivalent: "j")
        focus.target = self
        menu.addItem(focus)
        menu.addItem(.separator())

        let recheck = NSMenuItem(title: "Recheck Accessibility", action: #selector(recheckAccessibility), keyEquivalent: "r")
        recheck.target = self
        menu.addItem(recheck)

        let settings = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "s")
        settings.target = self
        menu.addItem(settings)

        let relaunch = NSMenuItem(title: "Relaunch to Apply Accessibility", action: #selector(relaunchApplication), keyEquivalent: "")
        relaunch.target = self
        menu.addItem(relaunch)
        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Dialog Jumper", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Dialog Jumper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusMenu = menu
        statusItem.menu = menu
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func refreshFromSystem() {
        let trusted = trustReader.isProcessTrusted()
        let previous = authorization
        let transition = AccessibilityGate.applyTrustChange(
            previous: previous,
            isProcessTrusted: trusted,
            hadBeenReady: accessibilityHadBeenReady
        )
        authorization = transition.authorization
        accessibilityHadBeenReady = transition.hadBeenReady
        detectionState = fileDialogDetector.detect(authorization: authorization)

        // Update menu text first so UI never stays on placeholders if toolbar sync is slow.
        applyToUI()

        if AccessibilityGate.isFolderJumpEnabled(authorization) {
            let showChrome = shouldShowAttachedChrome(for: detectionState)
            if showChrome {
                // 仅在 chrome 从隐藏→显示时刷新列表，避免 0.5s 轮询重建行
                if !chromeWasShown {
                    refreshListChrome()
                }
                chromeWasShown = true
            } else {
                chromeWasShown = false
            }
            attachedToolbar.sync(to: detectionState, showChrome: showChrome)
        } else {
            // paused / revoked：拆除依赖 AX 的 chrome，绝不附着
            chromeWasShown = false
            attachedToolbar.dismiss()
        }

        if transition.justRevoked {
            // 一次性提示：ready→paused 边沿，不在 0.5s 轮询里重复弹
            notifyAccessibilityRevokedOnce()
        }

#if DEBUG
        NSLog(
            "[DialogJumper] trusted=%@ revokedPresent=%@ detect=%@",
            trusted ? "YES" : "NO",
            transition.isRevokedPresentation ? "YES" : "NO",
            detectionState.menuTitle as NSString
        )
#endif
    }

    /// Show floating chrome only while the File Dialog's host (or panel service) is frontmost.
    /// Switching to another app hides chrome; Cancel/close removes eligibility entirely.
    private func shouldShowAttachedChrome(for detection: FileDialogDetectionState) -> Bool {
        guard case .eligible(let dialog) = detection else { return false }
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }

        // Typing in our toolbar makes Dialog Jumper frontmost — keep chrome visible.
        if front.bundleIdentifier == Bundle.main.bundleIdentifier { return true }
        if front.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }

        // Panel service itself is key.
        if front.processIdentifier == dialog.panelPID { return true }
        if FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: front.bundleIdentifier) {
            return true
        }
        // Host app (e.g. TextEdit) is frontmost.
        if let hostBundle = dialog.hostBundleIdentifier,
           front.bundleIdentifier == hostBundle {
            return true
        }
        if let hostName = dialog.hostName?.lowercased(),
           let frontName = front.localizedName?.lowercased(),
           frontName == hostName {
            return true
        }
        return false
    }

    private func applyToUI() {
        guard let menu = statusMenu ?? statusItem.menu else {
#if DEBUG
            NSLog("[DialogJumper] applyToUI: no menu")
#endif
            return
        }

        let revoked = authorization == .paused && accessibilityHadBeenReady
        statusItem.button?.title = menuBarGlyph()

        menu.item(at: MenuIndex.accessibility)?.title =
            AccessibilityGate.statusTitle(authorization, revoked: revoked)

        let jumpReady = AccessibilityGate.isFolderJumpEnabled(authorization)
        let hasEligible: Bool = {
            if case .eligible = detectionState { return true }
            return false
        }()
        let hostSummary: String? = {
            guard case .eligible(let dialog) = detectionState else { return nil }
            var parts: [String] = []
            if let host = dialog.hostName, !host.isEmpty { parts.append(host) }
            if let kind = dialog.panelKind {
                switch kind {
                case .open: parts.append("Open")
                case .save: parts.append("Save")
                case .unknown: break
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()

        menu.item(at: MenuIndex.folderJump)?.title = AccessibilityGate.folderJumpMenuTitle(
            authorization: authorization,
            revoked: revoked,
            hasEligibleDialog: hasEligible,
            hostSummary: hostSummary
        )
        menu.item(at: MenuIndex.lastJump)?.title = lastJumpSummary

        let canJump = jumpReady && hasEligible
        if let focus = menu.item(at: MenuIndex.focusPath) {
            focus.isEnabled = true
            if canJump {
                focus.title = "Focus Path on Toolbar…"
            } else if !jumpReady {
                focus.title = revoked
                    ? "Focus Path… (Accessibility revoked)"
                    : "Focus Path… (need Accessibility)"
            } else {
                focus.title = "Focus Path… (no File Dialog)"
            }
        }

        menu.item(at: MenuIndex.recheckAccess)?.isEnabled = true
        menu.item(at: MenuIndex.relaunch)?.isEnabled = !jumpReady
    }

    private func menuBarGlyph() -> String {
        switch detectionState {
        case .eligible: return "DJ●"
        case .accessibilityPaused: return "DJ!"
        case .none: return authorization == .ready ? "DJ" : "DJ!"
        }
    }

    @objc private func jumpToPath() {
        refreshFromSystem()
        if authorization != .ready {
            presentJumpFailure(.accessibilityPaused)
            return
        }
        guard case .eligible = detectionState else {
            presentJumpFailure(.noEligibleDialog)
            return
        }
        attachedToolbar.focusPathField()
    }

    private func performJump(rawPath: String) {
        refreshFromSystem()
        let dialog: EligibleFileDialog?
        if case .eligible(let current) = detectionState {
            dialog = current
        } else {
            dialog = nil
        }
        switch folderJumper.jump(rawPath: rawPath, authorization: authorization, dialog: dialog) {
        case .success(let path, _):
            lastJumpSummary = "Last jump: ok · \(shortPath(path))"
            // 成功 Jump 写入 Recents（Open/Save 落点观察未接，避免假写入）
            recents.record(url: URL(fileURLWithPath: path, isDirectory: true))
            refreshListChrome()
            attachedToolbar.setStatus("Jumped")
            applyToUI()
        case .failure(let failure):
            presentJumpFailure(failure)
        }
    }

    /// Soft failures: menu + toolbar status only. Accessibility hard recovery may alert.
    private func presentJumpFailure(_ failure: FolderJumpFailure) {
        lastJumpSummary = "Last jump: failed · \(shortMessage(failure.userMessage))"
        attachedToolbar.setStatus(failure.toolbarStatus)
        applyToUI()

        guard failure == .accessibilityPaused else { return }

        let alert = NSAlert()
        alert.messageText = failure.alertTitle
        alert.informativeText = failure.userMessage
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Accessibility Settings…")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func notifyAccessibilityRevokedOnce() {
        lastJumpSummary = "Last jump: — (Accessibility revoked)"
        applyToUI()
        let alert = NSAlert()
        alert.messageText = "Accessibility revoked"
        alert.informativeText = AccessibilityGate.revokeAlertMessage()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Accessibility Settings…")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func shortMessage(_ text: String, limit: Int = 72) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit - 1)) + "…"
    }

    private func explainUnavailableRecent(_ reason: String) {
        attachedToolbar.setStatus("Unavailable · \(shortMessage(reason, limit: 40))")
        lastJumpSummary = "Last jump: — · recent unavailable"
        applyToUI()
    }

    private func explainUnavailableFavorite(_ reason: String) {
        attachedToolbar.setStatus("Unavailable · \(shortMessage(reason, limit: 40))")
        lastJumpSummary = "Last jump: — · favorite unavailable"
        applyToUI()
    }

    private func refreshListChrome() {
        attachedToolbar.setRecents(recents.list())
        attachedToolbar.setFavorites(favorites.list())
    }

    private func addFavorite(rawPath: String) {
        switch favorites.add(rawPath: rawPath) {
        case .added:
            refreshListChrome()
            attachedToolbar.setStatus("Favorited")
        case .alreadyPresent:
            attachedToolbar.setStatus("Already in Favorites")
        case .atCapacity:
            attachedToolbar.setStatus("Favorites full (max \(FavoritesRepository.capacity))")
        case .invalid(let reason):
            attachedToolbar.setStatus(reason.userMessage)
        }
    }

    private func removeFavorite(path: String) {
        favorites.remove(path: path)
        refreshListChrome()
        attachedToolbar.setStatus("Removed favorite")
    }

    private func moveFavoriteUp(path: String) {
        favorites.moveUp(path: path)
        refreshListChrome()
    }

    private func moveFavoriteDown(path: String) {
        favorites.moveDown(path: path)
        refreshListChrome()
    }

    private func shortPath(_ path: String) -> String {
        path.count <= 48 ? path : "…" + path.suffix(47)
    }

    @objc private func requestAccessibility() {
        // User-initiated only — never loop this from the poll timer.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshFromSystem()
    }

    /// Re-read trust only. Never presents the system prompt (no storm).
    @objc private func recheckAccessibility() {
        refreshFromSystem()
        let revoked = authorization == .paused && accessibilityHadBeenReady
        let title = AccessibilityGate.statusTitle(authorization, revoked: revoked)
        lastJumpSummary = authorization == .ready
            ? "Last recheck: Accessibility ready"
            : "Last recheck: \(title)"
        applyToUI()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(AccessibilitySettingsLink.privacyAccessibilityURL)
        refreshFromSystem()
    }

    @objc private func relaunchApplication() {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else { return }
        let path = appURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.4; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Dialog Jumper"
        alert.informativeText =
            "Jump folders inside standard macOS Open & Save dialogs.\n"
            + "Path · Recents · Favorites — never clicks Open/Save for you."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
