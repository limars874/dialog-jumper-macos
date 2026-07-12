import Foundation

/// Structured reasons for strict Path Input failure (no search fallback).
public enum PathResolutionFailure: String, Equatable, Sendable {
    case empty
    case notPath
    case notFound
    case notDirectory
    case unreachable
    case unmounted

    public var userMessage: String {
        switch self {
        case .empty:
            return "Enter a folder path."
        case .notPath:
            return "Need an absolute path or ~ (Path is not search)."
        case .notFound:
            return "That path does not exist."
        case .notDirectory:
            return "That path is not a folder."
        case .unreachable:
            return "That folder is not reachable."
        case .unmounted:
            return "That volume is not mounted."
        }
    }
}

public enum PathResolution: Equatable, Sendable {
    case ok(URL)
    case failed(PathResolutionFailure)
}

/// Filesystem view used by PathResolver so pure resolution can be unit-tested.
public protocol DirectoryPresenceReading: Sendable {
    /// Inspect a standardized absolute filesystem path.
    func inspect(path: String) -> PathFileInspection
}

public enum PathFileInspection: Equatable, Sendable {
    case missing
    case file
    case directory(isReachable: Bool)
    case unmountedVolume
}

/// Live FileManager-backed probe.
public struct FileManagerDirectoryPresenceReader: DirectoryPresenceReading, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func inspect(path: String) -> PathFileInspection {
        if Self.looksLikeUnmountedVolume(path, fileManager: fileManager) {
            return .unmountedVolume
        }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        guard exists else { return .missing }
        guard isDirectory.boolValue else { return .file }

        let reachable = fileManager.isReadableFile(atPath: path)
        return .directory(isReachable: reachable)
    }

    /// `/Volumes/Name/...` when the volume root itself is missing → unmounted.
    private static func looksLikeUnmountedVolume(_ path: String, fileManager: FileManager) -> Bool {
        let prefix = "/Volumes/"
        guard path.hasPrefix(prefix) else { return false }
        let rest = path.dropFirst(prefix.count)
        guard !rest.isEmpty else { return false }
        let volumeName = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        guard !volumeName.isEmpty else { return false }
        let volumeRoot = prefix + volumeName
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: volumeRoot, isDirectory: &isDirectory)
        return !exists
    }
}

/// Expand `~` / absolute paths and validate directory reachability. Never fuzzy-search.
public enum PathResolver {
    /// Resolve raw Path Input into a directory URL or a structured failure.
    public static func resolve(
        _ raw: String,
        homeDirectoryPath: String = NSHomeDirectory(),
        presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader()
    ) -> PathResolution {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failed(.empty)
        }

        guard looksLikePath(trimmed) else {
            return .failed(.notPath)
        }

        let expanded = expandTilde(trimmed, homeDirectoryPath: homeDirectoryPath)
        let standardized = (expanded as NSString).standardizingPath
        guard standardized.hasPrefix("/") else {
            return .failed(.notPath)
        }

        switch presence.inspect(path: standardized) {
        case .missing:
            return .failed(.notFound)
        case .file:
            return .failed(.notDirectory)
        case .unmountedVolume:
            return .failed(.unmounted)
        case .directory(let isReachable):
            guard isReachable else {
                return .failed(.unreachable)
            }
            return .ok(URL(fileURLWithPath: standardized, isDirectory: true))
        }
    }

    /// Absolute (`/…`) or home-relative (`~` / `~/…`) only — never free text.
    public static func looksLikePath(_ raw: String) -> Bool {
        raw.hasPrefix("/") || raw == "~" || raw.hasPrefix("~/")
    }

    public static func expandTilde(_ raw: String, homeDirectoryPath: String) -> String {
        if raw == "~" {
            return homeDirectoryPath
        }
        if raw.hasPrefix("~/") {
            let home = homeDirectoryPath.hasSuffix("/")
                ? String(homeDirectoryPath.dropLast())
                : homeDirectoryPath
            return home + String(raw.dropFirst(1))
        }
        return raw
    }
}
