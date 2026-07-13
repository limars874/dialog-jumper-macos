# Dialog Jumper

macOS **菜单栏**工具：在**系统标准 Open / Save 对话框**里快速跳转文件夹。

侧栏附着在对话框旁，可用路径、最近、收藏、已打开的 Finder 窗口、[zoxide](https://github.com/ajeetdsouza/zoxide) 常用目录。**不会替你点击 Open / Save。**

**English:** [README.md](./README.md)

> Lab / 自用阶段。**未公证**（无 Apple Developer ID）。首次打开会有 Gatekeeper 提示。

## 截图

<p align="left">
  <img src="https://cdn.jsdelivr.net/gh/limars874/dialog-jumper-macos@main/docs/screenshots/side-chrome.png" alt="Dialog Jumper 侧栏" width="320" />
</p>

## 安装（Release）

1. 从 [Releases](https://github.com/limars874/dialog-jumper-macos/releases) 下载最新 **macOS zip**  
   - 当前 CI 产物仅为 **Apple 芯片 (arm64)**。
2. 解压后 **右键 → 打开**（或终端执行 `xattr -cr DialogJumper.app`）。
3. 系统设置 → 隐私与安全性 → **辅助功能** → 勾选 **Dialog Jumper**。
4. 可选：
   - **自动化** → 允许 Dialog Jumper 控制 **Finder**（Find 页）
   - 安装 **[zoxide](https://github.com/ajeetdsouza/zoxide)**（Zox 页）

## 30 秒上手

1. 启动 Dialog Jumper（菜单栏出现 **DJ** / **DJ!** / **DJ●**）。
2. 打开**系统**文件对话框（如 TextEdit → **文件 → 打开…**）。
3. 在侧栏：
   - 输入/粘贴路径（`/` 或 `~`）→ **Jump**，或  
   - 点击列表行，或  
   - **拖左侧拖柄**到对话框上（系统原生导航）。
4. 最后由你自己点 **打开 / 存储**——Dialog Jumper 不会代点。

### 菜单栏图标

| 图标 | 含义 |
| --- | --- |
| **DJ** | 已就绪，未检测到文件对话框 |
| **DJ!** | 需要辅助功能（或权限被关） |
| **DJ●** | 已检测到系统文件对话框 |

## 功能

| 区域 | 说明 |
| --- | --- |
| **Jump** | 在系统对话框内跳到目标文件夹，不自动确认 |
| **Path** | 绝对路径与 `~`；清除按钮；框内拖柄可拖到面板 |
| **Rec** | 本 app 成功跳转过的目录（最多 10） |
| **Fav** | 收藏，可排序/删除（最多 40） |
| **Find** | 当前打开的 Finder 窗口目录（最多 50；需刷新与自动化） |
| **Zox** | `zoxide query -l` 列表（最多 50；需本机 zoxide） |
| **列表操作** | 单击/双击（见菜单 **Jump on List Click**）、★ 收藏、复制路径、拖柄 |
| **安全** | 不自动 Open/Save；失败在状态行提示 |

**暂不包含：** 全局热键、全盘模糊搜文件夹、同步 Finder 边栏收藏、多对话框各挂一侧栏。

## 从源码运行

```bash
cd apps/DialogJumper
./scripts/run-dev-app.sh
```

```bash
cd apps/DialogJumper && swift test && swift build
```

开发签名若使用本地证书，**不要**打开 Hardened Runtime（会影响跨进程辅助功能）。

本地打 Release zip：

```bash
apps/DialogJumper/scripts/package-release.sh
```

维护者：推送 `v0.0.x` tag 可触发 [GitHub Actions](https://github.com/limars874/dialog-jumper-macos/actions) 打包（ad-hoc 签名、未公证）。变更见 [CHANGELOG.md](./CHANGELOG.md)。

## 环境要求

| 需要 | 用途 |
| --- | --- |
| macOS 14+ | 运行 |
| 辅助功能 | Jump |
| Finder 自动化 | Find 页 |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Zox 页 |
| Apple 芯片（当前 Release） | CI 预编译 zip |

## 许可证

[MIT](./LICENSE)
