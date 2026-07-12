import AppKit
import DialogJumperCore

final class AttachedPathToolbarController: NSObject, NSTextFieldDelegate {
    /// Path field / list click → raw path string for Folder Jump.
    var onJump: ((String) -> Void)?
    /// Unavailable recent click → explanation only (no jump).
    var onUnavailableRecent: ((String) -> Void)?
    /// Unavailable favorite click → explanation only (no jump).
    var onUnavailableFavorite: ((String) -> Void)?
    /// Explicit add from Path field.
    var onAddFavoriteFromPath: ((String) -> Void)?
    /// Remove / reorder favorites by path.
    var onRemoveFavorite: ((String) -> Void)?
    var onMoveFavoriteUp: ((String) -> Void)?
    var onMoveFavoriteDown: ((String) -> Void)?

    private var panel: NSPanel?
    private var pathField: NSTextField?
    private var statusLabel: NSTextField?
    private var recentsHeaderLabel: NSTextField?
    private var favoritesHeaderLabel: NSTextField?
    private var recentsScroll: NSScrollView?
    private var favoritesScroll: NSScrollView?
    private var recentsDocument: NSView?
    private var favoritesDocument: NSView?
    private var emptyRecentsLabel: NSTextField?
    private var emptyFavoritesLabel: NSTextField?
    private var addFavoriteButton: NSButton?
    private var attachedPID: pid_t?
    private var recentEntries: [RecentFolderEntry] = []
    private var favoriteEntries: [FavoriteFolderEntry] = []

    private let chromeSize = CGSize(width: 300, height: 460)
    private let rowHeight: CGFloat = 44
    private let favoriteManageWidth: CGFloat = 54

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

    /// Refresh Favorites rows (call after manage / on show).
    func setFavorites(_ entries: [FavoriteFolderEntry]) {
        favoriteEntries = entries
        rebuildFavoritesRows()
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

        // 顶区：短状态 + Path + 按钮（无内容总标题，窗标题 Dialog Jumper 已够）
        let status = makeLabel("", bold: false, size: 10)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 12, y: h - 22, width: w - 24, height: 14)
        statusLabel = status

        let field = NSTextField(frame: NSRect(x: 12, y: h - 52, width: w - 24, height: 24))
        field.placeholderString = "Paste path…  / or ~"
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = self
        field.target = self
        field.action = #selector(jumpFromField)
        pathField = field

        let jump = NSButton(frame: NSRect(x: 12, y: h - 88, width: 72, height: 28))
        jump.title = "Jump"
        jump.bezelStyle = .rounded
        jump.target = self
        jump.action = #selector(jumpFromField)

        let add = NSButton(frame: NSRect(x: 90, y: h - 88, width: 108, height: 28))
        add.title = "★ Favorite"
        add.bezelStyle = .rounded
        add.target = self
        add.action = #selector(addFavoriteFromField)
        add.toolTip = "Add path field folder to Favorites"
        addFavoriteButton = add

        // 列表区：Recents 上半、Favorites 下半（固定分区，避免抢高度）
        let listTop = h - 112
        let listBottom: CGFloat = 12
        let listHeight = listTop - listBottom
        let half = floor(listHeight / 2)
        let recentsBlockTop = listTop
        let favoritesBlockTop = listBottom + half

        let recentsHeader = makeLabel("Recents", bold: true, size: 11)
        recentsHeader.frame = NSRect(x: 12, y: recentsBlockTop - 16, width: w - 24, height: 16)
        recentsHeaderLabel = recentsHeader

        let emptyRecents = makeLabel("Jump once to fill Recents", bold: false, size: 10)
        emptyRecents.textColor = .tertiaryLabelColor
        emptyRecents.frame = NSRect(x: 12, y: recentsBlockTop - 40, width: w - 24, height: 16)
        emptyRecentsLabel = emptyRecents

        let recentsDoc = NSView(frame: NSRect(x: 0, y: 0, width: w - 16, height: 1))
        recentsDocument = recentsDoc

