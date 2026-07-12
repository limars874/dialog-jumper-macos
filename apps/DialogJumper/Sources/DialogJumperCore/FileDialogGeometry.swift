import ApplicationServices
import CoreGraphics
import Foundation

public struct FileDialogFrame: Equatable, Sendable {
    /// Cocoa global coordinates (origin bottom-left).
    public var cocoaRect: CGRect
    public var panelPID: pid_t

    public init(cocoaRect: CGRect, panelPID: pid_t) {
        self.cocoaRect = cocoaRect
        self.panelPID = panelPID
    }
}

/// Read the on-screen frame of an eligible Open/Save panel via AX.
public enum FileDialogGeometry {
    public static func frame(forPanelPID pid: pid_t) -> FileDialogFrame? {
        let app = AXUIElementCreateApplication(pid)
        guard let window = preferredWindow(app: app) else { return nil }
        guard let axOrigin = axPoint(window, kAXPositionAttribute as CFString),
              let axSize = axSize(window, kAXSizeAttribute as CFString),
              axSize.width > 40, axSize.height > 40
        else { return nil }

        // AX reports top-left origin in global screen space (y down from top of main display).
        let cocoaRect = cocoaRectFromAX(origin: axOrigin, size: axSize)
        return FileDialogFrame(cocoaRect: cocoaRect, panelPID: pid)
    }

    /// Place a side chrome of `chromeSize` to the right of the dialog when possible, else left.
    public static func sideChromeOrigin(
        dialog: CGRect,
        chromeSize: CGSize,
        gap: CGFloat = 8,
        screen: CGRect
    ) -> CGPoint {
        let rightX = dialog.maxX + gap
        let leftX = dialog.minX - gap - chromeSize.width
        let preferRight = rightX + chromeSize.width <= screen.maxX - 4
        let x = preferRight ? rightX : max(screen.minX + 4, leftX)
        // Align tops (Cocoa: maxY is top).
        var y = dialog.maxY - chromeSize.height
        y = min(max(y, screen.minY + 4), screen.maxY - chromeSize.height - 4)
        return CGPoint(x: x, y: y)
    }

    private static func preferredWindow(app: AXUIElement) -> AXUIElement? {
        if let focused = axElement(app, kAXFocusedWindowAttribute as CFString) {
            return focused
        }
        if let main = axElement(app, kAXMainWindowAttribute as CFString) {
            return main
        }
        return axElements(app, kAXWindowsAttribute as CFString).first
    }

    private static func cocoaRectFromAX(origin: CGPoint, size: CGSize) -> CGRect {
        // Primary display height in global top-left space.
        let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
        let cocoaY = mainHeight - origin.y - size.height
        return CGRect(x: origin.x, y: cocoaY, width: size.width, height: size.height)
    }
}

// MARK: - AX helpers (local)

private func axCopy(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value
}

private func axElement(_ element: AXUIElement, _ name: CFString) -> AXUIElement? {
    guard let value = axCopy(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeDowncast(value, to: AXUIElement.self)
}

private func axElements(_ element: AXUIElement, _ name: CFString) -> [AXUIElement] {
    guard let value = axCopy(element, name), CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
    let array = unsafeDowncast(value, to: CFArray.self)
    return (0..<CFArrayGetCount(array)).compactMap { index in
        guard let pointer = CFArrayGetValueAtIndex(array, index) else { return nil }
        let child = unsafeBitCast(pointer, to: AXUIElement.self)
        return CFGetTypeID(child) == AXUIElementGetTypeID() ? child : nil
    }
}

private func axPoint(_ element: AXUIElement, _ name: CFString) -> CGPoint? {
    guard let value = axCopy(element, name) else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
    return point
}

private func axSize(_ element: AXUIElement, _ name: CFString) -> CGSize? {
    guard let value = axCopy(element, name) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
    return size
}
