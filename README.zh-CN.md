# Dialog Jumper

macOS 菜单栏工具：在**系统标准 Open / Save 对话框**里快速 **Folder Jump**，不替你点 Open/Save。

侧栏附着在 File Dialog 旁，支持 Path 输入、Recents、Favorites、打开的 Finder 窗口、以及 **zoxide** 常用目录。

> Lab / 自用阶段。完整产品规格见  
> [`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`](.scratch/macos-file-dialog-jumper/assets/mvp-spec.md)

**English:** [README.md](./README.md)

## 截图

![Dialog Jumper 侧栏](https://cdn.jsdelivr.net/gh/limars874/dialog-jumper-macos@main/docs/screenshots/side-chrome.png)

附着在系统 Open 对话框旁的侧栏：Path、Jump、Rec / Fav / Find / Zox，以及拖柄 / 收藏 / 复制。

### 30 秒上手
1. 打开 **辅助功能**，勾选 Dialog Jumper。  
2. 打开系统文件对话框（如 TextEdit → **文件 → 打开…**）。  
3. 用 **Path + Jump**、点列表，或 **拖左侧柄** 到对话框（系统原生导航）。  
4. **不会**替你点 Open/Save。  
5. 未公证包：右键 → 打开，或 `xattr -cr DialogJumper.app`。

---

## 功能一览

### 核心 Jump
- 检测 **Open and Save Panel Service** 上的标准系统面板（可见大窗 + AX fingerprint）
- 侧栏 **Path** 输入 `/` 或 `~` 路径 → **Jump**
- Jump 链：`⇧⌘G` → Path 框 → 定向点击 → Return  
- **绝不**自动点击 Open / Save
- 非法路径 / 无面板：可见失败，可重试

### 侧栏列表（Rec | Fav | Find | Zox）

| Tab | 来源 | 刷新 |
| --- | --- | --- |
| **Rec** | 本 app 成功 Jump 的目录（最多 10） | 自动 |
| **Fav** | 你钉的收藏（显式顺序，最多 40） | 自动 |
| **Find** | 当前打开的 Finder 窗口路径（最多 50） | 点 **↻**（需 Automation） |
| **Zox** | `zoxide query -l` frecency（最多 50） | 点 **↻**（需本机安装 zoxide） |

- **单击**：填 Path；是否立刻 Jump 由菜单 **Jump on List Click** 控制（默认开）
- **双击**：始终 Jump
- **左侧拖柄**：拖出文件夹 URL，可拖到 Open/Save 面板上做 **系统原生导航**（与 Jump 点击区分开）
- **★**：加入 Favorites
- **⎘**：复制全路径  
- Favorites 行：**↑ ↓ ✕** 排序/删除

### 菜单栏
- **DJ** / **DJ!** / **DJ●**（固定宽度，状态切换不抖条）
- Accessibility / Folder Jump / Last jump 状态
- Focus Path · **Jump on List Click** · Recheck · Open Settings · Relaunch · About · Quit

### 权限与恢复
- **Accessibility**：Jump 必需；撤销时拆侧栏、暂停 Jump、可 Recheck / 开设置
- **Automation（Finder）**：仅 Finder tab ↻ 时需要
- 软失败只 status；权限类可一次性 alert（无 prompt 风暴）

### 明确不做（当前）
- 全局热键（如 ⌥⌘J）— 需要 Go to Folder 用系统 **⇧⌘G**
- Fuzzy 本机文件夹搜索 / 云同步索引
- 代点 Open/Save、同步 Finder 边栏收藏

---

## 运行（开发）

```bash
cd apps/DialogJumper
./scripts/run-dev-app.sh
```

1. 系统设置 → 隐私与安全性 → **辅助功能** → 勾选 Dialog Jumper  
2. TextEdit → **文件 → 打开…**  
3. 菜单栏出现 **DJ●**，侧栏可用  

开发签名：**DialogJumper Dev**，**不要** Hardened Runtime（会破坏跨进程 AX）。

```bash
cd apps/DialogJumper && swift test && swift build
```

---

## 从 GitHub Release 安装（无 Developer ID）

Release 为 **ad-hoc 签名、未公证**，会有 Gatekeeper 提示。

1. 从 [Releases](../../releases) 下载 macOS zip  
2. 解压后右键 **DialogJumper.app** → 打开，或 `xattr -cr DialogJumper.app`  
3. 打开 **辅助功能**  
4. 可选：自动化 → 控制 Finder（Find tab）  
5. 可选：安装 **zoxide**（Zox tab）  

---

## 发布（GitHub Actions）

```bash
git tag v0.1.0
git push origin v0.1.0
```

或在 Actions 里手动跑 **Release**（draft）。

本地：

```bash
apps/DialogJumper/scripts/package-release.sh
# → apps/DialogJumper/dist/DialogJumper-*-macos-*.zip
```

---

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `apps/DialogJumper/` | SwiftPM 产品 + 脚本 |
| `docs/` | progress / constraints / journal |
| `.scratch/` | 研究 / MVP 票（本地可选） |

许可证：[MIT](./LICENSE)
