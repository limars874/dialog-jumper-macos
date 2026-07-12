import Foundation

/// Product-facing Accessibility authorization. Only `ready` means Folder Jump may run.
public enum AccessibilityAuthorization: Equatable, Sendable {
    /// `AXIsProcessTrusted()` is true.
    case ready
    /// Not trusted — Folder Jump must stay paused. Never present as authorized.
    case paused
}

/// Pure session transition for trust changes during a running app.
/// Tracks ready→paused as **revoked** (distinct recovery copy) without any system side effects.
public struct AccessibilitySessionTransition: Equatable, Sendable {
    public var authorization: AccessibilityAuthorization
    /// True once this process has observed `ready` at least once; stays true after revoke.
    public var hadBeenReady: Bool
    /// True only on the edge ready→paused (one-shot revoke detection for UI).
    public var justRevoked: Bool

    public init(
        authorization: AccessibilityAuthorization,
        hadBeenReady: Bool,
        justRevoked: Bool
    ) {
        self.authorization = authorization
        self.hadBeenReady = hadBeenReady
        self.justRevoked = justRevoked
    }

    /// Present paused-after-ready as revoked until trust returns.
    public var isRevokedPresentation: Bool {
        authorization == .paused && hadBeenReady
    }
}

public enum AccessibilityGate {
    /// Map the system trust bit to product authorization. No other signals allowed.
    public static func authorization(isProcessTrusted: Bool) -> AccessibilityAuthorization {
        isProcessTrusted ? .ready : .paused
    }

    /// Apply a fresh trust read to prior session state. Never prompts.
    public static func applyTrustChange(
        previous: AccessibilityAuthorization,
        isProcessTrusted: Bool,
        hadBeenReady: Bool
    ) -> AccessibilitySessionTransition {
        let next = authorization(isProcessTrusted: isProcessTrusted)
        let justRevoked = previous == .ready && next == .paused
        let nextHadBeenReady = hadBeenReady || next == .ready
        return AccessibilitySessionTransition(
            authorization: next,
            hadBeenReady: nextHadBeenReady,
            justRevoked: justRevoked
        )
    }

    public static func statusTitle(
        _ authorization: AccessibilityAuthorization,
        revoked: Bool = false
    ) -> String {
        switch authorization {
        case .ready:
            return "Accessibility: Ready"
        case .paused:
            if revoked {
                return "Accessibility: Revoked — Folder Jump stopped"
            }
            return "Accessibility: Paused — Folder Jump disabled"
        }
    }

    public static func shortMenuBarTitle(
        _ authorization: AccessibilityAuthorization,
        revoked: Bool = false
    ) -> String {
        // Glyph is shared; menu statusTitle distinguishes paused vs revoked.
        _ = revoked
        switch authorization {
        case .ready:
            return "DJ"
        case .paused:
            return "DJ!"
        }
    }

    public static func folderJumpMenuTitle(
        authorization: AccessibilityAuthorization,
        revoked: Bool,
        hasEligibleDialog: Bool,
        hostSummary: String? = nil
    ) -> String {
        guard isFolderJumpEnabled(authorization) else {
            if revoked {
                return "Folder Jump: stopped (Accessibility revoked)"
            }
            return "Folder Jump: paused (need Accessibility)"
        }
        if hasEligibleDialog {
            if let hostSummary, !hostSummary.isEmpty {
                return "Folder Jump: ready · \(hostSummary)"
            }
            return "Folder Jump: ready"
        }
        return "Folder Jump: waiting for File Dialog"
    }

    public static func revokeAlertMessage() -> String {
        "Accessibility was turned off while Dialog Jumper was running. "
            + "Attached chrome is detached and Folder Jump is stopped. "
            + "Open Accessibility Settings, enable Dialog Jumper, then Recheck Accessibility."
    }

    public static func isFolderJumpEnabled(_ authorization: AccessibilityAuthorization) -> Bool {
        authorization == .ready
    }
}
