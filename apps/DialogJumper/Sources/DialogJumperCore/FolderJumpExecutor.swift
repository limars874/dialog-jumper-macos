import AppKit
import ApplicationServices
import Foundation

/// Outcome of a Folder Jump attempt. Success requires location evidence.
public enum FolderJumpOutcome: Equatable, Sendable {
    case success(path: String, evidence: String)
    case failure(FolderJumpFailure)
}

public enum FolderJumpFailure: Equatable, Sendable {
    case accessibilityPaused
    case noEligibleDialog
    case path(PathResolutionFailure)
    case postEventDenied
    case goToFolderDidNotOpen
    case pathFieldNotFound
    case pathFieldNotWritable
    case confirmFailed
    case verificationFailed
    case dialogLost
    case actionFailed(String)

    public var userMessage: String {
        switch self {
        case .accessibilityPaused:
            return "Accessibility is paused — Folder Jump disabled."
        case .noEligibleDialog:
            return "No eligible File Dialog detected."
        case .path(let reason):
            return reason.userMessage
        case .postEventDenied:
            return "Cannot send keyboard/mouse events to the File Dialog."
        case .goToFolderDidNotOpen:
            return "Go to Folder did not open."
        case .pathFieldNotFound:
            return "Could not find the Go to Folder path field."
        case .pathFieldNotWritable:
            return "Could not write the path into Go to Folder."
        case .confirmFailed:
            return "Could not confirm Go to Folder (sheet still open)."
        case .verificationFailed:
            return "Jump finished without location evidence — not claiming success."
        case .dialogLost:
            return "File Dialog disappeared during jump."
        case .actionFailed(let detail):
            return detail
        }
    }
}

public protocol FolderJumping: Sendable {
    func jump(
        rawPath: String,
        authorization: AccessibilityAuthorization,
        dialog: EligibleFileDialog?
    ) -> FolderJumpOutcome
}

/// Locked MVP jump path:
/// ⇧⌘G → AX PathTextField write → directed synthetic click (panel PID) → Return → verify.
/// Never submits Open/Save for the user.
public struct FolderJumpExecutor: FolderJumping {
    private let presence: any DirectoryPresenceReading
    private let homeDirectoryPath: String

    public init(
        homeDirectoryPath: String = NSHomeDirectory(),
        presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader()
    ) {
        self.homeDirectoryPath = homeDirectoryPath
        self.presence = presence
    }

    public func jump(
        rawPath: String,
        authorization: AccessibilityAuthorization,
        dialog: EligibleFileDialog?
    ) -> FolderJumpOutcome {
        guard authorization == .ready else {
            return .failure(.accessibilityPaused)
        }
        guard let dialog else {
            return .failure(.noEligibleDialog)
        }

        switch PathResolver.resolve(
            rawPath,
            homeDirectoryPath: homeDirectoryPath,
            presence: presence
        ) {
        case .failed(let reason):
            return .failure(.path(reason))
        case .ok(let url):
            return performJump(to: url, panelPID: dialog.panelPID)
        }
    }

    // MARK: - Jump sequence

    private func performJump(to url: URL, panelPID: pid_t) -> FolderJumpOutcome {
        let path = url.standardizedFileURL.path
        let app = AXUIElementCreateApplication(panelPID)

        guard panelStillPresent(app: app) else {
            return .failure(.dialogLost)
        }

        if let raiseError = raiseBestWindow(app: app) {
            return .failure(raiseError)
        }

        // 1) ⇧⌘G — Go to Folder
        if let keyError = postKey(keyCode: 5, flags: [.maskCommand, .maskShift], targetPID: panelPID) {
            return .failure(keyError)
        }
        Thread.sleep(forTimeInterval: 0.45)

        guard goToFolderSheetIsActive(app: app) || pathTextField(in: app) != nil else {
            return .failure(.goToFolderDidNotOpen)
        }

        // 2) Locate PathTextField
        guard let field = pathTextField(in: app) ?? focusedTextField(in: app) else {
            return .failure(.pathFieldNotFound)
        }

        // 3) Write path via AX
        if !isSettable(field, kAXValueAttribute as CFString) {
            return .failure(.pathFieldNotWritable)
        }
        // Best-effort focus (AppKit first responder still needs the directed click).
        if isSettable(field, kAXFocusedAttribute as CFString) {
            _ = AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        let setResult = AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, path as CFString)
        guard setResult == .success else {
            return .failure(.pathFieldNotWritable)
        }

        // 4) Directed synthetic click on field center (panel PID; no global mouse-move)
        if let clickError = clickCenter(of: field, targetPID: panelPID) {
            return .failure(clickError)
        }

        // 5) Return to confirm — never press Open/Save buttons
        for _ in 0..<2 where goToFolderSheetIsActive(app: app) {
            if let keyError = postKey(keyCode: 36, flags: [], targetPID: panelPID) {
                return .failure(keyError)
            }
            Thread.sleep(forTimeInterval: 0.45)
        }
        if goToFolderSheetIsActive(app: app) {
            return .failure(.confirmFailed)
        }

        Thread.sleep(forTimeInterval: 0.55)

        // 6) Location evidence required
        guard panelStillPresent(app: app) else {
            return .failure(.dialogLost)
        }
        let evidence = locationEvidence(for: path, app: app)
        guard evidence != "unknown" else {
            return .failure(.verificationFailed)
        }
        return .success(path: path, evidence: evidence)
    }

