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

Menu lines show Accessibility status and File Dialog detection (`detected` / `none` / `paused`).

## Test

```bash
swift test
```

## Tickets done

- 01 Accessibility gate
- 02 File Dialog detection
```