        let recentsScrollHeight = max(40, half - 24)
        let recentsScrollView = NSScrollView(
            frame: NSRect(x: 8, y: favoritesBlockTop + 4, width: w - 16, height: recentsScrollHeight)
        )
        recentsScrollView.hasVerticalScroller = true
        recentsScrollView.hasHorizontalScroller = false
        recentsScrollView.autohidesScrollers = true
        recentsScrollView.borderType = .noBorder
        recentsScrollView.drawsBackground = false
        recentsScrollView.documentView = recentsDoc
        recentsScroll = recentsScrollView

        let favoritesHeader = makeLabel("Favorites", bold: true, size: 11)
        favoritesHeader.frame = NSRect(x: 12, y: favoritesBlockTop - 16, width: w - 24, height: 16)
        favoritesHeaderLabel = favoritesHeader

        let emptyFavorites = makeLabel("★ Favorite pins a path here", bold: false, size: 10)
        emptyFavorites.textColor = .tertiaryLabelColor
        emptyFavorites.frame = NSRect(x: 12, y: favoritesBlockTop - 40, width: w - 24, height: 16)
        emptyFavoritesLabel = emptyFavorites

        let favoritesDoc = NSView(frame: NSRect(x: 0, y: 0, width: w - 16, height: 1))
        favoritesDocument = favoritesDoc

        let favoritesScrollHeight = max(40, half - 24)
        let favoritesScrollView = NSScrollView(
            frame: NSRect(x: 8, y: listBottom, width: w - 16, height: favoritesScrollHeight)
        )
        favoritesScrollView.hasVerticalScroller = true
        favoritesScrollView.hasHorizontalScroller = false
        favoritesScrollView.autohidesScrollers = true
        favoritesScrollView.borderType = .noBorder
        favoritesScrollView.drawsBackground = false
        favoritesScrollView.documentView = favoritesDoc
        favoritesScroll = favoritesScrollView

        root.addSubview(status)
        root.addSubview(field)
        root.addSubview(jump)
        root.addSubview(add)
        root.addSubview(recentsHeader)
        root.addSubview(emptyRecents)
        root.addSubview(recentsScrollView)
        root.addSubview(favoritesHeader)
        root.addSubview(emptyFavorites)
        root.addSubview(favoritesScrollView)

