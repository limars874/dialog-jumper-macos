import Foundation

/// Product-facing Accessibility authorization. Only `ready` means Folder Jump may run.
public enum AccessibilityAuthorization: Equatable, Sendable {
    /// `AXIsProcessTrusted()` is true.
    case ready
    /// Not trusted — Folder Jump must stay paused. Never present as authorized.
    case paused
}

public enum AccessibilityGate {
    /// Map the system trust bit to product authorization. No other signals allowed.
    public static func authorization(isProcessTrusted: Bool) -> AccessibilityAuthorization {
        isProcessTrusted ? .ready : .paused
    }

    public static func statusTitle(_ authorization: AccessibilityAuthorization) -> String {
        switch authorization {
        case .ready:
            return "Accessibility: Ready"
        case .paused:
            return "Accessibility: Paused — Folder Jump disabled"
        }
    }

    public static func shortMenuBarTitle(_ authorization: AccessibilityAuthorization) -> String {
        switch authorization {
        case .ready:
            return "DJ"
        case .paused:
            return "DJ!"
        }
    }

    public static func isFolderJumpEnabled(_ authorization: AccessibilityAuthorization) -> Bool {
        authorization == .ready
    }
}
