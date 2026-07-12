# Dialog Jumper (macOS)

MVP product code. Spec: `../../.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## Run

Prefer the signed bundle (stable GUI + Accessibility identity):

```bash
./scripts/run-dev-app.sh
```

Bare `swift run DialogJumper` may work for compile checks but is not the preferred TCC identity path.

Menu bar:

- **DJ** — Accessibility ready, no eligible File Dialog
- **DJ!** — Accessibility paused
- **DJ●** — eligible standard File Dialog detected

Menu:

- Accessibility + File Dialog status lines
- **Focus Path on Toolbar…** when eligible
- **Recheck Accessibility** (no prompt storm) / Open Settings / Request / Relaunch
- Last jump summary

## Test

```bash
swift test
swift build
```

## Manual Path jump (TextEdit)

1. Enable Dialog Jumper under System Settings → Privacy & Security → Accessibility.
2. `./scripts/run-dev-app.sh`
3. Open TextEdit → File → Open…
4. When menu bar shows `DJ●`, use the side toolbar Path field (or menu Focus Path).
5. Enter `/Library/Application Support` (space in path) → Jump
6. Confirm the Open panel is at that folder; Open is **not** pressed for you.

## Support-matrix pack

Minimal lab acceptance + PASS/REQ honesty:

`../../.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`

## Tickets

- 01–06 done (shell, detection, path jump, toolbar, recents, favorites)
- 07 cancelled (no global shortcut)
- 08 done (runtime failure / revoke recovery)
- 09 done (support-matrix MVP pack)
