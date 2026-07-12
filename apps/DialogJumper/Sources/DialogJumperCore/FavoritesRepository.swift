import Foundation

/// One user-pinned Favorite Folder. Order is explicit (array index), not last-used.
///
/// Residual: identity/dedupe is path-based (`standardizingPath`). `bookmarkData`
/// is legacy/optional in the Codable shape; new adds store path only (same trust
/// model as Recents). No Finder sidebar sync; no security-scoped access.
public struct FavoriteFolder: Codable, Equatable, Sendable {
    public let path: String
    public let bookmarkData: Data?
    public let addedAt: Date

    public init(path: String, bookmarkData: Data? = nil, addedAt: Date) {
        self.path = path
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
    }

    /// 文件夹名（路径最后一段）；根路径退回 path 本身。
    public var displayName: String {
        let name = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
        return name.isEmpty ? path : name
    }
}

/// Availability for Favorites list display / click gate.
public enum FavoriteAvailability: Equatable, Sendable {
    case available
    case unavailable(PathResolutionFailure)
}

/// List row: favorite + live availability probe result.
public struct FavoriteFolderEntry: Equatable, Sendable {
    public let folder: FavoriteFolder
    public let availability: FavoriteAvailability
    /// Path used for display/jump after optional bookmark resolve.
    public let resolvedPath: String

    public init(folder: FavoriteFolder, availability: FavoriteAvailability, resolvedPath: String) {
        self.folder = folder
        self.availability = availability
        self.resolvedPath = resolvedPath
    }

    public var path: String { resolvedPath }
    public var displayName: String {
        let name = URL(fileURLWithPath: resolvedPath, isDirectory: true).lastPathComponent
        return name.isEmpty ? resolvedPath : name
    }

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

public enum FavoriteAddResult: Equatable, Sendable {
    case added
    case alreadyPresent
    case atCapacity
    /// 仅语法级拒绝（空 / 不像 path）；不因「此刻不存在」拒绝。
    case invalid(PathResolutionFailure)
}

/// Persistence seam for Favorites (tests inject memory; app uses UserDefaults).
public protocol FavoritesPersisting: Sendable {
    func load() -> [FavoriteFolder]
    func save(_ folders: [FavoriteFolder])
}

/// In-memory store for unit tests.
public final class InMemoryFavoritesStore: FavoritesPersisting, @unchecked Sendable {
    private var folders: [FavoriteFolder]

    public init(folders: [FavoriteFolder] = []) {
        self.folders = folders
    }

    public func load() -> [FavoriteFolder] { folders }

