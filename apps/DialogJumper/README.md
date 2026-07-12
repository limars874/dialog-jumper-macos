# Dialog Jumper (macOS)

MVP product code. Spec: `../../.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## Run (ticket 01 shell)

```bash
cd apps/DialogJumper
swift run DialogJumper
```

Menu bar item: **DJ** (ready) or **DJ!** (Accessibility paused).

- Open Accessibility Settings…
- Recheck Accessibility

Does not request Input Monitoring, Automation, or Full Disk Access.

## Test

```bash
swift test
```
