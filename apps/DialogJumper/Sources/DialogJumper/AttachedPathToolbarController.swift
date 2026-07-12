import AppKit
import DialogJumperCore

final class AttachedPathToolbarController: NSObject, NSTextFieldDelegate {
    /// Path field / recent click → raw path string for Folder Jump.
    var onJump: ((String) -> Void)?
    /// Unavailable recent click → explanation only (no jump).
    var onUnavailableRecent: ((String) -> Void)?

    private var panel: NSPanel?
    private var pathField: NSTextField?
    private var statusLabel: NSTextField?
    private var recentsHeaderLabel: NSTextField?
    private var recentsScroll: NSScrollView?
    private var recentsDocument: NSView?
    private var emptyRecentsLabel: NSTextField?
    private var attachedPID: pid_t?
    private var recentEntries: [RecentFolderEntry] = []

    private let chromeSize = CGSize(width: 300, height: 360)
    private let rowHeight: CGFloat = 40

    func sync(to detection: FileDialogDetectionState, showChrome: Bool = true) {
        guard case .eligible(let dialog) = detection else {
            dismiss()
            return
        }
        guard showChrome else {
            hideChromePreservingState()
            return
        }
        guard let frame = FileDialogGeometry.frame(forPanelPID: dialog.panelPID) else {
            hideChromePreservingState()
            return
        }
        showOrUpdate(dialog: dialog, frame: frame)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel?.alphaValue = 0
        attachedPID = nil
    }

    private func hideChromePreservingState() {
        panel?.orderOut(nil)
        panel?.alphaValue = 0
    }

    func setStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    /// Refresh Recents rows (call after successful jump / on show).
    func setRecents(_ entries: [RecentFolderEntry]) {
        recentEntries = entries
        rebuildRecentsRows()
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
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(pathField)
        pathField.currentEditor()?.selectAll(nil)
    }

    private func showOrUpdate(dialog: EligibleFileDialog, frame: FileDialogFrame) {
        let panel = ensurePanel()
        let isNewAttachment = attachedPID != dialog.panelPID
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
        let attachedLine = "Attached · \(kind) · \(host)"
        // 新附着或仍是默认文案时更新；Jump 成功/失败状态行不冲掉
        if isNewAttachment {
            statusLabel?.stringValue = attachedLine
        } else if let s = statusLabel?.stringValue, s.hasPrefix("Attached") || s.isEmpty {
            statusLabel?.stringValue = attachedLine
        }

        panel.alphaValue = 1
        panel.orderFront(nil)
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true

        let root = NSView(frame: NSRect(origin: .zero, size: chromeSize))
        panel.contentView = root

        let w = chromeSize.width
        let h = chromeSize.height

        let title = makeLabel("Path + Recents", bold: true, size: 12)
        title.frame = NSRect(x: 12, y: h - 28, width: w - 24, height: 18)

        let status = makeLabel("Attached", bold: false, size: 10)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 12, y: h - 44, width: w - 24, height: 14)
        statusLabel = status

        let field = NSTextField(frame: NSRect(x: 12, y: h - 76, width: w - 24, height: 24))
        field.placeholderString = "Paste path…  / or ~"
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = self
        field.target = self
        field.action = #selector(jumpFromField)
        pathField = field

        let jump = NSButton(frame: NSRect(x: 12, y: h - 112, width: 90, height: 28))
        jump.title = "Jump"
        jump.bezelStyle = .rounded
        jump.target = self
        jump.action = #selector(jumpFromField)

        let hint = makeLabel("Return · never auto Open/Save", bold: false, size: 9)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 110, y: h - 108, width: w - 122, height: 20)

        let recentsHeader = makeLabel("Recents", bold: true, size: 11)
        recentsHeader.frame = NSRect(x: 12, y: h - 140, width: w - 24, height: 16)
        recentsHeaderLabel = recentsHeader

        let empty = makeLabel("Jump once to fill Recents", bold: false, size: 10)
        empty.textColor = .tertiaryLabelColor
        empty.frame = NSRect(x: 12, y: h - 168, width: w - 24, height: 16)
        emptyRecentsLabel = empty

        let document = NSView(frame: NSRect(x: 0, y: 0, width: w - 16, height: 1))
        recentsDocument = document

        let scroll = NSScrollView(frame: NSRect(x: 8, y: 12, width: w - 16, height: h - 156))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = document
        recentsScroll = scroll

        root.addSubview(title)
        root.addSubview(status)
        root.addSubview(field)
        root.addSubview(jump)
        root.addSubview(hint)
        root.addSubview(recentsHeader)
        root.addSubview(empty)
        root.addSubview(scroll)

        self.panel = panel
        rebuildRecentsRows()
        return panel
    }

    private func rebuildRecentsRows() {
        guard let document = recentsDocument, let scroll = recentsScroll else { return }
        document.subviews.forEach { $0.removeFromSuperview() }

        let empty = recentEntries.isEmpty
        emptyRecentsLabel?.isHidden = !empty
        scroll.isHidden = empty
        recentsHeaderLabel?.stringValue = empty
            ? "Recents"
            : "Recents (\(recentEntries.count))"

        guard !empty else {
            document.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 1)
            return
        }

        let rowWidth = max(scroll.contentSize.width, chromeSize.width - 16)
        let totalHeight = CGFloat(recentEntries.count) * rowHeight
        // Cocoa scroll document: origin at bottom-left；行自上而下排布
        document.frame = NSRect(x: 0, y: 0, width: rowWidth, height: max(totalHeight, scroll.contentSize.height))

        for (index, entry) in recentEntries.enumerated() {
            let yFromTop = CGFloat(index) * rowHeight
            let y = document.frame.height - yFromTop - rowHeight
            let row = makeRecentRow(entry: entry, index: index, width: rowWidth)
            row.frame = NSRect(x: 0, y: y, width: rowWidth, height: rowHeight)
            document.addSubview(row)
        }

        if totalHeight > scroll.contentSize.height {
            document.scroll(NSPoint(x: 0, y: document.frame.height))
        }
    }

    private func makeRecentRow(entry: RecentFolderEntry, index: Int, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))

        let titleText = entry.isAvailable
            ? entry.displayName
            : "\(entry.displayName) · unavailable"
        let title = makeLabel(titleText, bold: true, size: 11)
        title.textColor = entry.isAvailable ? .labelColor : .secondaryLabelColor
        title.frame = NSRect(x: 6, y: 18, width: width - 12, height: 16)
        title.lineBreakMode = .byTruncatingTail

        let subtitle = makeLabel(entry.path, bold: false, size: 9)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.frame = NSRect(x: 6, y: 2, width: width - 12, height: 14)
        subtitle.lineBreakMode = .byTruncatingMiddle

        let button = NSButton(frame: container.bounds)
        button.title = ""
        button.bezelStyle = .inline
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.tag = index
        button.target = self
        button.action = #selector(recentClicked(_:))
        button.autoresizingMask = [.width, .height]

        container.addSubview(button)
        container.addSubview(title)
        container.addSubview(subtitle)
        return container
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
        onJump?(pathField?.stringValue ?? "")
    }

    @objc private func recentClicked(_ sender: NSButton) {
        let index = sender.tag
        guard recentEntries.indices.contains(index) else { return }
        let entry = recentEntries[index]
        if entry.isAvailable {
            // 回填 path 字段，便于用户看到目标
            pathField?.stringValue = entry.path
            onJump?(entry.path)
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable · \(entry.displayName)")
            onUnavailableRecent?(reason)
        }
    }
}