    // MARK: - AX panel helpers

    private func panelStillPresent(app: AXUIElement) -> Bool {
        !axElements(app, kAXWindowsAttribute as CFString).isEmpty
            || axElement(app, kAXFocusedWindowAttribute as CFString) != nil
    }

    private func raiseBestWindow(app: AXUIElement) -> FolderJumpFailure? {
        var windows = axElements(app, kAXWindowsAttribute as CFString)
        if let focused = axElement(app, kAXFocusedWindowAttribute as CFString) {
            windows.insert(focused, at: 0)
        }
        if let main = axElement(app, kAXMainWindowAttribute as CFString) {
            windows.insert(main, at: 0)
        }
        guard let window = windows.first else {
            return .dialogLost
        }
        if actionNames(window).contains(kAXRaiseAction as String) {
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            Thread.sleep(forTimeInterval: 0.2)
        }
        return nil
    }

    private func pathTextField(in app: AXUIElement) -> AXUIElement? {
        let roots = windowRoots(app: app)
        for root in roots {
            let nodes = collectNodes(from: root, maxDepth: 8, maxNodes: 400)
            if let hit = nodes.first(where: { $0.identifier == "PathTextField" }) {
                return hit.element
            }
            if let goTo = nodes.first(where: { $0.identifier == "GoToWindow" }) {
                let nested = collectNodes(from: goTo.element, maxDepth: 5, maxNodes: 80)
                if let field = nested.first(where: {
                    $0.role == (kAXTextFieldRole as String) || $0.identifier == "PathTextField"
                }) {
                    return field.element
                }
            }
        }
        return nil
    }

    private func focusedTextField(in app: AXUIElement) -> AXUIElement? {
        if let focused = axElement(app, kAXFocusedUIElementAttribute as CFString),
           axString(focused, kAXRoleAttribute as CFString) == (kAXTextFieldRole as String) {
            return focused
        }
        for root in windowRoots(app: app) {
            let nodes = collectNodes(from: root, maxDepth: 8, maxNodes: 400)
            let focused = nodes.filter {
                $0.role == (kAXTextFieldRole as String)
                    && axBool($0.element, kAXFocusedAttribute as CFString) == true
            }
            if focused.count == 1 {
                return focused[0].element
            }
        }
        return nil
    }

    private func goToFolderSheetIsActive(app: AXUIElement) -> Bool {
        for root in windowRoots(app: app) {
            let nodes = collectNodes(from: root, maxDepth: 4, maxNodes: 120)
            if nodes.contains(where: {
                ($0.identifier == "GoToWindow" || $0.identifier == "PathTextField")
                    && axBool($0.element, "AXVisible" as CFString) != false
            }) {
                return true
            }
        }
        return false
    }

    private func locationEvidence(for path: String, app: AXUIElement) -> String {
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let expectedName = URL(fileURLWithPath: standardized).lastPathComponent
        let fileURLString = URL(fileURLWithPath: standardized).absoluteString

        for root in windowRoots(app: app) {
            let nodes = collectNodes(from: root, maxDepth: 8, maxNodes: 500)
            if nodes.contains(where: {
                $0.value == standardized || $0.url == fileURLString
            }) {
                return "exact-path-match"
            }
            if nodes.contains(where: {
                $0.identifier == "where popup" && $0.value == expectedName
            }) {
                return "where-popup-basename-match"
            }
            // Breadcrumb / path control often exposes last component as title/value.
            if !expectedName.isEmpty,
               nodes.contains(where: {
                   ($0.role == (kAXPopUpButtonRole as String) || $0.identifier?.contains("where") == true)
                       && ($0.value == expectedName || $0.title == expectedName)
               }) {
                return "where-control-basename-match"
            }
        }
        return "unknown"
    }

    private func windowRoots(app: AXUIElement) -> [AXUIElement] {
        var roots = axElements(app, kAXWindowsAttribute as CFString)
        if let focused = axElement(app, kAXFocusedWindowAttribute as CFString) {
            roots.insert(focused, at: 0)
        }
        if let main = axElement(app, kAXMainWindowAttribute as CFString) {
            roots.insert(main, at: 0)
        }
        var seen = Set<CFHashCode>()
        return roots.filter { seen.insert(CFHash($0)).inserted }
    }