    public func save(_ folders: [FavoriteFolder]) {
        self.folders = folders
    }
}

/// UserDefaults JSON — survives relaunch; stores optional bookmark blobs.
public final class UserDefaultsFavoritesStore: FavoritesPersisting, @unchecked Sendable {
    public static let defaultKey = "dialogJumper.favoriteFolders"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [FavoriteFolder] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FavoriteFolder].self, from: data)) ?? []
    }

    public func save(_ folders: [FavoriteFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Product Favorites: explicit order, path dedupe, soft capacity, availability on list.
///
/// Never silently deletes unavailable entries. No Finder sidebar import/export.
public final class FavoritesRepository: @unchecked Sendable {
    /// Soft cap so persistence stays small; not required by MVP spec.
    public static let capacity = 40

    private let store: any FavoritesPersisting
    private let presence: any DirectoryPresenceReading
    private var cache: [FavoriteFolder]

    public init(
        store: any FavoritesPersisting = UserDefaultsFavoritesStore(),
        presence: any DirectoryPresenceReading = FileManagerDirectoryPresenceReader()
    ) {
        self.store = store
        self.presence = presence
        self.cache = Self.normalized(store.load())
    }

    /// Whether a standardized path is already pinned.
    public func contains(path: String) -> Bool {
        let key = Self.canonicalPathString(path)
        return cache.contains { Self.samePath($0.path, key) }
    }

    /// Explicit add. Trust path like Recents.record — no FS probe, no bookmark.
    /// Existence is only checked on `list()` / Jump (same as Recents).
    @discardableResult
    public func add(url: URL, at date: Date = Date()) -> FavoriteAddResult {
        appendTrustedPath(Self.canonicalPath(url), at: date)
    }

    /// Explicit add from raw path: expand ~ / standardize only; no directory probe.
    @discardableResult
    public func add(
        rawPath: String,
        at date: Date = Date(),
        homeDirectoryPath: String = NSHomeDirectory()
    ) -> FavoriteAddResult {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .invalid(.empty)
        }
        guard PathResolver.looksLikePath(trimmed) else {
            return .invalid(.notPath)
        }
        let expanded = PathResolver.expandTilde(trimmed, homeDirectoryPath: homeDirectoryPath)
        let path = Self.canonicalPathString(expanded)
        guard path.hasPrefix("/") else {
            return .invalid(.notPath)
        }
        return appendTrustedPath(path, at: date)
    }

    private func appendTrustedPath(_ path: String, at date: Date) -> FavoriteAddResult {
        if cache.contains(where: { Self.samePath($0.path, path) }) {
            return .alreadyPresent
        }
        if cache.count >= Self.capacity {
            return .atCapacity
        }
        cache.append(FavoriteFolder(path: path, bookmarkData: nil, addedAt: date))
        store.save(cache)
        return .added
    }

    public func remove(path: String) {
        let key = Self.canonicalPathString(path)
        let before = cache.count
        cache.removeAll { Self.samePath($0.path, key) || Self.samePath(Self.resolvedPath(for: $0), key) }
        if cache.count != before {
            store.save(cache)
        }
    }

    /// Move item earlier in user order (toward top of list).
    public func moveUp(path: String) {
        let key = Self.canonicalPathString(path)
        guard let index = cache.firstIndex(where: {
            Self.samePath($0.path, key) || Self.samePath(Self.resolvedPath(for: $0), key)
        }), index > 0 else { return }
        cache.swapAt(index, index - 1)
        store.save(cache)
    }

    /// Move item later in user order (toward bottom of list).
    public func moveDown(path: String) {
        let key = Self.canonicalPathString(path)
        guard let index = cache.firstIndex(where: {
            Self.samePath($0.path, key) || Self.samePath(Self.resolvedPath(for: $0), key)
        }), index < cache.count - 1 else { return }
        cache.swapAt(index, index + 1)
        store.save(cache)
    }

    /// List in user order with live availability; unavailable stay visible.
    public func list() -> [FavoriteFolderEntry] {
        cache = Self.normalized(store.load())
        return cache.map { folder in
            let path = Self.resolvedPath(for: folder)
            return FavoriteFolderEntry(
                folder: folder,
                availability: Self.probe(path: path, presence: presence),
                resolvedPath: path
            )
        }
    }

    // MARK: - Helpers

    private static func probe(
        path: String,
        presence: any DirectoryPresenceReading
    ) -> FavoriteAvailability {
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

    /// Keep user order; drop only true path duplicates (first wins).
    private static func normalized(_ folders: [FavoriteFolder]) -> [FavoriteFolder] {
        var seen = Set<String>()
        var result: [FavoriteFolder] = []
        for folder in folders {
            let key = (folder.path as NSString).standardizingPath
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(
                FavoriteFolder(
                    path: key,
                    bookmarkData: folder.bookmarkData,
                    addedAt: folder.addedAt
                )
            )
            if result.count == capacity { break }
        }
        return result
    }

    private static func resolvedPath(for folder: FavoriteFolder) -> String {
        // 主键是 path；遗留 bookmark 忽略，避免 resolve 再触发 TCC。
        _ = folder.bookmarkData
        return (folder.path as NSString).standardizingPath
    }

    private static func canonicalPath(_ url: URL) -> String {
        (url.path as NSString).standardizingPath
    }

    private static func canonicalPathString(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func samePath(_ a: String, _ b: String) -> Bool {
        (a as NSString).standardizingPath == (b as NSString).standardizingPath
    }
}
