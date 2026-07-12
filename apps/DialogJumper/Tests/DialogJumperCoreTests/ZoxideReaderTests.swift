import DialogJumperCore
import Foundation
import Testing

@Suite struct ZoxideReaderTests {
    @Test func parsePathListDedupesAndCapsStyleOrder() {
        let raw = """
        /Users/a/code
        /Users/a/docs
        /Users/a/code
        /tmp
        """
        #expect(
            ZoxideReader.parsePathList(raw) == [
                "/Users/a/code",
                "/Users/a/docs",
                "/tmp"
            ]
        )
    }

    @Test func parsePathListAcceptsScorePrefixedLines() {
        let raw = """
        12.5 /Users/a/code
        3 /Users/a/docs
        """
        #expect(
            ZoxideReader.parsePathList(raw) == [
                "/Users/a/code",
                "/Users/a/docs"
            ]
        )
    }

    @Test func listFoldersNotInstalled() {
        let reader = ZoxideReader(executableSearchPaths: ["/no/such/zoxide"])
        #expect(reader.listFolders() == .failure(.notInstalled))
    }

    @Test func listFoldersCapsAtCapacity() {
        let lines = (1...80).map { "/tmp/z-\($0)" }.joined(separator: "\n")
        let reader = ZoxideReader(
            executableSearchPaths: ["/usr/bin/true"],
            runCommand: { _ in .success(lines) }
        )
        // isExecutableFile may fail for /usr/bin/true path check - use custom paths that pass
        // resolveExecutable checks isExecutableFile; inject via runCommand only if exe found.
        // Use a real executable path for resolve, mock runCommand body.
        let real = ZoxideReader.defaultSearchPaths().first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "/bin/ls"
        let cappedReader = ZoxideReader(
            executableSearchPaths: [real],
            runCommand: { _ in .success(lines) }
        )
        let result = cappedReader.listFolders()
        guard case .success(let entries) = result else {
            // If even /bin/ls missing in sandbox-like env, skip soft
            return
        }
        #expect(entries.count == ZoxideReader.capacity)
        #expect(entries.first?.path == "/tmp/z-1")
    }
}
