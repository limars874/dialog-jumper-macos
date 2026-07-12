import AppKit
import ApplicationServices
import DialogJumperCore

/// Menu-bar shell: Accessibility + File Dialog detection + attached Path toolbar.
///
/// Accessibility UX:
/// - No auto prompt/Settings on launch (avoids double dialogs).
/// - Menu: Request Accessibility… | Open Settings… | Relaunch to Apply
/// - Ad-hoc rebuild changes CDHash: Settings may still show ON for the old binary;
///   this process can still be untrusted until re-grant for the new build.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trustReader: any AccessibilityTrustReading
    private let fileDialogDetector: any FileDialogDetecting
    private let folderJumper: any FolderJumping
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var jumpCapabilityMenuItem: NSMenuItem!
    private var fileDialogMenuItem: NSMenuItem!
    private var jumpToPathMenuItem: NSMenuItem!
    private var lastJumpMenuItem: NSMenuItem!
    private var requestAccessMenuItem: NSMenuItem!
    private var openSettingsMenuItem: NSMenuItem!
    private var relaunchMenuItem: NSMenuItem!
    private var authorization: AccessibilityAuthorization = .paused
    private var detectionState: FileDialogDetectionState = .accessibilityPaused
    private var lastJumpSummary: String = "Last jump: —"
    private var pollTimer: Timer?
    private let attachedToolbar = AttachedPathToolbarController()

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
            self?.performJump(rawPath: raw, source: "toolbar")
        }
        refreshFromSystem()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromSystem()
            }
        }
    }

    /// Prevent double menu-bar icons after a botched relaunch.
    private func terminateOtherInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myBundle = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications {
            let sameBundle = (myBundle != nil && app.bundleIdentifier == myBundle)
            let samePath = app.bundleURL == Bundle.main.bundleURL
            if (sameBundle || samePath), app.processIdentifier != myPID {
                app.terminate()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshFromSystem()
    }

    private func installMainMenuWithStandardEdit() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Dialog Jumper", action: #selector(quit), keyEquivalent: "q")

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.isVisible = true
        statusItem.button?.title = "DJ"
        statusItem.button?.toolTip = "Dialog Jumper"

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        jumpCapabilityMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        jumpCapabilityMenuItem.isEnabled = false
        menu.addItem(jumpCapabilityMenuItem)

        fileDialogMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        fileDialogMenuItem.isEnabled = false
        menu.addItem(fileDialogMenuItem)

        lastJumpMenuItem = NSMenuItem(title: lastJumpSummary, action: nil, keyEquivalent: "")
        lastJumpMenuItem.isEnabled = false
        menu.addItem(lastJumpMenuItem)

        menu.addItem(.separator())

        jumpToPathMenuItem = NSMenuItem(
            title: "Focus Path on Toolbar…",
            action: #selector(jumpToPath),
            keyEquivalent: "j"
        )
        jumpToPathMenuItem.target = self
        menu.addItem(jumpToPathMenuItem)

        menu.addItem(.separator())

        requestAccessMenuItem = NSMenuItem(
            title: "Request Accessibility…",
            action: #selector(requestAccessibility),
            keyEquivalent: ""
        )
        requestAccessMenuItem.target = self
        menu.addItem(requestAccessMenuItem)

        openSettingsMenuItem = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: "s"
        )
        openSettingsMenuItem.target = self
        menu.addItem(openSettingsMenuItem)

        relaunchMenuItem = NSMenuItem(
            title: "Relaunch to Apply Accessibility",
            action: #selector(relaunchApplication),
            keyEquivalent: ""
        )
        relaunchMenuItem.target = self
        menu.addItem(relaunchMenuItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Dialog Jumper", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Dialog Jumper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshFromSystem() {
        let trusted = trustReader.isProcessTrusted()
        authorization = AccessibilityGate.authorization(isProcessTrusted: trusted)
        detectionState = fileDialogDetector.detect(authorization: authorization)
        if AccessibilityGate.isFolderJumpEnabled(authorization) {
            attachedToolbar.sync(to: detectionState)
        } else {
            attachedToolbar.dismiss()
        }
        applyToUI()
    }

    private func applyToUI() {
        statusItem.button?.title = menuBarGlyph()
        statusMenuItem.title = AccessibilityGate.statusTitle(authorization)

        let jumpReady = AccessibilityGate.isFolderJumpEnabled(authorization)
        if jumpReady {
            switch detectionState {
            case .eligible:
                jumpCapabilityMenuItem.title = "Folder Jump: ready (Path)"
            case .none:
                jumpCapabilityMenuItem.title = "Folder Jump: waiting for eligible File Dialog"
            case .accessibilityPaused:
                jumpCapabilityMenuItem.title = "Folder Jump: paused until Accessibility is enabled"
            }
        } else {
            // One Settings row can still be for an older ad-hoc build (CDHash).
            jumpCapabilityMenuItem.title =
                "Paused: Settings ON but this build untrusted → Request again, or remove row & re-add"
        }

        fileDialogMenuItem.title = detectionState.menuTitle
        lastJumpMenuItem.title = lastJumpSummary

        if case .eligible = detectionState, jumpReady {
            jumpToPathMenuItem.isEnabled = true
            jumpToPathMenuItem.title = "Focus Path on Toolbar…"
        } else {
            jumpToPathMenuItem.isEnabled = false
            jumpToPathMenuItem.title = "Focus Path… (need eligible File Dialog)"
        }

        let paused = authorization == .paused
        requestAccessMenuItem.isEnabled = paused
        relaunchMenuItem.isEnabled = paused
        openSettingsMenuItem.isEnabled = true
    }

    private func menuBarGlyph() -> String {
        switch detectionState {
        case .eligible:
            return "DJ●"
        case .accessibilityPaused:
            return AccessibilityGate.shortMenuBarTitle(.paused)
        case .none:
            return AccessibilityGate.shortMenuBarTitle(authorization)
        }
    }

    @objc private func jumpToPath() {
        refreshFromSystem()
        guard case .eligible = detectionState,
              AccessibilityGate.isFolderJumpEnabled(authorization)
        else { return }
        attachedToolbar.focusPathField()
    }

    private func performJump(rawPath: String, source: String) {
        refreshFromSystem()
        let liveDialog: EligibleFileDialog?
        if case .eligible(let current) = detectionState {
            liveDialog = current
        } else {
            liveDialog = nil
        }

        let outcome = folderJumper.jump(
            rawPath: rawPath,
            authorization: authorization,
            dialog: liveDialog
        )

        switch outcome {
        case .success(let path, let evidence):
            lastJumpSummary = "Last jump: ok → \(shortPath(path)) (\(evidence))"
            attachedToolbar.setStatus("Jumped · \(shortPath(path))")
            applyToUI()
            if source != "toolbar" {
                presentAlert(
                    title: "Jump succeeded",
                    message: "Navigated to:\n\(path)\n\nEvidence: \(evidence)\nOpen/Save was not submitted."
                )
            }
        case .failure(let failure):
            lastJumpSummary = "Last jump: failed — \(shortFailure(failure))"
            attachedToolbar.setStatus("Failed · \(shortFailure(failure))")
            applyToUI()
            presentAlert(title: "Jump did not run", message: failure.userMessage)
        }
    }

    private func shortPath(_ path: String) -> String {
        path.count <= 48 ? path : "…" + path.suffix(47)
    }

    private func shortFailure(_ failure: FolderJumpFailure) -> String {
        switch failure {
        case .accessibilityPaused: return "accessibilityPaused"
        case .noEligibleDialog: return "noEligibleDialog"
        case .path: return "path"
        case .postEventDenied: return "postEventDenied"
        case .goToFolderDidNotOpen: return "goToFolderDidNotOpen"
        case .pathFieldNotFound: return "pathFieldNotFound"
        case .pathFieldNotWritable: return "pathFieldNotWritable"
        case .confirmFailed: return "confirmFailed"
        case .verificationFailed: return "verificationFailed"
        case .dialogLost: return "dialogLost"
        case .actionFailed: return "actionFailed"
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// System prompt only — registers this build. Does not open Settings.
    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshFromSystem()
    }

    /// Settings only.
    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(AccessibilitySettingsLink.privacyAccessibilityURL)
        refreshFromSystem()
    }

    @objc private func relaunchApplication() {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            presentAlert(
                title: "Use the app bundle",
                message: "Launch via apps/DialogJumper/scripts/run-dev-app.sh"
            )
            return
        }
        // Quit first, then open — never create a second instance while this one lives.
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
        alert.informativeText = """
        MVP — tickets 01–04.

        Accessibility when DJ!:
        1) Request Accessibility… (registers this build)
        2) Turn the switch ON (or remove stale row, then Request again)
        3) Relaunch to Apply Accessibility

        After code rebuild (ad-hoc sign), Settings may still show ON for the old
        binary while this process stays untrusted — re-grant for the new build.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
