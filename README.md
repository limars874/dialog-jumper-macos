# Dialog Jumper

macOS **menu bar** tool for fast **folder navigation** inside **system Open / Save dialogs**.

It attaches a small side panel next to the dialog. You jump by path, recents, favorites, open Finder windows, or [zoxide](https://github.com/ajeetdsouza/zoxide) — and **it never clicks Open or Save for you**.

**中文说明：** [README.zh-CN.md](./README.zh-CN.md)

> Lab / personal-use stage. **Not notarized** (no Apple Developer ID). Gatekeeper will warn on first open.

## Screenshot

<p align="left">
  <img src="https://cdn.jsdelivr.net/gh/limars874/dialog-jumper-macos@main/docs/screenshots/side-chrome.png" alt="Dialog Jumper side chrome" width="320" />
</p>

## Install (from Release)

1. Download the latest **macOS zip** from [Releases](https://github.com/limars874/dialog-jumper-macos/releases)  
   - Current CI builds are **Apple silicon (arm64)** only.
2. Unzip, then open once via **right-click → Open** (or run `xattr -cr DialogJumper.app` in Terminal).
3. System Settings → Privacy & Security → **Accessibility** → enable **Dialog Jumper**.
4. Optional:
   - **Automation** → allow Dialog Jumper to control **Finder** (Find tab)
   - Install **[zoxide](https://github.com/ajeetdsouza/zoxide)** (Zox tab)

## Quick start

1. Launch Dialog Jumper (menu bar shows **DJ** / **DJ!** / **DJ●**).
2. Open a **system** file dialog (e.g. TextEdit → **File → Open…**).
3. In the side panel:
   - Type/paste a path (`/` or `~`) → **Jump**, or  
   - Click a list row, or  
   - **Drag the handle** onto the Open/Save panel (native navigation).
4. Confirm the folder yourself with **Open** / **Save** — Dialog Jumper will not press those buttons.

### Menu bar glyphs

| Glyph | Meaning |
| --- | --- |
| **DJ** | Ready, no file dialog detected |
| **DJ!** | Needs Accessibility (or revoked) |
| **DJ●** | System file dialog detected |

## Features

| Area | What you get |
| --- | --- |
| **Jump** | Go to a folder inside the system dialog without auto-submitting |
| **Path** | Absolute paths and `~`; clear button; drag handle for native drop |
| **Rec** | Last successful jumps in this app (max 10) |
| **Fav** | Pinned folders, reorder / remove (max 40) |
| **Find** | Open Finder window folders (max 50; refresh; needs Automation) |
| **Zox** | `zoxide query -l` list (max 50; refresh; needs zoxide installed) |
| **List actions** | Click / double-click (see **Jump on List Click** in the menu), ★ favorite, copy path, drag handle |
| **Safety** | No auto Open/Save; failures show in the status line |

**Not included (for now):** global hotkeys, fuzzy whole-disk folder search, syncing Finder sidebar favorites, multi-dialog side panels.

## Build from source

```bash
cd apps/DialogJumper
./scripts/run-dev-app.sh
```

```bash
cd apps/DialogJumper && swift test && swift build
```

Dev signing uses a local identity when configured. Do **not** enable Hardened Runtime if you need cross-process Accessibility.

Release zip locally:

```bash
apps/DialogJumper/scripts/package-release.sh
```

Maintainers: tag `v0.0.x` and push to trigger [GitHub Actions](https://github.com/limars874/dialog-jumper-macos/actions) release packaging (ad-hoc sign, not notarized). See [CHANGELOG.md](./CHANGELOG.md).

## Requirements

| Need | For |
| --- | --- |
| macOS 14+ | Running the app |
| Accessibility | Jump |
| Finder Automation | Find tab |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Zox tab |
| Apple silicon build (current Release) | Prebuilt zip from CI |

## License

[MIT](./LICENSE)
