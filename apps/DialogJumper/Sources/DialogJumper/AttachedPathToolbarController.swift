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

    private enum ListTab: Int {
        case recents = 0
        case favorites = 1
        case finder = 2
    }

    private var panel: NSPanel?
    private var pathField: NSTextField?
    private var statusLabel: NSTextField?
    private var listSegment: NSSegmentedControl?
    private var listScroll: NSScrollView?
    private var listDocument: NSView?
    private var emptyListLabel: NSTextField?
    private var addFavoriteButton: NSButton?
    private var refreshFinderButton: TinyActionButton?
    private var attachedPID: pid_t?
    private var recentEntries: [RecentFolderEntry] = []
    private var favoriteEntries: [FavoriteFolderEntry] = []
    private var finderEntries: [FinderFolderEntry] = []
    private var finderDidLoadOnce = false
    private var activeListTab: ListTab = .recents
    private let finderReader: any FinderWindowsReading

    private let chromeSize = CGSize(width: 300, height: 420)
    private let rowHeight: CGFloat = 30
    private let favoriteManageWidth: CGFloat = 52
    private let recentManageWidth: CGFloat = 46

    init(finderReader: any FinderWindowsReading = FinderWindowsReader()) {
        self.finderReader = finderReader
        super.init()
    }

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
        updateSegmentTitles()
        if activeListTab == .recents {
            rebuildActiveList()
        }
    }

    /// Refresh Favorites rows (call after manage / on show).
    func setFavorites(_ entries: [FavoriteFolderEntry]) {
        favoriteEntries = entries
        updateSegmentTitles()
        if activeListTab == .favorites {
            rebuildActiveList()
        }
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

        // 顶区：短状态 + Path + 按钮
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

        // 列表：Recent | Favs | Finder + 刷新（仅 Finder tab 用）
        let segment = NSSegmentedControl()
        segment.segmentCount = 3
        segment.setLabel("Recent", forSegment: ListTab.recents.rawValue)
        segment.setLabel("Favs", forSegment: ListTab.favorites.rawValue)
        segment.setLabel("Finder", forSegment: ListTab.finder.rawValue)
        segment.trackingMode = .selectOne
        segment.segmentStyle = .rounded
        segment.target = self
        segment.action = #selector(listTabChanged(_:))
        segment.selectedSegment = ListTab.recents.rawValue
        segment.frame = NSRect(x: 12, y: h - 124, width: w - 24 - 30, height: 24)
        listSegment = segment

        let refresh = TinyActionButton(frame: NSRect(x: w - 12 - 26, y: h - 124, width: 26, height: 24))
        refresh.glyph = "↻"
        refresh.glyphFontSize = 14
        refresh.toolTip = "Refresh Finder windows"
        refresh.target = self
        refresh.action = #selector(refreshFinderList)
        refresh.isHidden = true
        refreshFinderButton = refresh

        let empty = makeLabel("Jump once to fill Recents", bold: false, size: 11)
        empty.textColor = .tertiaryLabelColor
        empty.alignment = .center
        empty.frame = NSRect(x: 12, y: 40, width: w - 24, height: 18)
        emptyListLabel = empty

        let doc = NSView(frame: NSRect(x: 0, y: 0, width: w - 16, height: 1))
        listDocument = doc

        let listBottom: CGFloat = 12
        let listTop = h - 136
        let scroll = NSScrollView(frame: NSRect(x: 8, y: listBottom, width: w - 16, height: listTop - listBottom))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = doc
        listScroll = scroll

        root.addSubview(status)
        root.addSubview(field)
        root.addSubview(jump)
        root.addSubview(add)
        root.addSubview(segment)
        root.addSubview(refresh)
        root.addSubview(empty)
        root.addSubview(scroll)

        self.panel = panel
        updateSegmentTitles()
        updateRefreshButtonVisibility()
        rebuildActiveList()
        return panel
    }

    private func updateSegmentTitles() {
        guard let segment = listSegment else { return }
        segment.setLabel("Recent (\(recentEntries.count))", forSegment: ListTab.recents.rawValue)
        segment.setLabel("Favs (\(favoriteEntries.count))", forSegment: ListTab.favorites.rawValue)
        let finderLabel = finderDidLoadOnce ? "Finder (\(finderEntries.count))" : "Finder"
        segment.setLabel(finderLabel, forSegment: ListTab.finder.rawValue)
    }

    private func updateRefreshButtonVisibility() {
        refreshFinderButton?.isHidden = activeListTab != .finder
    }

    @objc private func listTabChanged(_ sender: NSSegmentedControl) {
        activeListTab = ListTab(rawValue: sender.selectedSegment) ?? .recents
        updateRefreshButtonVisibility()
        rebuildActiveList()
    }

    @objc private func refreshFinderList() {
        setStatus("Loading Finder…")
        switch finderReader.listOpenFolders() {
        case .success(let entries):
            finderEntries = entries
            finderDidLoadOnce = true
            updateSegmentTitles()
            if entries.isEmpty {
                setStatus("No open Finder windows")
            } else {
                setStatus("Finder · \(entries.count)")
            }
            if activeListTab == .finder {
                rebuildActiveList()
            }
        case .failure(.notAuthorized):
            finderDidLoadOnce = true
            finderEntries = []
            updateSegmentTitles()
            setStatus("Allow Automation for Finder")
            if activeListTab == .finder {
                rebuildActiveList()
            }
        case .failure(.scriptFailed(let message)):
            finderDidLoadOnce = true
            finderEntries = []
            updateSegmentTitles()
            let short = message.count > 48 ? String(message.prefix(45)) + "…" : message
            setStatus("Finder: \(short)")
            #if DEBUG
            NSLog("[DialogJumper] Finder script: %@", message)
            #endif
            if activeListTab == .finder {
                rebuildActiveList()
            }
        }
    }

    private func rebuildActiveList() {
        guard let document = listDocument, let scroll = listScroll else { return }
        document.subviews.forEach { $0.removeFromSuperview() }

        switch activeListTab {
        case .recents:
            rebuildRows(
                count: recentEntries.count,
                emptyMessage: "Jump once to fill Recents",
                document: document,
                scroll: scroll
            ) { index, width in
                makeRecentRow(entry: recentEntries[index], index: index, width: width)
            }
        case .favorites:
            rebuildRows(
                count: favoriteEntries.count,
                emptyMessage: "★ Favorite pins a path here",
                document: document,
                scroll: scroll
            ) { index, width in
                makeFavoriteRow(entry: favoriteEntries[index], index: index, width: width)
            }
        case .finder:
            let emptyMessage: String
            if !finderDidLoadOnce {
                emptyMessage = "↻ Refresh to load Finder windows"
            } else if finderEntries.isEmpty {
                emptyMessage = "No open Finder windows"
            } else {
                emptyMessage = ""
            }
            rebuildRows(
                count: finderEntries.count,
                emptyMessage: emptyMessage,
                document: document,
                scroll: scroll
            ) { index, width in
                makeFinderRow(entry: finderEntries[index], index: index, width: width)
            }
        }
    }

    private func rebuildRows(
        count: Int,
        emptyMessage: String,
        document: NSView,
        scroll: NSScrollView,
        makeRow: (Int, CGFloat) -> NSView
    ) {
        let empty = count == 0
        emptyListLabel?.stringValue = emptyMessage
        emptyListLabel?.isHidden = !empty
        scroll.isHidden = empty

        guard !empty else {
            document.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 1)
            return
        }

        let rowWidth = max(scroll.contentSize.width, chromeSize.width - 16)
        let totalHeight = CGFloat(count) * rowHeight
        // Cocoa scroll document: origin at bottom-left；行自上而下排布
        document.frame = NSRect(x: 0, y: 0, width: rowWidth, height: max(totalHeight, scroll.contentSize.height))

        for index in 0..<count {
            let yFromTop = CGFloat(index) * rowHeight
            let y = document.frame.height - yFromTop - rowHeight
            let row = makeRow(index, rowWidth)
            row.frame = NSRect(x: 0, y: y, width: rowWidth, height: rowHeight)
            document.addSubview(row)
        }

        if totalHeight > scroll.contentSize.height {
            document.scroll(NSPoint(x: 0, y: document.frame.height))
        }
    }

    private func makeRecentRow(entry: RecentFolderEntry, index: Int, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        container.autoresizingMask = [.width]

        let jumpWidth = max(80, width - recentManageWidth - 4)
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
        row.action = #selector(recentClicked(_:))
        row.autoresizingMask = [.width, .height]
        container.addSubview(row)

        // ★ 保持 16；仅复制按钮 +50% → 24（用户只嫌复制难点）
        let starW: CGFloat = 16
        let starH: CGFloat = 16
        let copyW: CGFloat = 24
        let copyH: CGFloat = 24
        let stackX = jumpWidth + 2

        let star = makeTinyButton(title: "★", tag: index, action: #selector(recentFavorite(_:)))
        star.frame = NSRect(
            x: stackX,
            y: (rowHeight - starH) / 2,
            width: starW,
            height: starH
        )
        star.toolTip = "Add to Favorites"

        let copy = makeTinyButton(title: "⎘", tag: index, action: #selector(recentCopyPath(_:)))
        copy.glyphFontSize = 14
        copy.frame = NSRect(
            x: stackX + starW + 4,
            y: (rowHeight - copyH) / 2,
            width: copyW,
            height: copyH
        )
        copy.toolTip = "Copy full path"

        container.addSubview(star)
        container.addSubview(copy)
        return container
    }

    private func makeFinderRow(entry: FinderFolderEntry, index: Int, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        container.autoresizingMask = [.width]

        let jumpWidth = max(80, width - recentManageWidth - 4)
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
        row.action = #selector(finderClicked(_:))
        row.autoresizingMask = [.width, .height]
        container.addSubview(row)

        let starW: CGFloat = 16
        let starH: CGFloat = 16
        let copyW: CGFloat = 24
        let copyH: CGFloat = 24
        let stackX = jumpWidth + 2

        let star = makeTinyButton(title: "★", tag: index, action: #selector(finderFavorite(_:)))
        star.frame = NSRect(
            x: stackX,
            y: (rowHeight - starH) / 2,
            width: starW,
            height: starH
        )
        star.toolTip = "Add to Favorites"

        let copy = makeTinyButton(title: "⎘", tag: index, action: #selector(finderCopyPath(_:)))
        copy.glyphFontSize = 14
        copy.frame = NSRect(
            x: stackX + starW + 4,
            y: (rowHeight - copyH) / 2,
            width: copyW,
            height: copyH
        )
        copy.toolTip = "Copy full path"

        container.addSubview(star)
        container.addSubview(copy)
        return container
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

        // 单行：↑ ↓ ✕ 横排靠右
        let btnW: CGFloat = 16
        let btnH: CGFloat = 16
        let midY = (rowHeight - btnH) / 2
        let stackX = jumpWidth + 2

        let up = makeTinyButton(title: "↑", tag: index, action: #selector(favoriteMoveUp(_:)))
        up.frame = NSRect(x: stackX, y: midY, width: btnW, height: btnH)
        up.toolTip = "Move up"
        up.isEnabled = index > 0

        let down = makeTinyButton(title: "↓", tag: index, action: #selector(favoriteMoveDown(_:)))
        down.frame = NSRect(x: stackX + 17, y: midY, width: btnW, height: btnH)
        down.toolTip = "Move down"
        down.isEnabled = index < favoriteEntries.count - 1

        let remove = makeTinyButton(title: "✕", tag: index, action: #selector(favoriteRemove(_:)))
        remove.frame = NSRect(x: stackX + 34, y: midY, width: btnW, height: btnH)
        remove.toolTip = "Remove favorite"

        container.addSubview(up)
        container.addSubview(down)
        container.addSubview(remove)
        return container
    }

    private func makeTinyButton(title: String, tag: Int, action: Selector) -> TinyActionButton {
        let button = TinyActionButton(frame: .zero)
        button.glyph = title
        button.tag = tag
        button.target = self
        button.action = action
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
            pathField?.stringValue = entry.path
            setStatus("Jumping…")
            onJump?(entry.path)
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable")
            onUnavailableRecent?(reason)
        }
    }

    @objc private func recentFavorite(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard recentEntries.indices.contains(index) else { return }
        let path = recentEntries[index].path
        pathField?.stringValue = path
        onAddFavoriteFromPath?(path)
    }

    @objc private func recentCopyPath(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard recentEntries.indices.contains(index) else { return }
        let path = recentEntries[index].path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        setStatus("Copied path")
    }

    @objc private func finderClicked(_ sender: Any?) {
        let index: Int?
        if let row = sender as? FolderListRowControl {
            index = row.entryIndex
        } else if let button = sender as? NSControl {
            index = button.tag
        } else {
            index = nil
        }
        guard let index, finderEntries.indices.contains(index) else { return }
        let entry = finderEntries[index]
        if entry.isAvailable {
            pathField?.stringValue = entry.path
            setStatus("Jumping…")
            onJump?(entry.path)
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable")
            onUnavailableRecent?(reason)
        }
    }

    @objc private func finderFavorite(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard finderEntries.indices.contains(index) else { return }
        let path = finderEntries[index].path
        pathField?.stringValue = path
        onAddFavoriteFromPath?(path)
    }

    @objc private func finderCopyPath(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard finderEntries.indices.contains(index) else { return }
        let path = finderEntries[index].path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        setStatus("Copied path")
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

    @objc private func favoriteMoveUp(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard favoriteEntries.indices.contains(index) else { return }
        onMoveFavoriteUp?(favoriteEntries[index].path)
    }

    @objc private func favoriteMoveDown(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard favoriteEntries.indices.contains(index) else { return }
        onMoveFavoriteDown?(favoriteEntries[index].path)
    }

    @objc private func favoriteRemove(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard favoriteEntries.indices.contains(index) else { return }
        onRemoveFavorite?(favoriteEntries[index].path)
    }
}

// MARK: - Single-line folder row (full-hit, hover, pressed)

/// 单行列表：`name · path`，无类型图标；整行 hit-test + activeAlways hover。
private final class FolderListRowControl: NSControl {
    private(set) var entryIndex: Int = 0
    private var isAvailable = true

    private let titleLabel = NonInteractiveLabel(labelWithString: "")
    private let chevronLabel = NonInteractiveLabel(labelWithString: "›")

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        configureLayerChrome()

        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.allowsDefaultTighteningForTruncation = true

        chevronLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        chevronLabel.textColor = .tertiaryLabelColor
        chevronLabel.alignment = .center

        addSubview(titleLabel)
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

        let nameColor: NSColor = isAvailable ? .labelColor : .secondaryLabelColor
        let pathColor: NSColor = isAvailable ? .tertiaryLabelColor : .quaternaryLabelColor
        let nameText = isAvailable ? displayName : "\(displayName) · unavailable"
        let shortPath = Self.displayPath(path)

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(
            string: nameText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: nameColor
            ]
        ))
        if !shortPath.isEmpty {
            attributed.append(NSAttributedString(
                string: "  \(shortPath)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: pathColor
                ]
            ))
        }
        titleLabel.attributedStringValue = attributed
        toolTip = isAvailable ? path : (unavailableMessage ?? path)
        chevronLabel.isHidden = !isAvailable
        needsLayout = true
        refreshAppearance()
    }

    /// 家目录压成 ~，中间截断留给 layout。
    private static func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    override func layout() {
        super.layout()
        let bounds = bounds.insetBy(dx: 6, dy: 0)
        let chevronW: CGFloat = isAvailable ? 12 : 0
        let textW = max(0, bounds.width - chevronW - 4)
        titleLabel.frame = NSRect(x: bounds.minX, y: bounds.midY - 8, width: textW, height: 16)
        if isAvailable {
            chevronLabel.frame = NSRect(
                x: bounds.maxX - chevronW,
                y: bounds.midY - 8,
                width: chevronW,
                height: 16
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
            // 侧栏附着时前台常是宿主，必须 activeAlways
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureLayerChrome()
        refreshAppearance()
    }

    private func configureLayerChrome() {
        wantsLayer = true
        guard let layer else { return }
        layer.cornerRadius = 6
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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = fill.cgColor
        }
    }
}

// MARK: - Tiny action button (★ ⎘ ↑ ↓ ✕)

/// 列表行旁小操作钮：activeAlways hover / 按下底色 + 手型。
private final class TinyActionButton: NSControl {
    var glyph: String = "" {
        didSet { needsDisplay = true }
    }
    var glyphFontSize: CGFloat = 11 {
        didSet { needsDisplay = true }
    }

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet {
            alphaValue = isEnabled ? 1 : 0.35
            if !isEnabled {
                isHovered = false
                isPressed = false
            }
            refreshAppearance()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, isEnabled, alphaValue > 0.01 else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        refreshAppearance()
    }

    override func cursorUpdate(with event: NSEvent) {
        (isEnabled ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        refreshAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let local = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(local)
        if isPressed != inside {
            isPressed = inside
            refreshAppearance()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let local = convert(event.locationInWindow, from: nil)
        let shouldFire = isPressed && bounds.contains(local)
        isPressed = false
        refreshAppearance()
        if shouldFire {
            sendAction(action, to: target)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let font = NSFont.systemFont(ofSize: glyphFontSize, weight: .semibold)
        let color: NSColor = isPressed
            ? .controlAccentColor
            : (isHovered ? .labelColor : .secondaryLabelColor)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (glyph as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        (glyph as NSString).draw(at: origin, withAttributes: attrs)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshAppearance()
    }

    private func refreshAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 4
        let fill: NSColor
        if !isEnabled {
            fill = .clear
        } else if isPressed {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.28)
        } else if isHovered {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.16)
        } else {
            fill = .clear
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = fill.cgColor
        }
        needsDisplay = true
    }
}

/// labelWithString 文本控件，但永远不参与 hit-test。
private final class NonInteractiveLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var acceptsFirstResponder: Bool { false }
}
