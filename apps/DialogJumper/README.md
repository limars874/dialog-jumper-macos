# Dialog Jumper (macOS)

MVP product code. Spec: `../../.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## Run

```bash
cd apps/DialogJumper
swift run DialogJumper
```

Menu bar:

- **DJ** — Accessibility ready, no eligible File Dialog
- **DJ!** — Accessibility paused
- **DJ●** — eligible standard File Dialog detected

Menu:

- Accessibility + File Dialog status lines
- **Jump to Path…** (enabled when `DJ●`) — absolute or `~` path; navigates dialog only
- Last jump summary

## Test

```bash
swift test
swift build
```

## Manual Path jump (TextEdit)

1. Enable Dialog Jumper under System Settings → Privacy & Security → Accessibility.
2. `swift run DialogJumper`
3. Open TextEdit → File → Open…
4. When menu bar shows `DJ●`, choose **Jump to Path…**
5. Enter `/Library/Application Support` (space in path) → Jump
6. Confirm the Open panel is at that folder; Open is **not** pressed for you.

## Tickets done

- 01 Accessibility gate
- 02 File Dialog detection
- 03 Path Input → Folder Jump
