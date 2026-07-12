import Foundation

/// One open Finder window resolved to a folder path.
public struct FinderFolderEntry: Equatable, Sendable {
    public var path: String
    public var displayName: String
    public var isAvailable: Bool
    public var unavailableMessage: String?

    public init(
        path: String,
        displayName: String,
        isAvailable: Bool,
        unavailableMessage: String? = nil
    ) {
        self.path = path
        self.displayName = displayName
        self.isAvailable = isAvailable
        self.unavailableMessage = unavailableMessage
    }
}

public enum FinderWindowsError: Error, Equatable, Sendable {
    case scriptFailed(String)
    case notAuthorized
}

public protocol FinderWindowsReading: Sendable {
    /// 按需拉取：当前打开的 Finder 窗口 → 文件夹 path（去重、保序）。
    func listOpenFolders() -> Result<[FinderFolderEntry], FinderWindowsError>
}

/// 通过 AppleScript 读 Finder window `target`（会触发 Automation 授权弹窗，若尚未授权）。
public struct FinderWindowsReader: FinderWindowsReading {
    /// 列表软上限，避免上百个 Finder 窗拖垮 ↻ / 侧栏。
    public static let capacity = 50

    private let presence: any DirectoryPresenceReading

    public init(presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader()) {
        self.presence = presence
    }

    public func listOpenFolders() -> Result<[FinderFolderEntry], FinderWindowsError> {
        // 注意：不要 `repeat with w in every Finder window`（会得到脆弱 reference，
        // target as alias 在新系统上大量失败）。用 window 索引 + 双路径 coercion。
        let source = """
        set outText to ""
        tell application "Finder"
          set n to count of windows
          repeat with i from 1 to n
            try
              set w to window i
              try
                set p to POSIX path of (target of w as alias)
              on error
                set p to POSIX path of (target of w as text)
              end try
              if outText is "" then
                set outText to p
              else
                set outText to outText & linefeed & p
              end if
            end try
          end repeat
        end tell
        return outText
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(.scriptFailed("Could not create AppleScript."))
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "AppleScript failed."
            // -1743 not authorized / -10004 privilege violations 等
            if number == -1743 || number == -10004
                || message.localizedCaseInsensitiveContains("not authorized")
                || message.localizedCaseInsensitiveContains("not allowed") {
                return .failure(.notAuthorized)
            }
            return .failure(.scriptFailed(message))
        }

        let raw = result.stringValue ?? ""
        let paths = Array(Self.parsePathList(raw).prefix(Self.capacity))
        let entries = paths.map { path -> FinderFolderEntry in
            let standardized = (path as NSString).standardizingPath
            let name = (standardized as NSString).lastPathComponent
            let display = name.isEmpty ? standardized : name
            switch presence.inspect(path: standardized) {
            case .directory(let isReachable):
                if isReachable {
                    return FinderFolderEntry(
                        path: standardized,
                        displayName: display,
                        isAvailable: true
                    )
                }
                return FinderFolderEntry(
                    path: standardized,
                    displayName: display,
                    isAvailable: false,
                    unavailableMessage: PathResolutionFailure.unreachable.userMessage
                )
            case .missing:
                return FinderFolderEntry(
                    path: standardized,
                    displayName: display,
                    isAvailable: false,
                    unavailableMessage: PathResolutionFailure.notFound.userMessage
                )
            case .file:
                return FinderFolderEntry(
                    path: standardized,
                    displayName: display,
                    isAvailable: false,
                    unavailableMessage: PathResolutionFailure.notDirectory.userMessage
                )
            case .unmountedVolume:
                return FinderFolderEntry(
                    path: standardized,
                    displayName: display,
                    isAvailable: false,
                    unavailableMessage: PathResolutionFailure.unmounted.userMessage
                )
            }
        }
        return .success(entries)
    }

    /// 解析脚本输出：一行一个 path，去重保序。
    public static func parsePathList(_ raw: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = (trimmed as NSString).standardizingPath
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }
}
