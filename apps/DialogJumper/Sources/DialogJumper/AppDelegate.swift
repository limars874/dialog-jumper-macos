import AppKit
import ApplicationServices
import DialogJumperCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trustReader: any AccessibilityTrustReading
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var jumpCapabilityMenuItem: NSMenuItem!
    private var authorization: AccessibilityAuthorization = .paused
    private var pollTimer: Timer?

    init(trustReader: any AccessibilityTrustReading) {
        self.trustReader = trustReader
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        refreshAuthorizationFromSystem()
        // Poll so returning from System Settings updates without requiring a click.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAuthorizationFromSystem()
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

    private func refreshAuthorizationFromSystem() {
        let trusted = trustReader.isProcessTrusted()
        authorization = AccessibilityGate.authorization(isProcessTrusted: trusted)
        applyAuthorizationToUI()
    }

    private func applyAuthorizationToUI() {
        statusItem.button?.title = AccessibilityGate.shortMenuBarTitle(authorization)
        statusMenuItem.title = AccessibilityGate.statusTitle(authorization)

        if AccessibilityGate.isFolderJumpEnabled(authorization) {
            jumpCapabilityMenuItem.title = "Folder Jump: available (features land in later tickets)"
        } else {
            jumpCapabilityMenuItem.title = "Folder Jump: paused until Accessibility is enabled"
        }
    }

    @objc private func openAccessibilitySettings() {
        // Optional system prompt; async — never treat return value as granted.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(AccessibilitySettingsLink.privacyAccessibilityURL)
        // Stay honest until recheck sees trusted=true.
        refreshAuthorizationFromSystem()
    }

    @objc private func recheckAccessibility() {
        refreshAuthorizationFromSystem()
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
        MVP shell — ticket 01.

        Folder Jump needs Accessibility only.
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
