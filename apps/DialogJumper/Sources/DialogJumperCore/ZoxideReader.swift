import Foundation

/// One directory from zoxide frecency DB.
public struct ZoxideFolderEntry: Equatable, Sendable {
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

public enum ZoxideError: Error, Equatable, Sendable {
    case notInstalled
    case commandFailed(String)
}

public protocol ZoxideReading: Sendable {
    /// 按需：`zoxide query -l`，去重保序后 cap。
    func listFolders() -> Result<[ZoxideFolderEntry], ZoxideError>
}

/// 调本机 `zoxide` CLI（菜单栏 app 需自扫常见 install path，不依赖登录 shell PATH）。
public struct ZoxideReader: ZoxideReading {
    public static let capacity = 50

    private let presence: any DirectoryPresenceReading
    private let executableSearchPaths: [String]
    private let runCommand: @Sendable (URL) -> Result<String, ZoxideError>

    public init(
        presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader(),
        executableSearchPaths: [String] = ZoxideReader.defaultSearchPaths(),
        runCommand: (@Sendable (URL) -> Result<String, ZoxideError>)? = nil
    ) {
        self.presence = presence
        self.executableSearchPaths = executableSearchPaths
        self.runCommand = runCommand ?? { url in
            ZoxideReader.executeQueryList(executable: url)
        }
    }

    public static func defaultSearchPaths() -> [String] {
        var paths = [
            "/opt/homebrew/bin/zoxide",
            "/usr/local/bin/zoxide",
            "\(NSHomeDirectory())/.local/bin/zoxide",
            "/usr/bin/zoxide"
        ]
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                paths.append("\(dir)/zoxide")
            }
        }
        return paths
    }

    public func listFolders() -> Result<[ZoxideFolderEntry], ZoxideError> {
        guard let exe = resolveExecutable() else {
            return .failure(.notInstalled)
        }
        switch runCommand(exe) {
        case .failure(let error):
            return .failure(error)
        case .success(let stdout):
            let paths = Array(Self.parsePathList(stdout).prefix(Self.capacity))
            let entries = paths.map { path -> ZoxideFolderEntry in
                Self.makeEntry(path: path, presence: presence)
            }
            return .success(entries)
        }
    }

    public static func parsePathList(_ raw: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // `zoxide query -ls` 可能是 "score path"；只取 path
            let pathPart: String
            if trimmed.first?.isNumber == true, let space = trimmed.firstIndex(of: " ") {
                pathPart = String(trimmed[trimmed.index(after: space)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                pathPart = trimmed
            }
            guard pathPart.hasPrefix("/") || pathPart.hasPrefix("~") else { continue }
            let key = (pathPart as NSString).standardizingPath
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }

    private func resolveExecutable() -> URL? {
        let fm = FileManager.default
        for path in executableSearchPaths {
            let url = URL(fileURLWithPath: path)
            if fm.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func executeQueryList(executable: URL) -> Result<String, ZoxideError> {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["query", "-l"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(.commandFailed(error.localizedDescription))
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .failure(.commandFailed(err.isEmpty ? "zoxide exit \(process.terminationStatus)" : err))
        }
        return .success(stdout)
    }

    private static func makeEntry(
        path: String,
        presence: any DirectoryPresenceReading
    ) -> ZoxideFolderEntry {
        let standardized = (path as NSString).standardizingPath
        let name = (standardized as NSString).lastPathComponent
        let display = name.isEmpty ? standardized : name
        switch presence.inspect(path: standardized) {
        case .directory(let isReachable):
            if isReachable {
                return ZoxideFolderEntry(path: standardized, displayName: display, isAvailable: true)
            }
            return ZoxideFolderEntry(
                path: standardized,
                displayName: display,
                isAvailable: false,
                unavailableMessage: PathResolutionFailure.unreachable.userMessage
            )
        case .missing:
            return ZoxideFolderEntry(
                path: standardized,
                displayName: display,
                isAvailable: false,
                unavailableMessage: PathResolutionFailure.notFound.userMessage
            )
        case .file:
            return ZoxideFolderEntry(
                path: standardized,
                displayName: display,
                isAvailable: false,
                unavailableMessage: PathResolutionFailure.notDirectory.userMessage
            )
        case .unmountedVolume:
            return ZoxideFolderEntry(
                path: standardized,
                displayName: display,
                isAvailable: false,
                unavailableMessage: PathResolutionFailure.unmounted.userMessage
            )
        }
    }
}
