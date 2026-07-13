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

    /// 单击列表是否立即 Jump（菜单切换；双击始终 Jump）。默认 true。
    var jumpOnListClick: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.jumpOnListClickKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.jumpOnListClickKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.jumpOnListClickKey) }
    }

    private static let jumpOnListClickKey = "dialogJumper.jumpOnListClick"
    private enum ListTab: Int {
        case recents = 0
        case favorites = 1
        case finder = 2
        case zoxide = 3
    }

    private var panel: NSPanel?
    private var pathField: NSTextField?
    private var statusLabel: NSTextField?
    private var listSegment: NSSegmentedControl?
    private var listScroll: NSScrollView?
    private var listDocument: NSView?
    private var emptyListLabel: NSTextField?
    private var pathClearButton: NSButton?
    private var pathChrome: PathInputChromeView?
    private var jumpButton: NSButton?
    private var moreButton: TinyActionButton?
    private var moreMenu: NSMenu?
    private var pathDragHandle: FolderDragHandleView?
    private var refreshDynamicButton: TinyActionButton?
    private var attachedPID: pid_t?
    private var recentEntries: [RecentFolderEntry] = []
    private var favoriteEntries: [FavoriteFolderEntry] = []
    private var favoritePathKeys: Set<String> = []
    private var finderEntries: [FinderFolderEntry] = []
    private var zoxideEntries: [ZoxideFolderEntry] = []
    private var finderDidLoadOnce = false
    private var zoxideDidLoadOnce = false
    /// 列表区空态文案（未安装 / 空库 / 命令失败 / 未刷新）
    private var zoxidePanelMessage = "↻ Refresh zoxide (frecency)"
    private var activeListTab: ListTab = .recents
    private let finderReader: any FinderWindowsReading
    private let zoxideReader: any ZoxideReading

    private let chromeSize = CGSize(width: 300, height: 420)
    /// 列表行与顶区主控件统一高度
    private let rowHeight: CGFloat = 28
    private let controlHeight: CGFloat = 28
    private let contentInset: CGFloat = 12
    /// Path 行与列表共用的左拖柄列宽
    private let dragHandleWidth: CGFloat = 22
    private let controlGap: CGFloat = 4
    /// 列表右侧操作钮统一热区
    private let actionSize: CGFloat = 20
    private let actionGap: CGFloat = 2
    /// ☆ + 复制
    private let recentManageWidth: CGFloat = 42
    /// ↑ ↓ ✕
    private let favoriteManageWidth: CGFloat = 64

    init(
        finderReader: any FinderWindowsReading = FinderWindowsReader(),
        zoxideReader: any ZoxideReading = ZoxideReader()
    ) {
        self.finderReader = finderReader
        self.zoxideReader = zoxideReader
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
        statusLabel?.toolTip = text.isEmpty ? nil : text
        // 统一 secondary，避免错误文案抢主层级
        statusLabel?.textColor = .secondaryLabelColor
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
        favoritePathKeys = Set(entries.map { Self.canonicalPathKey($0.path) })
        updateSegmentTitles()
        // ★ 状态依赖收藏集合，各 tab 都重建
        rebuildActiveList()
    }

    private static func canonicalPathKey(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private func isFavoritePath(_ path: String) -> Bool {
        favoritePathKeys.contains(Self.canonicalPathKey(path))
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
        // chromeSize = 内容区；整窗含标题栏。顶对齐用 window 高度，
        // 否则侧栏会比 dialog 高出约一截标题栏。
        let contentProbe = NSRect(origin: .zero, size: chromeSize)
        let windowSize = panel.frameRect(forContentRect: contentProbe).size
        let gap: CGFloat = 8
        let dialogRect = frame.cocoaRect
        let rightX = dialogRect.maxX + gap
        let leftX = dialogRect.minX - gap - windowSize.width
        let preferRight = rightX + windowSize.width <= screen.maxX - 4
        let x = preferRight ? rightX : max(screen.minX + 4, leftX)
        var y = dialogRect.maxY - windowSize.height
        y = min(max(y, screen.minY + 4), screen.maxY - windowSize.height - 4)
        panel.setFrame(
            NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height),
            display: true
        )

        let host = dialog.hostName ?? "File Dialog"
        let kind = dialog.panelKind?.rawValue ?? "panel"
        let attachedLine = "Attached · \(kind) · \(host)"
        // 新附着或仍是默认文案时更新；Jump 成功/失败状态行不冲掉
        if isNewAttachment {
            setStatus(attachedLine)
        } else if let s = statusLabel?.stringValue, s.hasPrefix("Attached") || s.isEmpty {
            setStatus(attachedLine)
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
        // 栅格：inset=12，左列 drag=22，主控件高=28，右操作=20
        let inset = contentInset
        let rail = dragHandleWidth
        let gap = controlGap
        let ch = controlHeight

        // status + more（小字，不抢主层级）
        let status = makeLabel("", bold: false, size: 11)
        status.textColor = .secondaryLabelColor
        status.usesSingleLineMode = true
        status.maximumNumberOfLines = 1
        status.lineBreakMode = .byTruncatingTail
        status.cell?.lineBreakMode = .byTruncatingTail
        status.toolTip = nil
        status.frame = NSRect(x: inset, y: h - 26, width: w - inset * 2 - 32, height: 14)
        statusLabel = status

        let more = TinyActionButton(frame: NSRect(x: w - inset - 28, y: h - 32, width: 28, height: 24))
        more.glyph = "···"
        more.glyphFontSize = 13
        more.toolTip = "More"
        more.target = self
        more.action = #selector(showMoreMenu(_:))
        moreButton = more

        let overflow = NSMenu()
        let addFav = NSMenuItem(
            title: "Add Path to Favorites",
            action: #selector(addFavoriteFromField),
            keyEquivalent: ""
        )
        addFav.target = self
        overflow.addItem(addFav)
        let copyPath = NSMenuItem(
            title: "Copy Path Field",
            action: #selector(copyPathField),
            keyEquivalent: ""
        )
        copyPath.target = self
        overflow.addItem(copyPath)
        moreMenu = overflow

        // Path / Jump / segment 同宽 chromeW；Path 为内嵌拖柄+清除的一体框
        let chromeW = w - inset * 2
        let pathRowY = h - 36 - ch

        let pathChrome = PathInputChromeView(frame: NSRect(x: inset, y: pathRowY, width: chromeW, height: ch))
        self.pathChrome = pathChrome

        let pathHandle = FolderDragHandleView(frame: NSRect(x: 0, y: 0, width: rail, height: ch))
        pathHandle.pathProvider = { [weak self] in
            self?.resolvedPathFieldFolder()
        }
        pathHandle.onDragRejected = { [weak self] message in
            self?.setStatus(message)
        }
        pathHandle.toolTip = "Drag Path folder onto Open/Save panel"
        pathDragHandle = pathHandle

        let clearW: CGFloat = 20
        // 框内：左柄 | 文字 | clear，与列表左列 x 对齐（柄从 0 起）
        let field = NSTextField(frame: NSRect(
            x: rail,
            y: 4,
            width: chromeW - rail - clearW - 6,
            height: ch - 8
        ))
        field.placeholderString = "Paste path…  / or ~"
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.font = .systemFont(ofSize: 13)
        field.delegate = self
        field.target = self
        field.action = #selector(jumpFromField)
        pathField = field

        let clear = NSButton(frame: NSRect(
            x: chromeW - clearW - 4,
            y: (ch - 18) / 2,
            width: clearW,
            height: 18
        ))
        clear.bezelStyle = .inline
        clear.isBordered = false
        clear.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear path")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        clear.imagePosition = .imageOnly
        clear.contentTintColor = .secondaryLabelColor
        clear.target = self
        clear.action = #selector(clearPathField)
        clear.isHidden = true
        clear.toolTip = "Clear path"
        pathClearButton = clear

        pathChrome.addSubview(pathHandle)
        pathChrome.addSubview(field)
        pathChrome.addSubview(clear)
        pathChrome.refreshAppearance()

        // Jump：与 Path chrome 同宽同高；accent 作主按钮
        let jumpY = pathRowY - gap - ch
        let jump = NSButton(frame: NSRect(x: inset, y: jumpY, width: chromeW, height: ch))
        jump.title = "Jump"
        jump.bezelStyle = .rounded
        jump.controlSize = .regular
        jump.font = .systemFont(ofSize: 13, weight: .semibold)
        if #available(macOS 11.0, *) {
            jump.bezelColor = .controlAccentColor
        }
        jump.target = self
        jump.action = #selector(jumpFromField)
        jump.keyEquivalent = "\r"
        jumpButton = jump

        // Jump：与 Path chrome 同宽同高
        let jumpY = pathRowY - gap - ch
        let jump = NSButton(frame: NSRect(x: inset, y: jumpY, width: chromeW, height: ch))
        jump.title = "Jump"
        jump.bezelStyle = .rounded
        jump.controlSize = .regular
        jump.font = .systemFont(ofSize: 13, weight: .semibold)
        jump.target = self
        jump.action = #selector(jumpFromField)
        jump.keyEquivalent = "\r"
        jumpButton = jump

        // Segment 行总宽 = chromeW（↻ 收在右缘内）
        let segY = jumpY - gap - ch
        let segment = NSSegmentedControl()
        segment.segmentCount = 4
        segment.setLabel("Rec", forSegment: ListTab.recents.rawValue)
        segment.setLabel("Fav", forSegment: ListTab.favorites.rawValue)
        segment.setLabel("Find", forSegment: ListTab.finder.rawValue)
        segment.setLabel("Zox", forSegment: ListTab.zoxide.rawValue)
        segment.trackingMode = .selectOne
        segment.segmentStyle = .rounded
        segment.controlSize = .regular
        segment.target = self
        segment.action = #selector(listTabChanged(_:))
        segment.selectedSegment = ListTab.recents.rawValue
        segment.frame = NSRect(x: inset, y: segY, width: chromeW - 28, height: ch)
        listSegment = segment

        let refresh = TinyActionButton(frame: NSRect(x: inset + chromeW - 26, y: segY, width: 26, height: ch))
        refresh.glyph = "↻"
        refresh.glyphFontSize = 13
        refresh.toolTip = "Refresh"
        refresh.target = self
        refresh.action = #selector(refreshDynamicList)
        refresh.isHidden = true
        refreshDynamicButton = refresh

        let empty = makeLabel("Jump once to fill Recents", bold: false, size: 11)
        empty.textColor = .tertiaryLabelColor
        empty.alignment = .center
        empty.frame = NSRect(x: inset, y: 40, width: chromeW, height: 18)
        emptyListLabel = empty

        let doc = NSView(frame: NSRect(x: 0, y: 0, width: chromeW, height: 1))
        listDocument = doc

        let listBottom: CGFloat = 12
        let listTop = segY - gap
        let scroll = NSScrollView(frame: NSRect(x: inset, y: listBottom, width: chromeW, height: max(40, listTop - listBottom)))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = doc
        listScroll = scroll

        root.addSubview(status)
        root.addSubview(more)
        root.addSubview(pathChrome)
        root.addSubview(jump)
        root.addSubview(segment)
        root.addSubview(refresh)
        root.addSubview(empty)
        root.addSubview(scroll)

        self.panel = panel
        updateSegmentTitles()
        updateRefreshButtonVisibility()
        updatePathClearVisibility()
        rebuildActiveList()
        return panel
    }


    private func updateSegmentTitles() {
        guard let segment = listSegment else { return }
        segment.setLabel("Rec(\(recentEntries.count))", forSegment: ListTab.recents.rawValue)
        segment.setLabel("Fav(\(favoriteEntries.count))", forSegment: ListTab.favorites.rawValue)
        let finderLabel = finderDidLoadOnce ? "Find(\(finderEntries.count))" : "Find"
        segment.setLabel(finderLabel, forSegment: ListTab.finder.rawValue)
        let zoxLabel = zoxideDidLoadOnce ? "Zox(\(zoxideEntries.count))" : "Zox"
        segment.setLabel(zoxLabel, forSegment: ListTab.zoxide.rawValue)
    }

    private func updateRefreshButtonVisibility() {
        let needsRefresh = activeListTab == .finder || activeListTab == .zoxide
        refreshDynamicButton?.isHidden = !needsRefresh
        switch activeListTab {
        case .finder:
            refreshDynamicButton?.toolTip = "Refresh Finder windows"
        case .zoxide:
            refreshDynamicButton?.toolTip = "Refresh zoxide list"
        default:
            break
        }
    }

    @objc private func listTabChanged(_ sender: NSSegmentedControl) {
        activeListTab = ListTab(rawValue: sender.selectedSegment) ?? .recents
        updateRefreshButtonVisibility()
        rebuildActiveList()
    }

    @objc private func refreshDynamicList() {
        switch activeListTab {
        case .finder:
            refreshFinderList()
        case .zoxide:
            refreshZoxideList()
        default:
            break
        }
    }

    private func refreshFinderList() {
        setStatus("Loading Finder…")
        switch finderReader.listOpenFolders() {
        case .success(let entries):
            finderEntries = entries
            finderDidLoadOnce = true
            updateSegmentTitles()
            if entries.isEmpty {
                setStatus("No open Finder windows")
            } else if entries.count >= FinderWindowsReader.capacity {
                setStatus("Finder · \(entries.count) (max)")
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

    private func refreshZoxideList() {
        setStatus("Loading zoxide…")
        switch zoxideReader.listFolders() {
        case .success(let entries):
            zoxideEntries = entries
            zoxideDidLoadOnce = true
            updateSegmentTitles()
            if entries.isEmpty {
                zoxidePanelMessage = "zoxide DB empty"
                setStatus("zoxide DB empty")
            } else if entries.count >= ZoxideReader.capacity {
                zoxidePanelMessage = ""
                setStatus("Zox · \(entries.count) (max)")
            } else {
                zoxidePanelMessage = ""
                setStatus("Zox · \(entries.count)")
            }
            if activeListTab == .zoxide {
                rebuildActiveList()
            }
        case .failure(.notInstalled):
            zoxideDidLoadOnce = true
            zoxideEntries = []
            zoxidePanelMessage = "zoxide not found"
            updateSegmentTitles()
            setStatus("zoxide not found")
            if activeListTab == .zoxide {
                rebuildActiveList()
            }
        case .failure(.commandFailed(let message)):
            zoxideDidLoadOnce = true
            zoxideEntries = []
            let short = message.count > 48 ? String(message.prefix(45)) + "…" : message
            zoxidePanelMessage = "zoxide: \(short)"
            updateSegmentTitles()
            setStatus("zoxide: \(short)")
            #if DEBUG
            NSLog("[DialogJumper] zoxide: %@", message)
            #endif
            if activeListTab == .zoxide {
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
                emptyMessage = "↻ Refresh Finder windows"
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
        case .zoxide:
            rebuildRows(
                count: zoxideEntries.count,
                emptyMessage: zoxidePanelMessage,
                document: document,
                scroll: scroll
            ) { index, width in
                makeZoxideRow(entry: zoxideEntries[index], index: index, width: width)
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
        makeActionRow(
            displayName: entry.displayName,
            path: entry.path,
            isAvailable: entry.isAvailable,
            unavailableMessage: entry.unavailableMessage,
            index: index,
            width: width,
            manageWidth: recentManageWidth,
            click: #selector(recentClicked(_:)),
            doubleClick: #selector(recentDoubleClicked(_:)),
            leadingActions: { stackX, midY, container in
                self.addStarCopyActions(
                    container: container,
                    stackX: stackX,
                    index: index,
                    path: entry.path,
                    star: #selector(self.recentFavorite(_:)),
                    copy: #selector(self.recentCopyPath(_:))
                )
            }
        )
    }

    private func makeFinderRow(entry: FinderFolderEntry, index: Int, width: CGFloat) -> NSView {
        makeActionRow(
            displayName: entry.displayName,
            path: entry.path,
            isAvailable: entry.isAvailable,
            unavailableMessage: entry.unavailableMessage,
            index: index,
            width: width,
            manageWidth: recentManageWidth,
            click: #selector(finderClicked(_:)),
            doubleClick: #selector(finderDoubleClicked(_:)),
            leadingActions: { stackX, _, container in
                self.addStarCopyActions(
                    container: container,
                    stackX: stackX,
                    index: index,
                    path: entry.path,
                    star: #selector(self.finderFavorite(_:)),
                    copy: #selector(self.finderCopyPath(_:))
                )
            }
        )
    }

    private func makeZoxideRow(entry: ZoxideFolderEntry, index: Int, width: CGFloat) -> NSView {
        makeActionRow(
            displayName: entry.displayName,
            path: entry.path,
            isAvailable: entry.isAvailable,
            unavailableMessage: entry.unavailableMessage,
            index: index,
            width: width,
            manageWidth: recentManageWidth,
            click: #selector(zoxideClicked(_:)),
            doubleClick: #selector(zoxideDoubleClicked(_:)),
            leadingActions: { stackX, _, container in
                self.addStarCopyActions(
                    container: container,
                    stackX: stackX,
                    index: index,
                    path: entry.path,
                    star: #selector(self.zoxideFavorite(_:)),
                    copy: #selector(self.zoxideCopyPath(_:))
                )
            }
        )
    }

    private func makeFavoriteRow(entry: FavoriteFolderEntry, index: Int, width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        container.autoresizingMask = [.width]

        let handle = makeDragHandle(
            path: entry.path,
            displayName: entry.displayName,
            enabled: entry.isAvailable
        )
        handle.frame = NSRect(x: 0, y: 0, width: dragHandleWidth, height: rowHeight)
        container.addSubview(handle)

        let jumpWidth = max(60, width - dragHandleWidth - favoriteManageWidth - 4)
        let row = FolderListRowControl(
            frame: NSRect(x: dragHandleWidth, y: 0, width: jumpWidth, height: rowHeight)
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
        row.doubleAction = #selector(favoriteDoubleClicked(_:))
        row.autoresizingMask = [.width, .height]
        container.addSubview(row)

        let btn = actionSize
        let midY = (rowHeight - btn) / 2
        let stackX = dragHandleWidth + jumpWidth + 2

        let up = makeTinyButton(title: "↑", tag: index, action: #selector(favoriteMoveUp(_:)))
        up.glyphFontSize = 12
        up.frame = NSRect(x: stackX, y: midY, width: btn, height: btn)
        up.toolTip = "Move up"
        up.isEnabled = index > 0

        let down = makeTinyButton(title: "↓", tag: index, action: #selector(favoriteMoveDown(_:)))
        down.glyphFontSize = 12
        down.frame = NSRect(x: stackX + btn + actionGap, y: midY, width: btn, height: btn)
        down.toolTip = "Move down"
        down.isEnabled = index < favoriteEntries.count - 1

        let remove = makeTinyButton(title: "✕", tag: index, action: #selector(favoriteRemove(_:)))
        remove.glyphFontSize = 12
        remove.frame = NSRect(x: stackX + (btn + actionGap) * 2, y: midY, width: btn, height: btn)
        remove.toolTip = "Remove favorite"

        container.addSubview(up)
        container.addSubview(down)
        container.addSubview(remove)
        return container
    }

    /// 左拖柄 + 中 Jump 区 + 右操作：拖与点分离。
    private func makeActionRow(
        displayName: String,
        path: String,
        isAvailable: Bool,
        unavailableMessage: String?,
        index: Int,
        width: CGFloat,
        manageWidth: CGFloat,
        click: Selector,
        doubleClick: Selector,
        leadingActions: (CGFloat, CGFloat, NSView) -> Void
    ) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        container.autoresizingMask = [.width]

        let handle = makeDragHandle(path: path, displayName: displayName, enabled: isAvailable)
        handle.frame = NSRect(x: 0, y: 0, width: dragHandleWidth, height: rowHeight)
        container.addSubview(handle)

        let jumpWidth = max(60, width - dragHandleWidth - manageWidth - 4)
        let row = FolderListRowControl(
            frame: NSRect(x: dragHandleWidth, y: 0, width: jumpWidth, height: rowHeight)
        )
        row.configure(
            displayName: displayName,
            path: path,
            isAvailable: isAvailable,
            unavailableMessage: unavailableMessage,
            index: index
        )
        row.target = self
        row.action = click
        row.doubleAction = doubleClick
        row.autoresizingMask = [.width, .height]
        container.addSubview(row)

        let stackX = dragHandleWidth + jumpWidth + 2
        let midY = (rowHeight - actionSize) / 2
        leadingActions(stackX, midY, container)
        return container
    }

    private func addStarCopyActions(
        container: NSView,
        stackX: CGFloat,
        index: Int,
        path: String,
        star: Selector,
        copy: Selector
    ) {
        let starW = actionSize
        let starH = actionSize
        let copyW = actionSize
        let copyH = actionSize
        let favorited = isFavoritePath(path)

        let starBtn = makeTinyButton(title: favorited ? "★" : "☆", tag: index, action: star)
        starBtn.glyphFontSize = 12
        if favorited {
            starBtn.glyphColor = .systemYellow
        }
        starBtn.frame = NSRect(
            x: stackX,
            y: (rowHeight - starH) / 2,
            width: starW,
            height: starH
        )
        starBtn.toolTip = favorited ? "Already in Favorites" : "Add to Favorites"

        let copyBtn = makeTinyButton(title: "⎘", tag: index, action: copy)
        copyBtn.glyphFontSize = 12
        copyBtn.frame = NSRect(
            x: stackX + starW + actionGap,
            y: (rowHeight - copyH) / 2,
            width: copyW,
            height: copyH
        )
        copyBtn.toolTip = "Copy full path"

        container.addSubview(starBtn)
        container.addSubview(copyBtn)
    }

    private func makeDragHandle(path: String, displayName: String, enabled: Bool) -> FolderDragHandleView {
        let handle = FolderDragHandleView(frame: .zero)
        handle.configure(path: path, displayName: displayName, enabled: enabled)
        handle.onDragRejected = { [weak self] message in
            self?.setStatus(message)
        }
        return handle
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

    @objc private func clearPathField() {
        pathField?.stringValue = ""
        updatePathClearVisibility()
        setStatus("")
    }

    @objc private func showMoreMenu(_ sender: Any?) {
        guard let moreMenu, let button = moreButton else { return }
        let point = NSPoint(x: 0, y: button.bounds.height + 2)
        moreMenu.popUp(positioning: nil, at: point, in: button)
    }

    @objc private func copyPathField() {
        let text = pathField?.stringValue ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setStatus("Path field empty")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        setStatus("Copied path field")
    }

    private func updatePathClearVisibility() {
        let text = pathField?.stringValue ?? ""
        pathClearButton?.isHidden = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func controlTextDidChange(_ obj: Notification) {
        updatePathClearVisibility()
    }

    /// Path 框 → 可拖的真实目录；无效则 nil。
    private func resolvedPathFieldFolder() -> (path: String, displayName: String)? {
        let raw = (pathField?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, PathResolver.looksLikePath(raw) else { return nil }
        let expanded = PathResolver.expandTilde(raw, homeDirectoryPath: NSHomeDirectory())
        let path = (expanded as NSString).standardizingPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        let name = (path as NSString).lastPathComponent
        return (path, name.isEmpty ? path : name)
    }

    @objc private func addFavoriteFromField() {
        onAddFavoriteFromPath?(pathField?.stringValue ?? "")
    }
    @objc private func recentClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: recentEntries, forceJump: false, unavailable: onUnavailableRecent)
    }

    @objc private func recentDoubleClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: recentEntries, forceJump: true, unavailable: onUnavailableRecent)
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
        selectListPath(from: sender, entries: finderEntries, forceJump: false, unavailable: onUnavailableRecent)
    }

    @objc private func finderDoubleClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: finderEntries, forceJump: true, unavailable: onUnavailableRecent)
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

    @objc private func zoxideClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: zoxideEntries, forceJump: false, unavailable: onUnavailableRecent)
    }

    @objc private func zoxideDoubleClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: zoxideEntries, forceJump: true, unavailable: onUnavailableRecent)
    }

    @objc private func zoxideFavorite(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard zoxideEntries.indices.contains(index) else { return }
        let path = zoxideEntries[index].path
        pathField?.stringValue = path
        onAddFavoriteFromPath?(path)
    }

    @objc private func zoxideCopyPath(_ sender: Any?) {
        let index = (sender as? NSControl)?.tag ?? -1
        guard zoxideEntries.indices.contains(index) else { return }
        let path = zoxideEntries[index].path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        setStatus("Copied path")
    }

    @objc private func favoriteClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: favoriteEntries, forceJump: false, unavailable: onUnavailableFavorite)
    }

    @objc private func favoriteDoubleClicked(_ sender: Any?) {
        selectListPath(from: sender, entries: favoriteEntries, forceJump: true, unavailable: onUnavailableFavorite)
    }

    /// 统一列表选择：forceJump 或 jumpOnListClick 时 Jump；否则只填 Path。
    private func selectListPath(
        from sender: Any?,
        entries: [some ListPathEntry],
        forceJump: Bool,
        unavailable: ((String) -> Void)?
    ) {
        let index: Int?
        if let row = sender as? FolderListRowControl {
            index = row.entryIndex
        } else if let control = sender as? NSControl {
            index = control.tag
        } else {
            index = nil
        }
        guard let index, entries.indices.contains(index) else { return }
        let entry = entries[index]
        if entry.isAvailable {
            pathField?.stringValue = entry.path
            if forceJump || jumpOnListClick {
                setStatus("Jumping…")
                onJump?(entry.path)
            } else {
                setStatus("Path set")
            }
        } else {
            let reason = entry.unavailableMessage ?? "That folder is not available."
            setStatus("Unavailable")
            unavailable?(reason)
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

/// 列表行可选中条目的公共字段。
private protocol ListPathEntry {
    var path: String { get }
    var isAvailable: Bool { get }
    var unavailableMessage: String? { get }
}

extension RecentFolderEntry: ListPathEntry {}
extension FavoriteFolderEntry: ListPathEntry {}
extension FinderFolderEntry: ListPathEntry {}
extension ZoxideFolderEntry: ListPathEntry {}

// MARK: - Single-line folder row (full-hit, hover, pressed)

/// 单行列表：`name · path`，无类型图标；整行 hit-test + activeAlways hover。
private final class FolderListRowControl: NSControl {
    private(set) var entryIndex: Int = 0
    private var isAvailable = true
    /// 双击始终 Jump；单击走 action（是否 Jump 由 jumpOnListClick 决定）
    var doubleAction: Selector?

    private let titleLabel = NonInteractiveLabel(labelWithString: "")
    private let chevronLabel = NonInteractiveLabel(labelWithString: "›")

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        configureLayerChrome()

        titleLabel.usesSingleLineMode = true
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.cell?.lineBreakMode = .byTruncatingMiddle
        titleLabel.cell?.truncatesLastVisibleLine = true
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

        // attributed 字符串必须自带 paragraphStyle，否则 NSTextField 常不画省略号
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingMiddle
        para.allowsDefaultTighteningForTruncation = true

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(
            string: nameText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: nameColor,
                .paragraphStyle: para
            ]
        ))
        if !shortPath.isEmpty {
            attributed.append(NSAttributedString(
                string: "  \(shortPath)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: pathColor,
                    .paragraphStyle: para
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
            if event.clickCount >= 2, let doubleAction {
                sendAction(doubleAction, to: target)
            } else {
                sendAction(action, to: target)
            }
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
    /// 非 nil 时覆盖默认灰/label 色（已收藏 ★ 用 systemYellow）
    var glyphColor: NSColor? {
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
        let color: NSColor
        if let glyphColor {
            color = isPressed ? glyphColor.blended(withFraction: 0.2, of: .controlAccentColor) ?? glyphColor : glyphColor
        } else if isPressed {
            color = .controlAccentColor
        } else if isHovered {
            color = .labelColor
        } else {
            color = .secondaryLabelColor
        }
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

// MARK: - Folder drag handle (left of row; independent of Jump hit area)

/// 专用拖柄：只从这里发起拖放，pasteboard 为文件夹 file URL（系统 Open/Save 可原生导航）。
private final class FolderDragHandleView: NSView, NSDraggingSource {
    private var folderPath: String = ""
    private var displayName: String = ""
    private var dragEnabled = false
    private var mouseDownPoint: NSPoint?
    private let iconView = NSImageView()

    var onDragRejected: ((String) -> Void)?
    /// 若设置，拖出时现取 path（用于 Path 输入框）；否则用 configure 的静态 path。
    var pathProvider: (() -> (path: String, displayName: String)?)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        iconView.image = NSImage(
            systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
            accessibilityDescription: "Drag folder"
        )?.withSymbolConfiguration(config)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .secondaryLabelColor
        addSubview(iconView)
        toolTip = "Drag onto Open/Save panel to navigate"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(path: String, displayName: String, enabled: Bool) {
        folderPath = path
        self.displayName = displayName
        dragEnabled = enabled
        pathProvider = nil
        alphaValue = enabled ? 1 : 0.35
        iconView.contentTintColor = enabled ? .secondaryLabelColor : .quaternaryLabelColor
        toolTip = enabled
            ? "Drag onto Open/Save panel to navigate"
            : "Folder unavailable"
        window?.invalidateCursorRects(for: self)
    }

    override func layout() {
        super.layout()
        let side: CGFloat = 14
        iconView.frame = NSRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
    }

    override func resetCursorRects() {
        discardCursorRects()
        if pathProvider != nil || dragEnabled {
            addCursorRect(bounds, cursor: .openHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if pathProvider != nil || dragEnabled {
            mouseDownPoint = convert(event.locationInWindow, from: nil)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - start.x
        let dy = current.y - start.y
        let threshold: CGFloat = 4
        guard hypot(dx, dy) >= threshold else { return }
        mouseDownPoint = nil
        beginFolderDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
    }

    private func beginFolderDrag(with event: NSEvent) {
        let path: String
        let name: String
        if let pathProvider {
            guard let resolved = pathProvider() else {
                onDragRejected?("Can't drag — need a real folder path")
                return
            }
            path = resolved.path
            name = resolved.displayName
        } else {
            guard dragEnabled else { return }
            path = (folderPath as NSString).standardizingPath
            name = displayName
        }

        let standardized = (path as NSString).standardizingPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir), isDir.boolValue else {
            onDragRejected?("Can't drag — folder missing")
            return
        }

        let url = URL(fileURLWithPath: standardized, isDirectory: true)
        let writer = FolderURLPasteboardWriter(url: url)
        let item = NSDraggingItem(pasteboardWriter: writer)
        let preview = dragPreviewImage(name: name.isEmpty ? url.lastPathComponent : name)
        let dragRect = bounds.insetBy(dx: -4, dy: -4)
        item.setDraggingFrame(dragRect, contents: preview)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }


    private func dragPreviewImage(name: String) -> NSImage {
        let folderIcon = NSImage(
            systemSymbolName: "folder.fill",
            accessibilityDescription: nil
        ) ?? NSImage(size: NSSize(width: 16, height: 16))
        let text = name as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let pad: CGFloat = 6
        let iconSide: CGFloat = 16
        let size = NSSize(
            width: pad + iconSide + 4 + ceil(textSize.width) + pad,
            height: max(iconSide, ceil(textSize.height)) + pad
        )
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.controlBackgroundColor.withAlphaComponent(0.92).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            folderIcon.draw(
                in: NSRect(x: pad, y: (rect.height - iconSide) / 2, width: iconSide, height: iconSide),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            text.draw(
                at: NSPoint(x: pad + iconSide + 4, y: (rect.height - textSize.height) / 2),
                withAttributes: attrs
            )
            return true
        }
        return image
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // 放宽 mask：面板若只声明 copy/link，仅 generic 会显示禁止光标
        [.copy, .generic, .link, .move]
    }
}

/// 同时提供 file URL + 旧版 filenames 列表，贴近 Finder 拖文件夹的 pasteboard 形状。
private final class FolderURLPasteboardWriter: NSObject, NSPasteboardWriting {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            .string
        ]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .fileURL || type.rawValue == "public.file-url" {
            // 必须是 URL 字符串（file:///…），不是 path
            return (url as NSURL).absoluteString
        }
        if type.rawValue == "NSFilenamesPboardType" {
            return [url.path]
        }
        if type == .string {
            return url.path
        }
        return nil
    }
}

// MARK: - Path input chrome (single box: drag + field + clear)

/// 一体 Path 框：圆角描边 + 文本底，内嵌拖柄与清除；深浅色跟系统。
private final class PathInputChromeView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.borderWidth = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshAppearance()
    }

    func refreshAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            self.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
