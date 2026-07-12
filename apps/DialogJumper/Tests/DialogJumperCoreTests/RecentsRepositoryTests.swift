import DialogJumperCore
import Foundation
import Testing

private struct StubPresence: DirectoryPresenceReading {
    var table: [String: PathFileInspection]

    func inspect(path: String) -> PathFileInspection {
        table[path] ?? .missing
    }
}

struct RecentsRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_100)
    private let t2 = Date(timeIntervalSince1970: 1_700_000_200)

    @Test func recordWritesAndListsLastUsedFirst() {
        let store = InMemoryRecentsStore()
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
            "/Users/a/Desktop": .directory(isReachable: true),
        ])
        let repo = RecentsRepository(store: store, presence: presence)

        repo.record(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t0)
        repo.record(url: URL(fileURLWithPath: "/Users/a/Desktop", isDirectory: true), at: t1)

        let list = repo.list()
        #expect(list.map(\.path) == ["/Users/a/Desktop", "/Users/a/Docs"])
        #expect(list.map(\.displayName) == ["Desktop", "Docs"])
        #expect(list.allSatisfy { $0.isAvailable })
    }

    @Test func pathDedupeRefreshesTimestampAndPromotes() {
        let store = InMemoryRecentsStore()
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
            "/Users/a/Code": .directory(isReachable: true),
        ])
        let repo = RecentsRepository(store: store, presence: presence)

        repo.record(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t0)
        repo.record(url: URL(fileURLWithPath: "/Users/a/Code", isDirectory: true), at: t1)
        repo.record(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t2)

        let list = repo.list()
        #expect(list.count == 2)
        #expect(list.map(\.path) == ["/Users/a/Docs", "/Users/a/Code"])
        #expect(list[0].folder.lastUsedAt == t2)
    }

    @Test func capacityCapsAtTenDroppingOldest() {
        let store = InMemoryRecentsStore()
        var table: [String: PathFileInspection] = [:]
        for i in 0..<12 {
            table["/tmp/r\(i)"] = .directory(isReachable: true)
        }
        let repo = RecentsRepository(store: store, presence: StubPresence(table: table))

        for i in 0..<12 {
            let date = Date(timeIntervalSince1970: Double(i))
            repo.record(url: URL(fileURLWithPath: "/tmp/r\(i)", isDirectory: true), at: date)
        }

        let list = repo.list()
        #expect(list.count == RecentsRepository.capacity)
        #expect(list.first?.path == "/tmp/r11")
        #expect(list.last?.path == "/tmp/r2")
        #expect(!list.contains(where: { $0.path == "/tmp/r0" || $0.path == "/tmp/r1" }))
    }

    @Test func unavailableItemsStayVisibleWithReason() {
        let store = InMemoryRecentsStore(folders: [
            RecentFolder(path: "/gone", lastUsedAt: t1),
            RecentFolder(path: "/ok", lastUsedAt: t0),
            RecentFolder(path: "/Volumes/Missing/X", lastUsedAt: Date(timeIntervalSince1970: 50)),
        ])
        let presence = StubPresence(table: [
            "/ok": .directory(isReachable: true),
            "/Volumes/Missing/X": .unmountedVolume,
        ])
        let repo = RecentsRepository(store: store, presence: presence)

        let list = repo.list()
        #expect(list.count == 3)

        #expect(list[0].path == "/gone")
        #expect(list[0].isAvailable == false)
        #expect(list[0].availability == .unavailable(.notFound))
        #expect(list[0].unavailableMessage == PathResolutionFailure.notFound.userMessage)

        #expect(list[1].path == "/ok")
        #expect(list[1].isAvailable)

        #expect(list[2].availability == .unavailable(.unmounted))
    }

    @Test func persistsAcrossRepositoryRelaunch() {
        let suiteName = "dialogJumper.tests.recents.\(UUID().uuidString)"
        let storeDefaults = UserDefaults(suiteName: suiteName)!
        defer { storeDefaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsRecentsStore(defaults: storeDefaults)
        let presence = StubPresence(table: [
            "/Users/a/Docs": .directory(isReachable: true),
        ])

        let writer = RecentsRepository(store: store, presence: presence)
        writer.record(url: URL(fileURLWithPath: "/Users/a/Docs", isDirectory: true), at: t1)

        let reader = RecentsRepository(
            store: UserDefaultsRecentsStore(defaults: storeDefaults),
            presence: presence
        )
        let list = reader.list()
        #expect(list.map(\.path) == ["/Users/a/Docs"])
        #expect(list[0].folder.lastUsedAt == t1)
    }

    @Test func displayNameIsFolderNameNotFullPath() {
        let folder = RecentFolder(path: "/Users/a/Projects/dialog-jumper", lastUsedAt: t0)
        #expect(folder.displayName == "dialog-jumper")
    }

    @Test func doesNotTreatFilesAsRecentFoldersWhenProbing() {
        let store = InMemoryRecentsStore(folders: [
            RecentFolder(path: "/Users/a/file.txt", lastUsedAt: t0),
        ])
        let presence = StubPresence(table: [
            "/Users/a/file.txt": .file,
        ])
        let repo = RecentsRepository(store: store, presence: presence)
        let list = repo.list()
        #expect(list.count == 1)
        #expect(list[0].availability == .unavailable(.notDirectory))
        #expect(list[0].isAvailable == false)
    }
}
