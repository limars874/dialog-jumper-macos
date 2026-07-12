import AppKit
import ApplicationServices
import DialogJumperCore

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
        // Menu-bar apps need a real Edit menu or ⌘V/⌘C/⌘X never reach text fields.
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

    /// Standard Edit menu so accessory text fields accept ⌘V / ⌘C / ⌘X / ⌘A.
    private func installMainMenuWithStandardEdit() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit Dialog Jumper",
            action: #selector(quit),
            keyEquivalent: "q"
        )

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
            title: "Jump to Path…",
            action: #selector(jumpToPath),
            keyEquivalent: "j"
        )
        jumpToPathMenuItem.target = self
        menu.addItem(jumpToPathMenuItem)

        menu.addItem(.separator())

        let openSettings = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: "s"
        )
        openSettings.target = self
        menu.addItem(openSettings)

        let recheck = NSMenuItem(
            title: "Recheck Accessibility",
            action: #selector(recheckAccessibility),
            keyEquivalent: "r"
        )
        recheck.target = self
        menu.addItem(recheck)

        menu.addItem(.separator())

        let about = NSMenuItem(
            title: "About Dialog Jumper",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Dialog Jumper",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func refreshFromSystem() {
        let trusted = trustReader.isProcessTrusted()
        authorization = AccessibilityGate.authorization(isProcessTrusted: trusted)
        // Detection only when trusted — never cross-process AX while paused.
        detectionState = fileDialogDetector.detect(authorization: authorization)
        // Ticket 04: attach/detach side Path chrome to eligible dialogs only.
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
            jumpCapabilityMenuItem.title = "Folder Jump: paused until Accessibility is enabled"
        }

        fileDialogMenuItem.title = detectionState.menuTitle
        lastJumpMenuItem.title = lastJumpSummary

        // Path entry: attached toolbar is primary; menu focuses it when eligible.
        if case .eligible = detectionState, jumpReady {
            jumpToPathMenuItem.isEnabled = true
            jumpToPathMenuItem.title = "Focus Path on Toolbar…"
        } else {
            jumpToPathMenuItem.isEnabled = false
            jumpToPathMenuItem.title = "Focus Path… (need eligible File Dialog)"
        }
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
        else {
            presentJumpResult(
                title: "No eligible File Dialog",
                message: "Open a standard Open/Save panel first. Side toolbar attaches automatically when detected."
            )
            return
        }
        // Prefer attached chrome (ticket 04 primary path).
        if let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           PathResolver.looksLikePath(clip) {
            // Prefill is handled when user pastes into toolbar; just focus.
        }
        attachedToolbar.focusPathField()
    }

    /// Shared jump path for attached toolbar (and future entries).
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
            // Keep success non-modal for toolbar flow; status line + menu summary only.
            if source != "toolbar" {
                presentJumpResult(
                    title: "Jump succeeded",
                    message: "Navigated to:\n\(path)\n\nEvidence: \(evidence)\nOpen/Save was not submitted."
                )
            }
        case .failure(let failure):
            lastJumpSummary = "Last jump: failed — \(shortFailure(failure))"
            attachedToolbar.setStatus("Failed · \(shortFailure(failure))")
            applyToUI()
            presentJumpResult(
                title: "Jump did not run",
                message: failure.userMessage
            )
        }
    }

    private func shortPath(_ path: String) -> String {
        if path.count <= 48 { return path }
        return "…" + path.suffix(47)
    }

    private func shortFailure(_ failure: FolderJumpFailure) -> String {
        switch failure {
        case .path(let reason):
            return reason.rawValue
        case .accessibilityPaused:
            return "accessibilityPaused"
        case .noEligibleDialog:
            return "noEligibleDialog"
        case .postEventDenied:
            return "postEventDenied"
        case .goToFolderDidNotOpen:
            return "goToFolderDidNotOpen"
        case .pathFieldNotFound:
            return "pathFieldNotFound"
        case .pathFieldNotWritable:
            return "pathFieldNotWritable"
        case .confirmFailed:
            return "confirmFailed"
        case .verificationFailed:
            return "verificationFailed"
        case .dialogLost:
            return "dialogLost"
        case .actionFailed:
            return "actionFailed"
        }
    }

    private func presentJumpResult(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(AccessibilitySettingsLink.privacyAccessibilityURL)
        refreshFromSystem()
    }

    @objc private func recheckAccessibility() {
        refreshFromSystem()
        if authorization == .paused {
            let alert = NSAlert()
            alert.messageText = "Accessibility still off"
            alert.informativeText =
                "Dialog Jumper will not claim Folder Jump is ready. Enable the app under System Settings → Privacy & Security → Accessibility, then Recheck again."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Settings…")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                openAccessibilitySettings()
            }
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Dialog Jumper"
        alert.informativeText = """
        MVP — tickets 01–03.

        Folder Jump needs Accessibility only.
        Path Input: absolute or ~ ; strict failure (no search).
        Jump: ⇧⌘G → PathTextField → directed click → Return.
        Never submits Open/Save for you.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
