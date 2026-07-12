import AppKit
import DialogJumperCore

/// Floating side chrome attached to an eligible File Dialog (Path only for ticket 04).
final class AttachedPathToolbarController: NSObject, NSTextFieldDelegate {
    var onJump: ((String) -> Void)?

    private var panel: NSPanel?
    private var pathField: NSTextField?
    private var statusLabel: NSTextField?
    private var attachedPID: pid_t?
    private let chromeSize = CGSize(width: 280, height: 132)

    /// - Parameters:
    ///   - detection: current File Dialog detection
    ///   - showChrome: false when dialog exists but host is not frontmost (hide, don't destroy state)
    func sync(to detection: FileDialogDetectionState, showChrome: Bool = true) {
        guard case .eligible(let dialog) = detection, showChrome else {
            // Hide only — path text can remain for when user returns to the dialog.
            panel?.orderOut(nil)
            if case .eligible = detection {
                // keep attachedPID for continuity
            } else {
                attachedPID = nil
            }
            return
        }
        guard let frame = FileDialogGeometry.frame(forPanelPID: dialog.panelPID) else {
            panel?.orderOut(nil)
            return
        }
        showOrUpdate(dialog: dialog, frame: frame)
    }

    func dismiss() {
        panel?.orderOut(nil)
        attachedPID = nil
    }

    func setStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    func focusPathField() {
        guard let panel, let pathField else { return }
        if let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           PathResolver.looksLikePath(clip),
           pathField.stringValue.isEmpty {
            pathField.stringValue = clip
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(pathField)
        pathField.currentEditor()?.selectAll(nil)
    }

    private func showOrUpdate(dialog: EligibleFileDialog, frame: FileDialogFrame) {
        let panel = ensurePanel()
        attachedPID = dialog.panelPID

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame.cocoaRect) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? frame.cocoaRect
        let origin = FileDialogGeometry.sideChromeOrigin(
            dialog: frame.cocoaRect,
            chromeSize: chromeSize,
            screen: screen
        )
        panel.setFrame(CGRect(origin: origin, size: chromeSize), display: true)

        let host = dialog.hostName ?? "File Dialog"
        let kind = dialog.panelKind?.rawValue ?? "panel"
        statusLabel?.stringValue = "Attached · \(kind) · \(host)"

        if !panel.isVisible {
            panel.orderFront(nil)
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: chromeSize),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Dialog Jumper"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // canJoinAllSpaces and moveToActiveSpace are mutually exclusive — combining them throws and breaks the status menu.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true

        let root = NSView(frame: NSRect(origin: .zero, size: chromeSize))
        panel.contentView = root

        let title = makeLabel("Path Jump", bold: true, size: 12)
        title.frame = NSRect(x: 12, y: chromeSize.height - 28, width: 200, height: 18)

        let status = makeLabel("Attached", bold: false, size: 10)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 12, y: chromeSize.height - 44, width: chromeSize.width - 24, height: 14)
        statusLabel = status

        let field = NSTextField(frame: NSRect(x: 12, y: 48, width: chromeSize.width - 24, height: 24))
        field.placeholderString = "Paste path…  / or ~"
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = self
        field.target = self
        field.action = #selector(jumpFromField)
        pathField = field

        let jump = NSButton(frame: NSRect(x: 12, y: 12, width: 90, height: 28))
        jump.title = "Jump"
        jump.bezelStyle = .rounded
        jump.target = self
        jump.action = #selector(jumpFromField)

        let hint = makeLabel("Return or Jump · never auto Open/Save", bold: false, size: 9)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 110, y: 16, width: chromeSize.width - 122, height: 20)

        root.addSubview(title)
        root.addSubview(status)
        root.addSubview(field)
        root.addSubview(jump)
        root.addSubview(hint)

        self.panel = panel
        return panel
    }

    private func makeLabel(_ text: String, bold: Bool, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold
            ? .systemFont(ofSize: size, weight: .semibold)
            : .systemFont(ofSize: size)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        return label
    }

    @objc private func jumpFromField() {
        let raw = pathField?.stringValue ?? ""
        onJump?(raw)
    }
}
