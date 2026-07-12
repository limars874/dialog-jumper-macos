import ApplicationServices
import AppKit
import Foundation

public protocol FileDialogDetecting: Sendable {
    func detect(authorization: AccessibilityAuthorization) -> FileDialogDetectionState
}

/// Detects system Open/Save panels.
///
/// The panel XPC service often stays alive after Cancel. Eligibility requires a
/// **visible on-screen** large window (or large AX window), never process-only.
public struct FileDialogDetector: FileDialogDetecting {
    public init() {}

    public func detect(authorization: AccessibilityAuthorization) -> FileDialogDetectionState {
    public func detect(authorization: AccessibilityAuthorization) -> FileDialogDetectionState {
        guard authorization == .ready else { return .accessibilityPaused }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let preferredHost = (frontmost?.localizedName ?? "").lowercased()

        var hostMatched: EligibleFileDialog?
        var anyPanel: EligibleFileDialog?

        for application in NSWorkspace.shared.runningApplications {
            guard FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: application.bundleIdentifier)
            else { continue }

            let pid = application.processIdentifier
            guard isPanelVisiblyOpen(pid: pid) else { continue }

            // Host identity comes from the panel service name, NOT current frontmost app.
            // (Using frontmost as host made chrome stay when switching to another app.)
            let serviceHostName = hostNameFromPanelService(application.localizedName)
            let hostApp = resolvedHostApplication(named: serviceHostName)

            let hit = bestEligibleWindow(pid: pid)
                ?? FileDialogFingerprintScore(
                    points: 2,
                    reasons: ["visibleOnScreenChrome"],
                    panelKind: inferKind(application.localizedName)
                )

            let candidate = EligibleFileDialog(
                panelPID: pid,
                hostName: serviceHostName ?? hostApp?.localizedName,
                hostBundleIdentifier: hostApp?.bundleIdentifier,
                panelKind: hit.panelKind,
                score: max(hit.points, 2),
                reasons: hit.reasons
            )
            if anyPanel == nil { anyPanel = candidate }

            let serviceName = (application.localizedName ?? "").lowercased()
            if !preferredHost.isEmpty, serviceName.contains("(\(preferredHost))") {
                hostMatched = candidate
                break
            }
            if application.processIdentifier == frontmost?.processIdentifier {
                hostMatched = candidate
                break
            }
        }

        if let hostMatched { return .eligible(hostMatched) }
        if let anyPanel { return .eligible(anyPanel) }

        if let pid = cgVisiblePanelServicePID() {
            let hit = bestEligibleWindow(pid: pid)
                ?? FileDialogFingerprintScore(
                    points: 2,
                    reasons: ["cgOnScreenPanel"],
                    panelKind: .unknown
                )
            return .eligible(
                EligibleFileDialog(
                    panelPID: pid,
                    hostName: nil,
                    hostBundleIdentifier: nil,
                    panelKind: hit.panelKind,
                    score: max(hit.points, 2),
                    reasons: hit.reasons
                )
            )
        }

        return .none
    }

