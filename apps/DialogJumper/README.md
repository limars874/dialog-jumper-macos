# Dialog Jumper (macOS)

在系统 **Open / Save** 对话框旁附着侧栏，做 Folder Jump（不代点 Open/Save）。

产品总览与功能列表见仓库根目录 [`README.md`](../../README.md)。  
规格：[`mvp-spec.md`](../../.scratch/macos-file-dialog-jumper/assets/mvp-spec.md)

## 功能摘要

- **Jump**：Path 输入 + 列表点选 → 系统 Go to Folder 链（⇧⌘G…）
- **Rec / Fav / Find / Zox** 四个 path 源（Find=打开的 Finder 窗，Zox=`zoxide query -l`）
- 行：**★** 收藏 · **⎘** 复制 · Favorites **↑↓✕**
- 菜单 **Jump on List Click**（单击是否 Jump；双击始终 Jump）
- 菜单栏 **DJ / DJ! / DJ●**；Accessibility 撤销可恢复

## Run

```bash
./scripts/run-dev-app.sh
```

需要：系统设置 → 隐私与安全性 → **辅助功能**。  
Finder tab 另需 **自动化 → Dialog Jumper 控制 Finder**。  
Zox tab 需要本机已装 **zoxide**（Homebrew / `~/.local/bin` 等）。

`swift run DialogJumper` 仅适合编译检查；TCC 身份以签名 bundle 为准。

## Menu bar

| Glyph | 含义 |
| --- | --- |
| **DJ** | Accessibility ready，无 eligible File Dialog |
| **DJ!** | Accessibility paused / revoked |
| **DJ●** | 已检测到标准 File Dialog |

菜单：状态行 · Focus Path · **Jump on List Click** · Recheck · Settings · Relaunch · About · Quit

## Test

```bash
swift test
swift build
```

## Manual smoke (TextEdit)

1. `./scripts/run-dev-app.sh`，勾选 Accessibility  
2. TextEdit → 打开…  
3. Path：`/Library/Application Support` → Jump（含空格路径）  
4. 确认面板已到该目录，且 **Open 未被代点**  
5. 可选：Zox ↻、Find ↻、Favorites ★  

## Support matrix

[`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`](../../.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md)

## Tickets

- 01–06 / 08 / 09 done  
- 07 cancelled（无全局热键）  
- 后续 polish（列表 UI、Finder、Zoxide、Jump on List Click）已在 `main`
