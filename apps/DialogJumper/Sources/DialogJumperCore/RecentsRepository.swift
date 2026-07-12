import Foundation

/// One product-owned Recent Folder (path identity + last-used).
public struct RecentFolder: Codable, Equatable, Sendable {
    public let path: String
    public let lastUsedAt: Date

    public init(path: String, lastUsedAt: Date) {
        self.path = path
        self.lastUsedAt = lastUsedAt
    }

    /// 文件夹名（路径最后一段）；根路径退回 path 本身。
    public var displayName: String {
        let name = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
        return name.isEmpty ? path : name
    }
}

/// Availability for list display / click gate.
public enum RecentAvailability: Equatable, Sendable {
    case available
    case unavailable(PathResolutionFailure)
}

/// List row: folder + live availability probe result.
public struct RecentFolderEntry: Equatable, Sendable {
    public let folder: RecentFolder
    public let availability: RecentAvailability

    public init(folder: RecentFolder, availability: RecentAvailability) {
        self.folder = folder
        self.availability = availability
    }

    public var path: String { folder.path }
    public var displayName: String { folder.displayName }

    public var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    public var unavailableMessage: String? {
        if case .unavailable(let reason) = availability {
            return reason.userMessage
        }
        return nil
    }
}

/// Persistence seam for Recents (tests inject memory; app uses UserDefaults).
public protocol RecentsPersisting: Sendable {
    func load() -> [RecentFolder]
    func save(_ folders: [RecentFolder])
}

/// In-memory store for unit tests.
public final class InMemoryRecentsStore: RecentsPersisting, @unchecked Sendable {
    private var folders: [RecentFolder]

    public init(folders: [RecentFolder] = []) {
        self.folders = folders
    }

    public func load() -> [RecentFolder] { folders }

    public func save(_ folders: [RecentFolder]) {
        self.folders = folders
    }
}

/// UserDefaults JSON — survives relaunch, no Application Support bootstrap needed.
public final class UserDefaultsRecentsStore: RecentsPersisting, @unchecked Sendable {
    public static let defaultKey = "dialogJumper.recentFolders"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [RecentFolder] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentFolder].self, from: data)) ?? []
    }

    public func save(_ folders: [RecentFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Product Recents: ≤10, last-used desc, path dedupe, availability on list.
///
/// Writes on successful Folder Jump (Open/Save landing observation is best-effort later).
public final class RecentsRepository: @unchecked Sendable {
    public static let capacity = 10

    private let store: any RecentsPersisting
    private let presence: any DirectoryPresenceReading
    private var cache: [RecentFolder]

    public init(
        store: any RecentsPersisting = UserDefaultsRecentsStore(),
        presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader()
    ) {
        self.store = store
        self.presence = presence
        self.cache = Self.normalized(store.load())
    }

    /// Record a successful jump target; dedupe by path and refresh last-used.
    public func record(url: URL, at date: Date = Date()) {
        let path = Self.canonicalPath(url)
        cache.removeAll { Self.samePath($0.path, path) }
        cache.append(RecentFolder(path: path, lastUsedAt: date))
        cache = Self.normalized(cache)
        store.save(cache)
    }

    /// List ≤10 last-used desc, each with a live availability probe.
    public func list() -> [RecentFolderEntry] {
        cache = Self.normalized(store.load())
        return cache.map { folder in
            RecentFolderEntry(folder: folder, availability: Self.probe(path: folder.path, presence: presence))
        }
    }

    // MARK: - Pure helpers (testable via repository behavior)

    private static func probe(
        path: String,
        presence: any DirectoryPresenceReading
    ) -> RecentAvailability {
        switch presence.inspect(path: path) {
        case .directory(let isReachable):
            return isReachable ? .available : .unavailable(.unreachable)
        case .missing:
            return .unavailable(.notFound)
        case .file:
            return .unavailable(.notDirectory)
        case .unmountedVolume:
            return .unavailable(.unmounted)
        }
    }

    private static func normalized(_ folders: [RecentFolder]) -> [RecentFolder] {
        var seen = Set<String>()
        var deduped: [RecentFolder] = []
        // Prefer newer lastUsedAt when duplicate paths appear in raw store.
        let ordered = folders.sorted { $0.lastUsedAt > $1.lastUsedAt }
        for folder in ordered {
            let key = (folder.path as NSString).standardizingPath
            if seen.contains(key) { continue }
            seen.insert(key)
            deduped.append(RecentFolder(path: key, lastUsedAt: folder.lastUsedAt))
            if deduped.count == capacity { break }
        }
        return deduped
    }

    private static func canonicalPath(_ url: URL) -> String {
        (url.path as NSString).standardizingPath
    }

    private static func samePath(_ a: String, _ b: String) -> Bool {
        (a as NSString).standardizingPath == (b as NSString).standardizingPath
    }
}
