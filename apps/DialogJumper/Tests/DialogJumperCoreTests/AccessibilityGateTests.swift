import DialogJumperCore
import Testing

struct AccessibilityGateTests {
    @Test func trustedMapsToReady() {
        let auth = AccessibilityGate.authorization(isProcessTrusted: true)
        #expect(auth == .ready)
        #expect(AccessibilityGate.isFolderJumpEnabled(auth))
        #expect(AccessibilityGate.statusTitle(auth) == "Accessibility: Ready")
        #expect(AccessibilityGate.shortMenuBarTitle(auth) == "DJ")
    }

    @Test func untrustedMapsToPausedNotAuthorized() {
        let auth = AccessibilityGate.authorization(isProcessTrusted: false)
        #expect(auth == .paused)
        #expect(!AccessibilityGate.isFolderJumpEnabled(auth))
        #expect(AccessibilityGate.statusTitle(auth).contains("Paused"))
        #expect(!AccessibilityGate.statusTitle(auth).localizedCaseInsensitiveContains("authorized"))
        #expect(AccessibilityGate.shortMenuBarTitle(auth) == "DJ!")
    }

    @Test func settingsLinkIsAccessibilityPrivacy() {
        let url = AccessibilitySettingsLink.privacyAccessibilityURL
        #expect(url.absoluteString.contains("Privacy_Accessibility"))
    }
}
