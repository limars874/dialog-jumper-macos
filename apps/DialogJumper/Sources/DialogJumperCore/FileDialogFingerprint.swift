import Foundation

/// Attributes observed on one AX window candidate (no AX types here — pure logic).
public struct FileDialogWindowSignals: Equatable, Sendable {
    public var role: String
    public var subrole: String
    public var identifier: String
    public var title: String

    public init(role: String = "", subrole: String = "", identifier: String = "", title: String = "") {
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
    }
}

public struct FileDialogFingerprintScore: Equatable, Sendable {
    public var points: Int
    public var reasons: [String]
    public var panelKind: PanelKind?

    public enum PanelKind: String, Equatable, Sendable {
        case open
        case save
        case unknown
    }

    public var isEligible: Bool { points >= FileDialogFingerprint.minimumEligibleScore }

    public init(points: Int, reasons: [String], panelKind: PanelKind?) {
        self.points = points
        self.reasons = reasons
        self.panelKind = panelKind
    }
}

/// Multi-signal eligibility. Does not trust English titles alone.
public enum FileDialogFingerprint {
    public static let minimumEligibleScore = 2

    public static func score(_ signals: FileDialogWindowSignals) -> FileDialogFingerprintScore {
        var points = 0
        var reasons: [String] = []
        var kind: FileDialogFingerprintScore.PanelKind?

        let id = signals.identifier.lowercased()
        if id == "openpanel" {
            points += 3
            reasons.append("identifier:OpenPanel")
            kind = .open
        } else if id == "savepanel" {
            points += 3
            reasons.append("identifier:SavePanel")
            kind = .save
        }

        let role = signals.role
        let subrole = signals.subrole
        let isWindow = role == "AXWindow" || role.hasSuffix("Window")
        let isSystemDialog = subrole == "AXSystemDialog"
        let isDialogSubrole = subrole == "AXDialog" || subrole.hasSuffix("Dialog")

        if isWindow && isSystemDialog {
            points += 2
            reasons.append("window+AXSystemDialog")
            if kind == nil { kind = .unknown }
        } else if isWindow && isDialogSubrole {
            points += 1
            reasons.append("window+dialogSubrole")
            if kind == nil { kind = .unknown }
        }

        return FileDialogFingerprintScore(points: points, reasons: reasons, panelKind: kind)
    }

    public static func isOpenAndSavePanelService(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifier.lowercased().contains("openandsavepanelservice")
    }
}

public enum FileDialogDetectionState: Equatable, Sendable {
    case accessibilityPaused
    case none
    case eligible(EligibleFileDialog)

    public var menuTitle: String {
        switch self {
        case .accessibilityPaused:
            return "File Dialog: detection paused (need Accessibility)"
        case .none:
            return "File Dialog: none / not eligible"
        case .eligible(let dialog):
            let kind = dialog.panelKind?.rawValue ?? "unknown"
            let why = dialog.reasons.prefix(2).joined(separator: ",")
            if let host = dialog.hostName, !host.isEmpty {
                return "File Dialog: detected (\(kind), \(host)) [\(why)]"
            }
            return "File Dialog: detected (\(kind)) [\(why)]"
        }
    }
}

public struct EligibleFileDialog: Equatable, Sendable {
    public var panelPID: Int32
    public var hostName: String?
    public var hostBundleIdentifier: String?
    public var panelKind: FileDialogFingerprintScore.PanelKind?
    public var score: Int
    public var reasons: [String]

    public init(
        panelPID: Int32,
        hostName: String? = nil,
        hostBundleIdentifier: String? = nil,
        panelKind: FileDialogFingerprintScore.PanelKind? = nil,
        score: Int,
        reasons: [String]
    ) {
        self.panelPID = panelPID
        self.hostName = hostName
        self.hostBundleIdentifier = hostBundleIdentifier
        self.panelKind = panelKind
        self.score = score
        self.reasons = reasons
    }
}
