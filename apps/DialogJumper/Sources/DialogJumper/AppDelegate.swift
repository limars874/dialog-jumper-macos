import AppKit
import ApplicationServices
import DialogJumperCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trustReader: any AccessibilityTrustReading
    private let fileDialogDetector: any FileDialogDetecting
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var jumpCapabilityMenuItem: NSMenuItem!
    private var fileDialogMenuItem: NSMenuItem!
    private var authorization: AccessibilityAuthorization = .paused
    private var detectionState: FileDialogDetectionState = .accessibilityPaused
    private var pollTimer: Timer?

    init(
        trustReader: any AccessibilityTrustReading,
        fileDialogDetector: any FileDialogDetecting = FileDialogDetector()
    ) {
        self.trustReader = trustReader
        self.fileDialogDetector = fileDialogDetector
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        refreshFromSystem()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromSystem()
            }
        }
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
        applyToUI()
    }

    private func applyToUI() {
        statusItem.button?.title = menuBarGlyph()
        statusMenuItem.title = AccessibilityGate.statusTitle(authorization)

        if AccessibilityGate.isFolderJumpEnabled(authorization) {
            jumpCapabilityMenuItem.title = "Folder Jump: available (features land in later tickets)"
        } else {
            jumpCapabilityMenuItem.title = "Folder Jump: paused until Accessibility is enabled"
        }

        fileDialogMenuItem.title = detectionState.menuTitle
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
        MVP — tickets 01–02.

        Folder Jump needs Accessibility only.
        File Dialog detection uses system Open/Save panel service + AX fingerprint.
        This build does not request Input Monitoring, Automation, or Full Disk Access.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
