import DialogJumperCore
import Testing

struct FileDialogFingerprintTests {
    @Test func openPanelIdentifierIsEligible() {
        let score = FileDialogFingerprint.score(
            FileDialogWindowSignals(role: "AXWindow", subrole: "AXSystemDialog", identifier: "OpenPanel")
        )
        #expect(score.isEligible)
        #expect(score.panelKind == .open)
        #expect(score.points >= FileDialogFingerprint.minimumEligibleScore)
    }

    @Test func savePanelIdentifierIsEligible() {
        let score = FileDialogFingerprint.score(
            FileDialogWindowSignals(role: "AXWindow", subrole: "AXSystemDialog", identifier: "SavePanel")
        )
        #expect(score.isEligible)
        #expect(score.panelKind == .save)
    }

    @Test func systemDialogWindowWithoutIdIsEligible() {
        let score = FileDialogFingerprint.score(
            FileDialogWindowSignals(role: "AXWindow", subrole: "AXSystemDialog", identifier: "")
        )
        #expect(score.isEligible)
        #expect(score.points == 2)
    }

    @Test func englishTitleAloneIsNotEligible() {
        // Negative sample: custom / Electron-like window with only a title.
        let score = FileDialogFingerprint.score(
            FileDialogWindowSignals(role: "AXWindow", subrole: "", identifier: "", title: "Open")
        )
        #expect(!score.isEligible)
        #expect(score.points == 0)
    }

    @Test func plainDialogSubroleAloneIsBelowThreshold() {
        let score = FileDialogFingerprint.score(
            FileDialogWindowSignals(role: "AXWindow", subrole: "AXDialog", identifier: "")
        )
        #expect(!score.isEligible)
        #expect(score.points == 1)
    }

    @Test func panelServiceBundleHeuristic() {
        #expect(
            FileDialogFingerprint.isOpenAndSavePanelService(
                bundleIdentifier: "com.apple.appkit.xpc.openAndSavePanelService"
            )
        )
        #expect(
            !FileDialogFingerprint.isOpenAndSavePanelService(
                bundleIdentifier: "com.microsoft.VSCode"
            )
        )
    }

    @Test func detectionMenuTitles() {
        #expect(
            FileDialogDetectionState.accessibilityPaused.menuTitle.contains("paused")
        )
        #expect(
            FileDialogDetectionState.none.menuTitle.contains("none")
        )
        let eligible = FileDialogDetectionState.eligible(
            EligibleFileDialog(panelPID: 1, hostName: "TextEdit", panelKind: .open, score: 5, reasons: [])
        )
        #expect(eligible.menuTitle.contains("detected"))
        #expect(eligible.menuTitle.contains("TextEdit"))
    }
}
