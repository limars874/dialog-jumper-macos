import AppKit
import DialogJumperCore

let app = NSApplication.shared
let delegate = AppDelegate(trustReader: SystemAccessibilityTrustReader())
app.delegate = delegate
app.run()
