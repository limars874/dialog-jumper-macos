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
}
