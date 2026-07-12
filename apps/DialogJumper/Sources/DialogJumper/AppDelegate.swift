import AppKit
import ApplicationServices
import DialogJumperCore

/// Intentionally NOT @MainActor on the class — AppKit delegate callbacks must run reliably.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let trustReader: any AccessibilityTrustReading
    private let fileDialogDetector: any FileDialogDetecting
    private let folderJumper: any FolderJumping

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private var authorization: AccessibilityAuthorization = .paused
    private var detectionState: FileDialogDetectionState = .accessibilityPaused
    private var lastJumpSummary = "Last jump: —"
    private var pollTimer: Timer?
    private let attachedToolbar = AttachedPathToolbarController()

    private enum MenuIndex {
        static let accessibility = 0
        static let folderJump = 1
        static let fileDialog = 2
        static let lastJump = 3
        // 4 separator
        static let focusPath = 5
        // 6 separator
        static let requestAccess = 7
        static let openSettings = 8
        static let relaunch = 9
    }

    init(
        trustReader: any AccessibilityTrustReading,
        fileDialogDetector: any FileDialogDetecting = FileDialogDetector(),
        folderJumper: any FolderJumping = FolderJumpExecutor()
    ) {
        self.trustReader = trustReader
        self.fileDialogDetector = fileDialogDetector
        self.folderJumper = folderJumper
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
        NSLog("[DialogJumper] launched, initial auth refresh done")
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
        menu.addItem(disabled("File Dialog: starting…"))
        menu.addItem(disabled(lastJumpSummary))
        menu.addItem(.separator())

        let focus = NSMenuItem(title: "Focus Path on Toolbar…", action: #selector(jumpToPath), keyEquivalent: "j")
        focus.target = self
        menu.addItem(focus)
        menu.addItem(.separator())

        let request = NSMenuItem(title: "Request Accessibility…", action: #selector(requestAccessibility), keyEquivalent: "")
        request.target = self
        menu.addItem(request)

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
        authorization = AccessibilityGate.authorization(isProcessTrusted: trusted)
        detectionState = fileDialogDetector.detect(authorization: authorization)

        // Update menu text first so UI never stays on placeholders if toolbar sync is slow.
        applyToUI()

        if AccessibilityGate.isFolderJumpEnabled(authorization) {
            let showChrome = shouldShowAttachedChrome(for: detectionState)
            attachedToolbar.sync(to: detectionState, showChrome: showChrome)
        } else {
            attachedToolbar.dismiss()
        }

        NSLog(
            "[DialogJumper] trusted=%@ detect=%@ panels=%ld",
            trusted ? "YES" : "NO",
            detectionState.menuTitle as NSString,
            NSWorkspace.shared.runningApplications.filter {
                FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: $0.bundleIdentifier)
            }.count
        )
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
            NSLog("[DialogJumper] applyToUI: no menu")
            return
        }

        statusItem.button?.title = menuBarGlyph()

        menu.item(at: MenuIndex.accessibility)?.title = AccessibilityGate.statusTitle(authorization)

        let jumpReady = AccessibilityGate.isFolderJumpEnabled(authorization)
        let panelApps = NSWorkspace.shared.runningApplications.filter {
            FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: $0.bundleIdentifier)
        }
        let panelCount = panelApps.count
        let panelNames = panelApps.compactMap(\.localizedName).joined(separator: ", ")

        if !jumpReady {
            menu.item(at: MenuIndex.folderJump)?.title = "Folder Jump: paused (Accessibility)"
        } else if case .eligible = detectionState {
            menu.item(at: MenuIndex.folderJump)?.title = "Folder Jump: ready (Path)"
        } else {
            var waiting = "Folder Jump: waiting — panelServices=\(panelCount)"
            if !panelNames.isEmpty { waiting += " {\(panelNames)}" }
            menu.item(at: MenuIndex.folderJump)?.title = waiting
        }

        menu.item(at: MenuIndex.fileDialog)?.title = detectionState.menuTitle
        menu.item(at: MenuIndex.lastJump)?.title = lastJumpSummary

        let canJump: Bool = {
            guard jumpReady else { return false }
            if case .eligible = detectionState { return true }
            return false
        }()
        if let focus = menu.item(at: MenuIndex.focusPath) {
            focus.isEnabled = canJump
            focus.title = canJump ? "Focus Path on Toolbar…" : "Focus Path… (need eligible File Dialog)"
        }
        menu.item(at: MenuIndex.requestAccess)?.isEnabled = !jumpReady
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
        guard case .eligible = detectionState, authorization == .ready else { return }
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
        case .success(let path, let evidence):
            lastJumpSummary = "Last jump: ok → \(shortPath(path)) (\(evidence))"
            attachedToolbar.setStatus("Jumped · \(shortPath(path))")
            applyToUI()
        case .failure(let failure):
            lastJumpSummary = "Last jump: failed"
            attachedToolbar.setStatus("Failed")
            applyToUI()
            let alert = NSAlert()
            alert.messageText = "Jump did not run"
            alert.informativeText = failure.userMessage
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func shortPath(_ path: String) -> String {
        path.count <= 48 ? path : "…" + path.suffix(47)
    }

    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshFromSystem()
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
        alert.informativeText = "Status is the top grey lines of this menu."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
