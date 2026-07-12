import ApplicationServices
import AppKit
import Foundation

public protocol FileDialogDetecting: Sendable {
    func detect(authorization: AccessibilityAuthorization) -> FileDialogDetectionState
}

/// Detects system standard Open/Save panels via panel service + AX fingerprint.
public struct FileDialogDetector: FileDialogDetecting {
    public init() {}

    public func detect(authorization: AccessibilityAuthorization) -> FileDialogDetectionState {
        guard authorization == .ready else {
            return .accessibilityPaused
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostBundle = frontmost?.bundleIdentifier
        let hostName = frontmost?.localizedName
        let hostBundle = frontmost?.bundleIdentifier

        if FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: frontmostBundle),
           let hit = bestEligibleWindow(pid: frontmost!.processIdentifier) {
            return .eligible(
                EligibleFileDialog(
                    panelPID: frontmost!.processIdentifier,
                    hostName: hostNameFromPanelService(frontmost?.localizedName) ?? hostName,
                    hostBundleIdentifier: hostBundle,
                    panelKind: hit.panelKind,
                    score: hit.points,
                    reasons: hit.reasons
                )
            )
        }

        let preferredHost = (hostName ?? "").lowercased()
        var hostMatched: EligibleFileDialog?
        var anyPanel: EligibleFileDialog?

        for application in NSWorkspace.shared.runningApplications {
            guard FileDialogFingerprint.isOpenAndSavePanelService(bundleIdentifier: application.bundleIdentifier)
            else { continue }

            let pid = application.processIdentifier
            guard let hit = bestEligibleWindow(pid: pid) else { continue }

            let candidate = EligibleFileDialog(
                panelPID: pid,
                hostName: hostNameFromPanelService(application.localizedName) ?? hostName,
                hostBundleIdentifier: hostBundle,
                panelKind: hit.panelKind,
                score: hit.points,
                reasons: hit.reasons
            )

            if anyPanel == nil {
                anyPanel = candidate
            }

            let serviceName = (application.localizedName ?? "").lowercased()
            if !preferredHost.isEmpty, serviceName.contains("(\(preferredHost))") {
                hostMatched = candidate
                break
            }
        }

        if let hostMatched {
            return .eligible(hostMatched)
        }
        if let anyPanel {
            return .eligible(anyPanel)
        }
        return .none
    }

    private func hostNameFromPanelService(_ localizedName: String?) -> String? {
        guard let localizedName else { return nil }
        // "Open and Save Panel Service (TextEdit)" → TextEdit
        guard let open = localizedName.firstIndex(of: "("),
              let close = localizedName.lastIndex(of: ")"),
              open < close
        else { return nil }
        let inner = localizedName[localizedName.index(after: open)..<close]
        let name = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func bestEligibleWindow(pid: pid_t) -> FileDialogFingerprintScore? {
        let app = AXUIElementCreateApplication(pid)
        var candidates: [AXUIElement] = axElements(app, kAXWindowsAttribute as CFString)
        if let focused = axElement(app, kAXFocusedWindowAttribute as CFString) {
            candidates.insert(focused, at: 0)
        }
        if let main = axElement(app, kAXMainWindowAttribute as CFString) {
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