    // MARK: - Synthetic input (directed; no global mouse-move)

    private func ensurePostEventAccess() -> FolderJumpFailure? {
        if CGPreflightPostEventAccess() {
            return nil
        }
        // Accessibility-trusted apps usually pass; request once if needed.
        if CGRequestPostEventAccess() {
            return nil
        }
        return .postEventDenied
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags, targetPID: pid_t) -> FolderJumpFailure? {
        if let denied = ensurePostEventAccess() {
            return denied
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            return .actionFailed("Could not create keyboard event.")
        }
        down.flags = flags
        up.flags = flags
        // Directed to panel service PID — avoids stealing focus via session-wide post when possible.
        down.postToPid(targetPID)
        up.postToPid(targetPID)
        return nil
    }

    private func clickCenter(of element: AXUIElement, targetPID: pid_t) -> FolderJumpFailure? {
        if let denied = ensurePostEventAccess() {
            return denied
        }
        guard let position = axPoint(element, kAXPositionAttribute as CFString),
              let size = axSize(element, kAXSizeAttribute as CFString)
        else {
            return .actionFailed("Path field has no AX position/size.")
        }
        let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: center,
            mouseButton: .left
        ),
            let up = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: center,
                mouseButton: .left
            )
        else {
            return .actionFailed("Could not create synthetic click.")
        }
        // postToPid does not move the global cursor (no CGEvent mouse-moved).
        down.postToPid(targetPID)
        up.postToPid(targetPID)
        Thread.sleep(forTimeInterval: 0.15)
        return nil
    }
}

// MARK: - Minimal AX bridge (private to this file)

private struct AXNode {
    var element: AXUIElement
    var depth: Int
    var role: String
    var title: String?
    var value: String?
    var url: String?
    var identifier: String?
}

private func axCopy(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
}

private func axElement(_ element: AXUIElement, _ name: CFString) -> AXUIElement? {
    guard let value = axCopy(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeDowncast(value, to: AXUIElement.self)
}

private func axString(_ element: AXUIElement, _ name: CFString) -> String? {
    guard let value = axCopy(element, name) else { return nil }
    if CFGetTypeID(value) == CFStringGetTypeID() {
        return value as? String
    }
    if CFGetTypeID(value) == CFURLGetTypeID(), let url = value as? URL {
        return url.absoluteString
    }
    if CFGetTypeID(value) == CFNumberGetTypeID(), let number = value as? NSNumber {
        return number.stringValue
    }
    return nil
}

private func axBool(_ element: AXUIElement, _ name: CFString) -> Bool? {
    guard let value = axCopy(element, name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
    return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
}

private func axPoint(_ element: AXUIElement, _ name: CFString) -> CGPoint? {
    guard let value = axCopy(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgPoint else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
}

private func axSize(_ element: AXUIElement, _ name: CFString) -> CGSize? {
    guard let value = axCopy(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = unsafeDowncast(value, to: AXValue.self)
    guard AXValueGetType(axValue) == .cgSize else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
}

private func axElements(_ element: AXUIElement, _ name: CFString) -> [AXUIElement] {
    guard let value = axCopy(element, name), CFGetTypeID(value) == CFArrayGetTypeID() else {
        return []
    }
    let array = unsafeDowncast(value, to: CFArray.self)
    return (0..<CFArrayGetCount(array)).compactMap { index in
        guard let pointer = CFArrayGetValueAtIndex(array, index) else { return nil }
        let child = unsafeBitCast(pointer, to: AXUIElement.self)
        return CFGetTypeID(child) == AXUIElementGetTypeID() ? child : nil
    }
}

private func actionNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success, let names else { return [] }
    return names as? [String] ?? []
}

private func isSettable(_ element: AXUIElement, _ name: CFString) -> Bool {
    var settable = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(element, name, &settable) == .success && settable.boolValue
}

private func collectNodes(from root: AXUIElement, maxDepth: Int, maxNodes: Int) -> [AXNode] {
    var nodes: [AXNode] = []
    var visited = Set<CFHashCode>()

    func visit(_ element: AXUIElement, depth: Int) {
        guard depth <= maxDepth, nodes.count < maxNodes else { return }
        let hash = CFHash(element)
        guard visited.insert(hash).inserted else { return }

        nodes.append(
            AXNode(
                element: element,
                depth: depth,
                role: axString(element, kAXRoleAttribute as CFString) ?? "unknown",
                title: axString(element, kAXTitleAttribute as CFString),
                value: axString(element, kAXValueAttribute as CFString),
                url: axString(element, kAXURLAttribute as CFString),
                identifier: axString(element, kAXIdentifierAttribute as CFString)
            )
        )

        for child in axElements(element, kAXChildrenAttribute as CFString) {
            visit(child, depth: depth + 1)
        }
    }

    visit(root, depth: 0)
    return nodes
}
