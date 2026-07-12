import ApplicationServices
import Foundation

public protocol AccessibilityTrustReading: Sendable {
    func isProcessTrusted() -> Bool
}

/// Live system trust. Does not show a permission prompt.
public struct SystemAccessibilityTrustReader: AccessibilityTrustReading {
    public init() {}

    public func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}

public enum AccessibilitySettingsLink {
    /// System Settings → Privacy & Security → Accessibility
    public static let privacyAccessibilityURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!
}
