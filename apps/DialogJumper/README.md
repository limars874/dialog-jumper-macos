# DialogJumper (app package)

SwiftPM sources for the macOS menu bar app.

**User-facing docs:** repository root [README.md](../../README.md) / [README.zh-CN.md](../../README.zh-CN.md)

## Develop

```bash
./scripts/run-dev-app.sh
```

```bash
swift test
swift build
```

## Release zip (local)

```bash
./scripts/package-release.sh
```

Needs **Accessibility** for Jump. Find tab needs **Automation → Finder**. Zox tab needs **zoxide** on the machine.

`swift run DialogJumper` is fine for compile checks; prefer the signed `.app` from `run-dev-app.sh` / package script for real TCC identity.

Do **not** enable Hardened Runtime if you rely on cross-process Accessibility without full entitlements.
