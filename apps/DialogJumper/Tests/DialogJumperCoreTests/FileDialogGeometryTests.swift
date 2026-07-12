import DialogJumperCore
import CoreGraphics
import Testing

struct FileDialogGeometryTests {
    @Test func prefersRightWhenSpaceAllows() {
        let dialog = CGRect(x: 100, y: 100, width: 400, height: 300)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let chrome = CGSize(width: 280, height: 132)
        let origin = FileDialogGeometry.sideChromeOrigin(dialog: dialog, chromeSize: chrome, screen: screen)
        #expect(origin.x == dialog.maxX + 8)
        #expect(origin.y == dialog.maxY - chrome.height)
    }

    @Test func fallsBackLeftWhenRightOverflows() {
        let dialog = CGRect(x: 900, y: 100, width: 400, height: 300)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let chrome = CGSize(width: 280, height: 132)
        let origin = FileDialogGeometry.sideChromeOrigin(dialog: dialog, chromeSize: chrome, screen: screen)
        #expect(origin.x == dialog.minX - 8 - chrome.width)
    }
}
