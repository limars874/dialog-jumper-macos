import DialogJumperCore
import Testing

@Suite struct FinderWindowsReaderTests {
    @Test func parsePathListDedupesAndPreservesOrder() {
        let raw = """
        /Users/a/Documents
        /Users/a/Downloads
        /Users/a/Documents
        /Users/a/Desktop
        """
        #expect(
            FinderWindowsReader.parsePathList(raw) == [
                "/Users/a/Documents",
                "/Users/a/Downloads",
                "/Users/a/Desktop"
            ]
        )
    }

    @Test func parsePathListIgnoresBlankLines() {
        #expect(FinderWindowsReader.parsePathList("\n\n/tmp\n\n").count == 1)
        #expect(FinderWindowsReader.parsePathList("").isEmpty)
    }

    @Test func parseThenCapAtCapacity() {
        let lines = (1...80).map { "/tmp/folder-\($0)" }.joined(separator: "\n")
        let parsed = FinderWindowsReader.parsePathList(lines)
        #expect(parsed.count == 80)
        let capped = Array(parsed.prefix(FinderWindowsReader.capacity))
        #expect(capped.count == FinderWindowsReader.capacity)
        #expect(capped.first == "/tmp/folder-1")
        #expect(capped.last == "/tmp/folder-50")
    }
}
