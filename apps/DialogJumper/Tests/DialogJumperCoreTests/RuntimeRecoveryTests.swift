import DialogJumperCore
import Testing

struct RuntimeRecoveryTests {
    @Test func coldStartPausedIsNotRevoked() {
        let t = AccessibilityGate.applyTrustChange(
            previous: .paused,
            isProcessTrusted: false,
            hadBeenReady: false
        )
        #expect(t.authorization == .paused)
        #expect(!t.hadBeenReady)
        #expect(!t.justRevoked)
        #expect(!t.isRevokedPresentation)
        #expect(AccessibilityGate.statusTitle(t.authorization, revoked: false).contains("Paused"))
        #expect(!AccessibilityGate.statusTitle(t.authorization, revoked: false)
            .localizedCaseInsensitiveContains("revoked"))
    }

    @Test func readyToPausedMarksJustRevoked() {
        let t = AccessibilityGate.applyTrustChange(
            previous: .ready,
            isProcessTrusted: false,
            hadBeenReady: true
        )
        #expect(t.authorization == .paused)
        #expect(t.hadBeenReady)
        #expect(t.justRevoked)
        #expect(t.isRevokedPresentation)
        #expect(AccessibilityGate.statusTitle(.paused, revoked: true).contains("Revoked"))
        #expect(AccessibilityGate.folderJumpMenuTitle(
            authorization: .paused,
            revoked: true,
            hasEligibleDialog: false
        ).contains("revoked"))
    }

    @Test func secondPausedPollIsNotJustRevokedAgain() {
        // After the edge, subsequent polls stay paused without re-firing justRevoked.
        let t = AccessibilityGate.applyTrustChange(
            previous: .paused,
            isProcessTrusted: false,
            hadBeenReady: true
        )
        #expect(t.authorization == .paused)
        #expect(t.hadBeenReady)
        #expect(!t.justRevoked)
        #expect(t.isRevokedPresentation)
    }

    @Test func pausedToReadyClearsRevokedPresentation() {
        let t = AccessibilityGate.applyTrustChange(
            previous: .paused,
            isProcessTrusted: true,
            hadBeenReady: true
        )
        #expect(t.authorization == .ready)
        #expect(t.hadBeenReady)
        #expect(!t.justRevoked)
        #expect(!t.isRevokedPresentation)
        #expect(AccessibilityGate.statusTitle(.ready, revoked: false) == "Accessibility: Ready")
        #expect(AccessibilityGate.isFolderJumpEnabled(.ready))
    }

    @Test func firstReadyFromColdStart() {
        let t = AccessibilityGate.applyTrustChange(
            previous: .paused,
            isProcessTrusted: true,
            hadBeenReady: false
        )
        #expect(t.authorization == .ready)
        #expect(t.hadBeenReady)
        #expect(!t.justRevoked)
    }

    @Test func revokeAlertMentionsSettingsAndRecheck() {
        let msg = AccessibilityGate.revokeAlertMessage()
        #expect(msg.localizedCaseInsensitiveContains("accessibility"))
        #expect(msg.localizedCaseInsensitiveContains("settings"))
        #expect(msg.localizedCaseInsensitiveContains("recheck"))
    }

    @Test func jumpFailureCopyIsRecoveryOriented() {
        #expect(FolderJumpFailure.noEligibleDialog.userMessage.localizedCaseInsensitiveContains("standard"))
        #expect(FolderJumpFailure.noEligibleDialog.alertTitle.localizedCaseInsensitiveContains("standard"))
        #expect(FolderJumpFailure.dialogLost.userMessage.localizedCaseInsensitiveContains("nothing was submitted"))
        #expect(FolderJumpFailure.dialogLost.toolbarStatus.localizedCaseInsensitiveContains("lost"))
        #expect(FolderJumpFailure.accessibilityPaused.userMessage.localizedCaseInsensitiveContains("settings"))
        #expect(FolderJumpFailure.accessibilityPaused.alertTitle.localizedCaseInsensitiveContains("paused"))
        #expect(FolderJumpFailure.verificationFailed.toolbarStatus.localizedCaseInsensitiveContains("retry"))
    }

    @Test func folderJumpMenuTitlesDistinguishStates() {
        #expect(
            AccessibilityGate.folderJumpMenuTitle(
                authorization: .paused,
                revoked: false,
                hasEligibleDialog: false
            ).localizedCaseInsensitiveContains("paused")
        )
        #expect(
            AccessibilityGate.folderJumpMenuTitle(
                authorization: .ready,
                revoked: false,
                hasEligibleDialog: true,
                hostSummary: "TextEdit · Open"
            ).contains("ready")
        )
        #expect(
            AccessibilityGate.folderJumpMenuTitle(
                authorization: .ready,
                revoked: false,
                hasEligibleDialog: true,
                hostSummary: "TextEdit · Open"
            ).contains("TextEdit")
        )
        let waiting = AccessibilityGate.folderJumpMenuTitle(
            authorization: .ready,
            revoked: false,
            hasEligibleDialog: false
        )
        #expect(waiting.localizedCaseInsensitiveContains("waiting"))
        #expect(!waiting.localizedCaseInsensitiveContains("panelServices"))
    }
}
