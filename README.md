# Dialog Jumper

macOS 菜单栏工具：在**系统标准 Open / Save 对话框**里快速 **Folder Jump**，不替你点 Open/Save。

侧栏附着在 File Dialog 旁，支持 Path 输入、Recents、Favorites、打开的 Finder 窗口、以及 **zoxide** 常用目录。

> Lab / 自用阶段。完整产品规格见  
> [`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`](.scratch/macos-file-dialog-jumper/assets/mvp-spec.md)

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
Favorites 行：**↑ ↓ ✕** 排序/删除
### 菜单栏
- **DJ** / **DJ!** / **DJ●**（固定宽度，状态切换不抖条）
- Accessibility / Folder Jump / Last jump 状态
- Focus Path · **Jump on List Click** · Recheck · Open Settings · Relaunch · About · Quit

### 权限与恢复
- **Accessibility**：Jump 必需；撤销时拆侧栏、暂停 Jump、可 Recheck / 开设置
- **Automation（Finder）**：仅 Finder tab ↻ 时需要；Info.plist 含用途说明
- 软失败只 status；权限类可一次性 alert（无 prompt 风暴）

### 明确不做（当前）
- 全局热键（如 ⌥⌘J）— 需要 Go to Folder 用系统 **⇧⌘G**
- Fuzzy 本机文件夹搜索 / 云同步索引
- 代点 Open/Save、同步 Finder 边栏收藏

---

## 运行

```bash
cd apps/DialogJumper
./scripts/run-dev-app.sh
```

1. 系统设置 → 隐私与安全性 → **辅助功能** → 勾选 Dialog Jumper  
2. TextEdit → **文件 → 打开…**  
3. 菜单栏出现 **DJ●**，侧栏可用  

开发签名：专用 keychain 身份 **DialogJumper Dev**，**不要** Hardened Runtime（会破坏跨进程 AX）。

```bash
cd apps/DialogJumper && swift test && swift build
```

## 发布（GitHub Actions）

推送 tag 后自动测试、release 编译、ad-hoc 签名并上传 zip：

```bash
git tag v0.1.0
git push origin v0.1.0
```

也可在 Actions 里手动 **workflow_dispatch**（draft release）。

本地打 zip：

```bash
apps/DialogJumper/scripts/package-release.sh
# → apps/DialogJumper/dist/DialogJumper-*-macos-*.zip
```

**无 Apple Developer ID、未公证。** 别人安装：

1. 解压后右键 app → 打开，或 `xattr -cr DialogJumper.app`
2. 打开 **辅助功能**
3. Find 需 **自动化 → Finder**；Zox 需本机 **zoxide**

---

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `apps/DialogJumper/` | SwiftPM 产品代码 + `scripts/run-dev-app.sh` |
| `docs/` | progress / constraints / journal / context |
| `.scratch/macos-file-dialog-jumper/` | 研究 map、spec、support matrix |
| `.scratch/dialog-jumper-mvp/` | 实现票与验收 pack |

验收包（lab PASS vs 仍 REQ）：  
[`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`](.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md)

---

## 依赖（可选）

| 依赖 | 用途 |
| --- | --- |
| 无（仅 AX） | Path / Recents / Favorites Jump |
| **Finder Automation** | Find tab |
| **[zoxide](https://github.com/ajeetdsouza/zoxide)** 在 PATH/Homebrew | Zox tab |

---

## 实现票状态

- **01–06 / 08 / 09** done  
- **07** cancelled（无全局 shortcut）  
- 之后：列表 UI、Finder/Zoxide 源、Jump on List Click 等 polish 已合入 `main`