    private func resolvedHostApplication(named name: String?) -> NSRunningApplication? {
        guard let name, !name.isEmpty else { return nil }
        let lower = name.lowercased()
        return NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "").lowercased() == lower
        }
    }
            )
        }

        return .none
    }

    private func inferKind(_ name: String?) -> FileDialogFingerprintScore.PanelKind {
        let lower = (name ?? "").lowercased()
        if lower.contains("save") { return .save }
        if lower.contains("open") { return .open }
        return .unknown
    }

    private func hostNameFromPanelService(_ localizedName: String?) -> String? {
        guard let localizedName,
              let open = localizedName.firstIndex(of: "("),
              let close = localizedName.lastIndex(of: ")"),
              open < close
        else { return nil }
        let inner = localizedName[localizedName.index(after: open)..<close]
        let name = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Process alive ≠ panel open. Cancel leaves the service running.
    private func isPanelVisiblyOpen(pid: pid_t) -> Bool {
        if let size = largestOnScreenCGSize(pid: pid), size.width > 200, size.height > 150 {
            return true
        }
        return hasLargeAXWindow(pid: pid)
    }

    private func hasLargeAXWindow(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var windows = axElements(app, kAXWindowsAttribute as CFString)
        if let focused = axElement(app, kAXFocusedWindowAttribute as CFString) {
            windows.insert(focused, at: 0)
        }
        for window in windows {
            if let size = axSize(window, kAXSizeAttribute as CFString),
               size.width > 200, size.height > 150 {
                return true
            }
        }
        return false
    }

    private func largestOnScreenCGSize(pid: pid_t) -> CGSize? {
        let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        var best = CGSize.zero
        for window in info {
            guard let ownerPID = readPID(window), ownerPID == pid else { continue }
            if let alpha = window[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }
            if let alpha = window[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue < 0.05 {
                continue
            }
            guard let (w, h) = readWH(window) else { continue }
            if w * h > best.width * best.height {
                best = CGSize(width: w, height: h)
            }
        }
        return best == .zero ? nil : best
    }

    private func cgVisiblePanelServicePID() -> pid_t? {
        let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        var bestPID: pid_t?
        var bestArea: CGFloat = 0
        for window in info {
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? ""
            guard owner.lowercased().contains("open and save panel") else { continue }
            guard let pid = readPID(window), let (w, h) = readWH(window) else { continue }
            guard w > 200, h > 150 else { continue }
            let area = w * h
            if area > bestArea {
                bestArea = area
                bestPID = pid
            }
        }
        return bestPID
    }

    private func readPID(_ window: [String: Any]) -> pid_t? {
        if let p = window[kCGWindowOwnerPID as String] as? pid_t { return p }
        if let n = window[kCGWindowOwnerPID as String] as? NSNumber { return pid_t(truncating: n) }
        return nil
    }

    private func readWH(_ window: [String: Any]) -> (CGFloat, CGFloat)? {
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else { return nil }
        let w = (bounds["Width"] as? CGFloat)
            ?? (bounds["Width"] as? NSNumber).map { CGFloat(truncating: $0) }
            ?? 0
        let h = (bounds["Height"] as? CGFloat)
            ?? (bounds["Height"] as? NSNumber).map { CGFloat(truncating: $0) }
            ?? 0
        return (w, h)
    }

    private func bestEligibleWindow(pid: pid_t) -> FileDialogFingerprintScore? {
        let application = AXUIElementCreateApplication(pid)
        var candidates = axElements(application, kAXWindowsAttribute as CFString)
        if let focused = axElement(application, kAXFocusedWindowAttribute as CFString) {
            candidates.insert(focused, at: 0)
        }
        if let main = axElement(application, kAXMainWindowAttribute as CFString) {
            candidates.insert(main, at: 0)
        }

        var best: FileDialogFingerprintScore?
        var seen = Set<CFHashCode>()
        for window in candidates {
            let hash = CFHash(window)
            guard seen.insert(hash).inserted else { continue }
            let signals = FileDialogWindowSignals(
                role: axString(window, kAXRoleAttribute as CFString) ?? "",
                subrole: axString(window, kAXSubroleAttribute as CFString) ?? "",
                identifier: axString(window, kAXIdentifierAttribute as CFString) ?? "",
                title: axString(window, kAXTitleAttribute as CFString) ?? ""
            )
            let score = FileDialogFingerprint.score(signals)
            guard score.isEligible else { continue }
            if best == nil || score.points > best!.points {
                best = score
            }
        }
        return best
    }
}

// MARK: - AX helpers

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
    guard let value = axCopy(element, name), CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
    return value as? String
}

private func axSize(_ element: AXUIElement, _ name: CFString) -> CGSize? {
    guard let value = axCopy(element, name) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
    return size
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