        self.panel = panel
        rebuildRecentsRows()
        rebuildFavoritesRows()
        return panel
    }

    private func rebuildRecentsRows() {
        guard let document = recentsDocument, let scroll = recentsScroll else { return }
        document.subviews.forEach { $0.removeFromSuperview() }

        let empty = recentEntries.isEmpty
        emptyRecentsLabel?.isHidden = !empty
        scroll.isHidden = empty
        if empty {
            recentsHeaderLabel?.stringValue = "Recents"
            emptyRecentsLabel?.stringValue = "Jump once to fill Recents"
        } else {
            recentsHeaderLabel?.stringValue = "Recents (\(recentEntries.count))"
        }

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

    private func rebuildFavoritesRows() {
        guard let document = favoritesDocument, let scroll = favoritesScroll else { return }
        document.subviews.forEach { $0.removeFromSuperview() }

        let empty = favoriteEntries.isEmpty
        emptyFavoritesLabel?.isHidden = !empty
        scroll.isHidden = empty
        if empty {
            favoritesHeaderLabel?.stringValue = "Favorites"
            emptyFavoritesLabel?.stringValue = "★ Favorite pins a path here"
        } else {
            favoritesHeaderLabel?.stringValue = "Favorites (\(favoriteEntries.count))"
        }

        guard !empty else {
            document.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 1)
            return
        }

        let rowWidth = max(scroll.contentSize.width, chromeSize.width - 16)
        let totalHeight = CGFloat(favoriteEntries.count) * rowHeight
        document.frame = NSRect(x: 0, y: 0, width: rowWidth, height: max(totalHeight, scroll.contentSize.height))

        for (index, entry) in favoriteEntries.enumerated() {
            let yFromTop = CGFloat(index) * rowHeight
            let y = document.frame.height - yFromTop - rowHeight
            let row = makeFavoriteRow(entry: entry, index: index, width: rowWidth)
            row.frame = NSRect(x: 0, y: y, width: rowWidth, height: rowHeight)
            document.addSubview(row)
        }

        if totalHeight > scroll.contentSize.height {
            document.scroll(NSPoint(x: 0, y: document.frame.height))
        }
    }

    private func makeRecentRow(entry: RecentFolderEntry, index: Int, width: CGFloat) -> NSView {
        let row = FolderListRowControl(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        row.configure(
            displayName: entry.displayName,
            path: entry.path,
            isAvailable: entry.isAvailable,
            unavailableMessage: entry.unavailableMessage,
            index: index
        )
        row.target = self
        row.action = #selector(recentClicked(_:))
        row.autoresizingMask = [.width]
        return row
    }

    private func makeFavoriteRow(entry: FavoriteFolderEntry, index: Int, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        container.autoresizingMask = [.width]

        let jumpWidth = max(80, width - favoriteManageWidth - 4)
        let row = FolderListRowControl(
            frame: NSRect(x: 0, y: 0, width: jumpWidth, height: rowHeight)
        )
        row.configure(
            displayName: entry.displayName,
            path: entry.path,
            isAvailable: entry.isAvailable,
            unavailableMessage: entry.unavailableMessage,
            index: index
        )
        row.target = self
        row.action = #selector(favoriteClicked(_:))
        row.autoresizingMask = [.width, .height]
        container.addSubview(row)

        // 管理钮是独立 sibling，不叠在 label 下；整行 jump 区仍 full-hit
        let manageX = jumpWidth + 2
        let btnW: CGFloat = 16
        let btnH: CGFloat = 16
        let stackX = manageX
        let midY = rowHeight / 2

        let up = makeTinyButton(title: "↑", tag: index, action: #selector(favoriteMoveUp(_:)))
        up.frame = NSRect(x: stackX, y: midY + 2, width: btnW, height: btnH)
        up.toolTip = "Move up"
        up.isEnabled = index > 0

        let down = makeTinyButton(title: "↓", tag: index, action: #selector(favoriteMoveDown(_:)))
        down.frame = NSRect(x: stackX + 18, y: midY + 2, width: btnW, height: btnH)
        down.toolTip = "Move down"
        down.isEnabled = index < favoriteEntries.count - 1

        let remove = makeTinyButton(title: "✕", tag: index, action: #selector(favoriteRemove(_:)))
        remove.frame = NSRect(x: stackX + 9, y: midY - 16, width: btnW, height: btnH)
        remove.toolTip = "Remove favorite"

        container.addSubview(up)
        container.addSubview(down)
        container.addSubview(remove)
        return container
    }

    private func makeTinyButton(title: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = title
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.tag = tag
        button.target = self
        button.action = action
        button.focusRingType = .none
        return button
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

    @objc private func addFavoriteFromField() {
        onAddFavoriteFromPath?(pathField?.stringValue ?? "")
    }

    @objc private func recentClicked(_ sender: Any?) {
        let index: Int?
        if let row = sender as? FolderListRowControl {
            index = row.entryIndex
        } else if let button = sender as? NSControl {
            index = button.tag
        } else {
            index = nil
        }
        guard let index, recentEntries.indices.contains(index) else { return }
        let entry = recentEntries[index]
        if entry.isAvailable {
            // 回填 path 字段，便于用户看到目标
            pathField?.stringValue = entry.path
            setStatus("Jumping…")
            onJump?(entry.path)
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable")
            onUnavailableRecent?(reason)
        }
    }

    @objc private func favoriteClicked(_ sender: Any?) {
        let index: Int?
        if let row = sender as? FolderListRowControl {
            index = row.entryIndex
        } else if let button = sender as? NSControl {
            index = button.tag
        } else {
            index = nil
        }
        guard let index, favoriteEntries.indices.contains(index) else { return }
        let entry = favoriteEntries[index]
        if entry.isAvailable {
            pathField?.stringValue = entry.path
            setStatus("Jumping…")
            onJump?(entry.path)
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable")
            onUnavailableFavorite?(reason)
        }
    }

    @objc private func favoriteMoveUp(_ sender: NSButton) {
        let index = sender.tag
        guard favoriteEntries.indices.contains(index) else { return }
        onMoveFavoriteUp?(favoriteEntries[index].path)
    }

    @objc private func favoriteMoveDown(_ sender: NSButton) {
        let index = sender.tag
        guard favoriteEntries.indices.contains(index) else { return }
        onMoveFavoriteDown?(favoriteEntries[index].path)
    }

    @objc private func favoriteRemove(_ sender: NSButton) {
        let index = sender.tag
        guard favoriteEntries.indices.contains(index) else { return }
        onRemoveFavorite?(favoriteEntries[index].path)
    }
}

// MARK: - Folder list row (full-hit, hover, pressed)

/// 整行可点的列表行（Recents / Favorites jump 区）：自绘 hover/pressed，子 label 不抢 hit-test。
private final class FolderListRowControl: NSControl {
    private(set) var entryIndex: Int = 0
    private var isAvailable = true

    private let iconView = NSImageView()
    private let nameLabel = NonInteractiveLabel(labelWithString: "")
    private let pathLabel = NonInteractiveLabel(labelWithString: "")
    private let chevronLabel = NonInteractiveLabel(labelWithString: "›")

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        configureLayerChrome()

        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        iconView.contentTintColor = .secondaryLabelColor

        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail

        pathLabel.font = .systemFont(ofSize: 10)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle

        chevronLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        chevronLabel.textColor = .tertiaryLabelColor
        chevronLabel.alignment = .center

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(pathLabel)
        addSubview(chevronLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        displayName: String,
        path: String,
        isAvailable: Bool,
        unavailableMessage: String?,
        index: Int
    ) {
        entryIndex = index
        tag = index
        self.isAvailable = isAvailable

        nameLabel.stringValue = isAvailable
            ? displayName
            : "\(displayName) · unavailable"
        nameLabel.textColor = isAvailable ? .labelColor : .secondaryLabelColor
        pathLabel.stringValue = path

        let symbolName = isAvailable ? "folder.fill" : "folder.badge.questionmark"
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = isAvailable ? .controlAccentColor : .tertiaryLabelColor
        chevronLabel.isHidden = !isAvailable
        toolTip = isAvailable
            ? "Jump to \(path)"
            : (unavailableMessage ?? "Folder unavailable")

        needsLayout = true
        refreshAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // init 时 layer 可能还是 nil；入窗后再绑一次圆角/背景
        configureLayerChrome()
        refreshAppearance()
    }

    override func layout() {
        super.layout()
        let bounds = bounds.insetBy(dx: 4, dy: 2)
        let iconSide: CGFloat = 18
        let chevronW: CGFloat = isAvailable ? 14 : 0
        let textX = bounds.minX + iconSide + 8
        let textW = max(0, bounds.width - iconSide - 8 - chevronW - 4)

        iconView.frame = NSRect(
            x: bounds.minX,
            y: bounds.midY - iconSide / 2,
            width: iconSide,
            height: iconSide
        )
        nameLabel.frame = NSRect(x: textX, y: bounds.midY + 1, width: textW, height: 16)
        pathLabel.frame = NSRect(x: textX, y: bounds.midY - 15, width: textW, height: 14)
        if isAvailable {
            chevronLabel.frame = NSRect(
                x: bounds.maxX - chevronW,
                y: bounds.midY - 10,
                width: chevronW,
                height: 20
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            // toolbar 附着时前台往往是 TextEdit/panel service，DJ 非 active
            // 必须用 activeAlways，否则 hover/手型全灭
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    /// 整行吞掉 hit-test，避免子 label 挡住点击。
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.01 else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        refreshAppearance()
    }

    override func cursorUpdate(with event: NSEvent) {
        (isAvailable ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        refreshAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(local)
        if isPressed != inside {
            isPressed = inside
            refreshAppearance()
        }
    }

    override func mouseUp(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(local)
        let shouldFire = isPressed && inside
        isPressed = false
        refreshAppearance()
        if shouldFire {
            sendAction(action, to: target)
        }
    }

    private func configureLayerChrome() {
        wantsLayer = true
        guard let layer else { return }
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }

    private func refreshAppearance() {
        configureLayerChrome()
        let fill: NSColor
        if isPressed {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.28)
            chevronLabel.textColor = .controlAccentColor
        } else if isHovered {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.16)
            chevronLabel.textColor = .secondaryLabelColor
        } else {
            fill = .clear
            chevronLabel.textColor = .tertiaryLabelColor
        }
        // 动态色需在当前 appearance 下取 cgColor，否则可能是错色/透明
        effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = fill.cgColor
        }
    }
}

/// labelWithString 文本控件，但永远不参与 hit-test。
private final class NonInteractiveLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var acceptsFirstResponder: Bool { false }
}
