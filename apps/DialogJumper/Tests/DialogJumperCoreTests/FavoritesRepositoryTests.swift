import DialogJumperCore
import Foundation
import Testing

private struct StubPresence: DirectoryPresenceReading {
    var table: [String: PathFileInspection]

    func inspect(path: String) -> PathFileInspection {
        table[path] ?? .missing
    }
}

struct FavoritesRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_100)
    private let t2 = Date(timeIntervalSince1970: 1_700_000_200)

    @Test func addPreservesExplicitUserOrder() {
        let store = InMemoryFavoritesStore()
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
            "/Users/a/Desktop": .directory(isReachable: true),
            "/Users/a/Code": .directory(isReachable: true),
        ])
        let repo = FavoritesRepository(store: store, presence: presence)

        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t0) == .added)
        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Desktop", isDirectory: true), at: t1) == .added)
        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Code", isDirectory: true), at: t2) == .added)

        let list = repo.list()
        #expect(list.map(\.path) == [
            "/Users/a/Docs",
            "/Users/a/Desktop",
            "/Users/a/Code",
        ])
        #expect(list.map(\.displayName) == ["Docs", "Desktop", "Code"])
        #expect(list.allSatisfy { $0.isAvailable })
    }

    @Test func pathDedupeRejectsSecondAddWithoutReordering() {
        let store = InMemoryFavoritesStore()
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
            "/Users/a/Code": .directory(isReachable: true),
        ])
        let repo = FavoritesRepository(store: store, presence: presence)

        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t0) == .added)
        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Code", isDirectory: true), at: t1) == .added)
        #expect(repo.add(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t2) == .alreadyPresent)

        let list = repo.list()
        #expect(list.count == 2)
        #expect(list.map(\.path) == ["/Users/a/Docs", "/Users/a/Code"])
        #expect(repo.contains(path: "/Users/a/Docs"))
    }

    @Test func removeDeletesOnlyTargetPreservingOthers() {
        let store = InMemoryFavoritesStore()
        let presence = StubPresence(table: [
            "/a": .directory(isReachable: true),
            "/b": .directory(isReachable: true),
            "/c": .directory(isReachable: true),
        ])
        let repo = FavoritesRepository(store: store, presence: presence)
        _ = repo.add(url: URL(fileURLWithPath: "/a", isDirectory: true), at: t0)
        _ = repo.add(url: URL(fileURLWithPath: "/b", isDirectory: true), at: t1)
        _ = repo.add(url: URL(fileURLWithPath: "/c", isDirectory: true), at: t2)

        repo.remove(path: "/b")
        #expect(repo.list().map(\.path) == ["/a", "/c"])
    }

    @Test func reorderMoveUpAndDown() {
        let store = InMemoryFavoritesStore()
        let presence = StubPresence(table: [
            "/a": .directory(isReachable: true),
            "/b": .directory(isReachable: true),
            "/c": .directory(isReachable: true),
        ])
        let repo = FavoritesRepository(store: store, presence: presence)
        _ = repo.add(url: URL(fileURLWithPath: "/a", isDirectory: true), at: t0)
        _ = repo.add(url: URL(fileURLWithPath: "/b", isDirectory: true), at: t1)
        _ = repo.add(url: URL(fileURLWithPath: "/c", isDirectory: true), at: t2)

        repo.moveUp(path: "/c")
        #expect(repo.list().map(\.path) == ["/a", "/c", "/b"])

        repo.moveDown(path: "/a")
        #expect(repo.list().map(\.path) == ["/c", "/a", "/b"])

        // Edges no-op
        repo.moveUp(path: "/c")
        repo.moveDown(path: "/b")
        #expect(repo.list().map(\.path) == ["/c", "/a", "/b"])
    }

    @Test func unavailableItemsStayVisibleWithReason() {
        let store = InMemoryFavoritesStore(folders: [
            FavoriteFolder(path: "/gone", addedAt: t0),
            FavoriteFolder(path: "/ok", addedAt: t1),
            FavoriteFolder(path: "/Volumes/Missing/X", addedAt: t2),
        ])
        let presence = StubPresence(table: [
            "/ok": .directory(isReachable: true),
            "/Volumes/Missing/X": .unmountedVolume,
        ])
        let repo = FavoritesRepository(store: store, presence: presence)

        let list = repo.list()
        #expect(list.count == 3)
        #expect(list.map(\.path) == ["/gone", "/ok", "/Volumes/Missing/X"])

        #expect(list[0].isAvailable == false)
        #expect(list[0].availability == .unavailable(.notFound))
        #expect(list[0].unavailableMessage == PathResolutionFailure.notFound.userMessage)

        #expect(list[1].isAvailable)
        #expect(list[2].availability == .unavailable(.unmounted))
    }

    @Test func persistsOrderAcrossRepositoryRelaunch() {
        let suiteName = "dialogJumper.tests.favorites.\(UUID().uuidString)"
        let storeDefaults = UserDefaults(suiteName: suiteName)!
        defer { storeDefaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsFavoritesStore(defaults: storeDefaults)
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
            "/Users/a/Code": .directory(isReachable: true),
        ])

        let writer = FavoritesRepository(store: store, presence: presence)
        #expect(writer.add(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t0) == .added)
        #expect(writer.add(url: URL(fileURLWithPath: "/Users/a/Code", isDirectory: true), at: t1) == .added)
        writer.moveUp(path: "/Users/a/Code")

        let reader = FavoritesRepository(
            store: UserDefaultsFavoritesStore(defaults: storeDefaults),
            presence: presence
        )
        #expect(reader.list().map(\.path) == ["/Users/a/Code", "/Users/a/Docs"])
    }

    @Test func capacityRejectsBeyondSoftCap() {
        let store = InMemoryFavoritesStore()
        var table: [String: PathFileInspection] = [:]
        for i in 0..<(FavoritesRepository.capacity + 2) {
            table["/tmp/f\(i)"] = .directory(isReachable: true)
        }
        let repo = FavoritesRepository(store: store, presence: StubPresence(table: table))

        for i in 0..<FavoritesRepository.capacity {
            let result = repo.add(
                url: URL(fileURLWithPath: "/tmp/f\(i)", isDirectory: true),
                at: Date(timeIntervalSince1970: Double(i))
            )
            #expect(result == .added)
        }
        #expect(
            repo.add(
                url: URL(fileURLWithPath: "/tmp/f\(FavoritesRepository.capacity)", isDirectory: true),
                at: t0
            ) == .atCapacity
        )
        #expect(repo.list().count == FavoritesRepository.capacity)
    }

    @Test func addRawPathInvalidWhenMissing() {
        let store = InMemoryFavoritesStore()
        let presence = StubPresence(table: [:])
        let repo = FavoritesRepository(store: store, presence: presence)
        #expect(repo.add(rawPath: "/does/not/exist") == .invalid(.notFound))
        #expect(repo.list().isEmpty)
    }

    @Test func displayNameIsFolderNameNotFullPath() {
        let folder = FavoriteFolder(path: "/Users/a/Projects/dialog-jumper", addedAt: t0)
        #expect(folder.displayName == "dialog-jumper")
    }

    @Test func doesNotTreatFilesAsFavoriteFoldersWhenProbing() {
        let store = InMemoryFavoritesStore(folders: [
            FavoriteFolder(path: "/Users/a/file.txt", addedAt: t0),
        ])
        let presence = StubPresence(table: [
            "/Users/a/file.txt": .file,
        ])
        let repo = FavoritesRepository(store: store, presence: presence)
        let list = repo.list()
        #expect(list.count == 1)
        #expect(list[0].availability == .unavailable(.notDirectory))
        #expect(list[0].isAvailable == false)
    }
}
