import DialogJumperCore
import Foundation
import Testing

private struct StubPresence: DirectoryPresenceReading {
    var table: [String: PathFileInspection]

    func inspect(path: String) -> PathFileInspection {
        table[path] ?? .missing
    }
}

struct PathResolverTests {
    private let home = "/Users/tester"

    @Test func emptyInputFails() {
        let result = PathResolver.resolve("   ", homeDirectoryPath: home, presence: StubPresence(table: [:]))
        #expect(result == .failed(.empty))
    }

    @Test func freeTextIsNotPathAndNeverSearch() {
        let samples = ["Documents", "Application Support", "foo bar", "search query"]
        for sample in samples {
            let result = PathResolver.resolve(sample, homeDirectoryPath: home, presence: StubPresence(table: [:]))
            #expect(result == .failed(.notPath), "expected notPath for \(sample)")
        }
    }

    @Test func tildeExpandsToHome() {
        let presence = StubPresence(table: [
            home: .directory(isReachable: true),
            "\(home)/Library": .directory(isReachable: true),
        ])
        #expect(
            PathResolver.resolve("~", homeDirectoryPath: home, presence: presence)
                == .ok(URL(fileURLWithPath: home, isDirectory: true))
        )
        #expect(
            PathResolver.resolve("~/Library", homeDirectoryPath: home, presence: presence)
                == .ok(URL(fileURLWithPath: "\(home)/Library", isDirectory: true))
        )
    }

    @Test func absolutePathOkWhenDirectoryReachable() {
        let path = "/Library/Application Support"
        let presence = StubPresence(table: [path: .directory(isReachable: true)])
        let result = PathResolver.resolve(path, homeDirectoryPath: home, presence: presence)
        #expect(result == .ok(URL(fileURLWithPath: path, isDirectory: true)))
    }

    @Test func missingPathFailsNotFound() {
        let presence = StubPresence(table: [:])
        let result = PathResolver.resolve("/no/such/folder-xyz", homeDirectoryPath: home, presence: presence)
        #expect(result == .failed(.notFound))
    }

    @Test func fileIsNotDirectory() {
        let path = "/tmp/some-file.txt"
        let presence = StubPresence(table: [path: .file])
        let result = PathResolver.resolve(path, homeDirectoryPath: home, presence: presence)
        #expect(result == .failed(.notDirectory))
    }

    @Test func unreachableDirectoryFails() {
        let path = "/private/var/root-only"
        let presence = StubPresence(table: [path: .directory(isReachable: false)])
        let result = PathResolver.resolve(path, homeDirectoryPath: home, presence: presence)
        #expect(result == .failed(.unreachable))
    }

    @Test func unmountedVolumeFails() {
        let path = "/Volumes/MissingDisk/Projects"
        let presence = StubPresence(table: [path: .unmountedVolume])
        let result = PathResolver.resolve(path, homeDirectoryPath: home, presence: presence)
        #expect(result == .failed(.unmounted))
    }

    @Test func looksLikePathRules() {
        #expect(PathResolver.looksLikePath("/tmp"))
        #expect(PathResolver.looksLikePath("~"))
        #expect(PathResolver.looksLikePath("~/Documents"))
        #expect(!PathResolver.looksLikePath("Documents"))
        #expect(!PathResolver.looksLikePath("~foo"))
    }

    @Test func expandTildeHelpers() {
        #expect(PathResolver.expandTilde("~", homeDirectoryPath: home) == home)
        #expect(PathResolver.expandTilde("~/a/b", homeDirectoryPath: home) == "\(home)/a/b")
        #expect(PathResolver.expandTilde("/abs", homeDirectoryPath: home) == "/abs")
    }

    @Test func failureMessagesAreSpecific() {
        #expect(PathResolutionFailure.notPath.userMessage.contains("not search"))
        #expect(PathResolutionFailure.notFound.userMessage.lowercased().contains("exist"))
        #expect(PathResolutionFailure.unmounted.userMessage.lowercased().contains("mount"))
    }
}

struct FolderJumpGateTests {
    @Test func jumpRequiresReadyAccessibility() {
        let executor = FolderJumpExecutor(
            homeDirectoryPath: "/Users/tester",
            presence: StubPresence(table: ["/tmp": .directory(isReachable: true)])
        )
        let dialog = EligibleFileDialog(panelPID: 1, score: 5, reasons: [])
        let outcome = executor.jump(
            rawPath: "/tmp",
            authorization: .paused,
            dialog: dialog
        )
        #expect(outcome == .failure(.accessibilityPaused))
    }

    @Test func jumpRequiresEligibleDialog() {
        let executor = FolderJumpExecutor(
            homeDirectoryPath: "/Users/tester",
            presence: StubPresence(table: ["/tmp": .directory(isReachable: true)])
        )
        let outcome = executor.jump(
            rawPath: "/tmp",
            authorization: .ready,
            dialog: nil
        )
        #expect(outcome == .failure(.noEligibleDialog))
    }

    @Test func jumpRejectsBadPathBeforeAX() {
        let executor = FolderJumpExecutor(
            homeDirectoryPath: "/Users/tester",
            presence: StubPresence(table: [:])
        )
        let dialog = EligibleFileDialog(panelPID: 1, score: 5, reasons: [])
        let outcome = executor.jump(
            rawPath: "Documents",
            authorization: .ready,
            dialog: dialog
        )
        #expect(outcome == .failure(.path(.notPath)))
    }
}
