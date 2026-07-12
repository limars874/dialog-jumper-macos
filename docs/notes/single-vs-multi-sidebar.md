# Dialog Jumper：单侧栏原理 vs 多侧栏改造会碰到什么

Date: 2026-07-12  
Audience: 给同事 / 外人快速讲清现状，并评估「每个 File Dialog 旁各挂一块侧栏」  
Status: 说明文档（非实现票）

---

## 1. 产品在干什么（一句话）

菜单栏 app 发现 **系统标准 Open/Save 对话框**，在旁边挂一块 **侧栏**，让用户用 Path / 列表把对话框 **跳到某个文件夹**；**不替用户点 Open/Save**。

---

## 2. 当前实现原理（单侧栏）

### 2.1 进程与权限

| 能力 | 用途 |
| --- | --- |
| **Accessibility** | 读 panel 树、走 Go to Folder、点 Path 框 |
| **Automation（可选）** | Finder tab：用 AppleScript 读打开的 Finder 窗口路径 |
| **本地 CLI（可选）** | Zoxide tab：`zoxide query -l` |

无 Hardened Runtime 的开发签名（跨进程 AX 更省事）。  
Jump / 检测 **只信** `AXIsProcessTrusted()`。

### 2.2 检测：什么叫「有一个 File Dialog」

约每 **0.5s**（及切 app 时）跑一遍：

1. Accessibility 未就绪 → 不检测，侧栏拆掉  
2. 扫 `NSWorkspace.runningApplications`，**只保留** bundle id 含  
   `openAndSavePanelService` 的进程（系统 Open/Save 面板服务）  
3. 该进程是否有 **屏幕上可见的大窗**（CG 或 AX；防止 Cancel 后进程还在却无面板）  
4. AX **fingerprint 打分**（如 `OpenPanel` / `SavePanel` identifier、system dialog 等）  
5. 宿主名从服务显示名解析：  
   `Open and Save Panel Service (TextEdit)` → **TextEdit**  
   （**不用**「谁是 frontmost」当宿主身份的唯一来源）

**非系统 panel**（Electron 自绘、普通 alert）通常对不上 service / 指纹 → 视为无 dialog，零动作。

### 2.3 多个 dialog 时：仍然只认一个

候选里排序大致是：

1. 优先：服务名匹配 **当前 frontmost 宿主** 的 panel  
2. 否则：扫到的 **第一个** 合格 panel  
3. 同一 PID 多窗：fingerprint **分最高** 的那扇  

结果：全局 **`detectionState = eligible(一个 panelPID)` 或 none/paused**。

### 2.4 单侧栏 UI

- **一个** `NSPanel`（floating、nonactivating）  
- 几何：读该 `panelPID` 的窗口 frame → 贴在 dialog **旁侧**  
- 显示条件（当前策略）：  
  - 仍 eligible，且  
  - frontmost 是 **宿主 / panel service / Dialog Jumper 自己**  
  - 否则 **隐藏**（切到别的 app 让路）；dialog Cancel/关 → **dismiss**  

侧栏内容：

| 区域 | 内容 |
| --- | --- |
| Path | 一个输入框 + Jump / ★ Favorite |
| 列表 tabs | **Rec \| Fav \| Find \| Zox**（segment，整高给当前 tab） |
| Rec | 本 app **成功 Jump** 写入，≤10 |
| Fav | 用户钉选，显式顺序，≤40 |
| Find | ↻ → AppleScript 枚举 Finder 窗路径，≤50 |
| Zox | ↻ → `zoxide query -l`，≤50 |

列表数据在 **AppDelegate 级单例仓库**；侧栏只是视图。

### 2.5 Jump 怎么执行

1. 解析 path（`~`、存在性等）  
2. 对 **当前 eligible 的 panel PID** 发：  
   **⇧⌘G** → 找到 Path 文本框 → **定向合成点击（该 PID）** → **Return**  
3. 成功 → 写入 Recents；失败 → status（软失败一般不弹窗）  
4. **从不**点 Open/Save 按钮  

菜单 **Jump on List Click**：单击列表是否立刻 Jump（默认开）；**双击始终 Jump**。

### 2.6 结构示意（现状）

```
[Menu bar DJ]
     │
     ▼
AppDelegate ── poll / frontmost
     │
     ├─ FileDialogDetector ──► 0..1 EligibleFileDialog (panelPID)
     ├─ Recents / Favorites / FinderReader / ZoxideReader  (全局)
     └─ AttachedPathToolbarController × 1
              │
              ├─ Path 字符串 × 1
              └─ Jump ──► FolderJumpExecutor(当前 panelPID)
```

---

## 3. 若改成「每个 dialog 旁各吸一个侧栏」

### 3.1 目标模型（讨论中较干净的一版）

| 东西 | 作用域 |
| --- | --- |
| Rec / Fav / Find / Zox 数据 | **仍全局一份** |
| Jump 实现 / 权限 | 全局 |
| 侧栏窗口（NSPanel + 几何 + 显隐） | **每个 eligible panel 一个** |
| **Path 输入框内容** | **每个侧栏独立** |
| 生命周期 | panel 出现 → 创建/显示侧栏；Cancel/关 → 拆对应侧栏 |

列表点击、★、Zox 刷新等：数据全局；**写入 Path / 发起 Jump** 时绑在 **被操作的那块侧栏** 的 `panelPID` 上。

### 3.2 相对现状要改什么（实现面）

1. **Detector**  
   - 现在：`detect → 0..1`  
   - 改为：`detect → [EligibleFileDialog]`（去重 PID）

2. **Chrome 管理**  
   - 现在：1 个 `AttachedPathToolbarController`  
   - 改为：`Dictionary<pid_t, Controller>`（或等价），每轮对账：  
     - 新 PID → create  
     - 消失 PID → dismiss + remove  
     - 仍在 → 更新 frame / show-hide  

3. **Jump API**  
   - 现在：隐式「当前唯一 PID」  
   - 必须改为：**显式 `panelPID`**（侧栏闭包捕获），否则多开时必串台  

4. **Path 状态**  
   - 从「全局一个 pathField」→ **每个 controller 自带 path 字符串**  

5. **菜单 Focus Path**  
   - 多目标时：Focus frontmost host 对应侧栏，或菜单列出多个 host  

6. **hide 策略（产品要拍板）**  
   - A：dialog 在就显示（跟生命周期最齐，可能挡桌面）  
   - B：仅该 host/panel 前台时显示对应侧栏（更接近现在「让路」，但是 N 份规则）  

### 3.3 会碰到的问题 / 风险

| 问题 | 说明 |
| --- | --- |
| **Jump 串台** | 最大正确性风险。侧栏 A 必须只驱动 panel A；漏传 PID 会 Jump 到 B。 |
| **状态对账** | 检测抖动、Cancel 时序、PID 复用，可能导致侧栏泄漏或闪烁。 |
| **几何** | 两 Open 并排/重叠时侧栏互挡；多屏 frame 已有 residual，N 倍暴露。 |
| **焦点 / key window** | nonactivating panel × N；「当前在改哪个 Path」要比现在清晰。 |
| **列表操作归属** | 全局 Zox 点 ★：写入 **哪** 个 Path？应固定为「事件来源侧栏」。 |
| **性能** | 每 PID 几何 + 可能的 orderFront；2～3 个通常可接受，很多 panel 要 cap。 |
| **测试矩阵** | 单测好写；HITL 要「双 TextEdit Open」等场景，自动化难。 |
| **心智** | 两块侧栏两个 Path，比单块「跟当前 dialog」多一步理解成本（有人觉得更直观，有人觉得乱）。 |

### 3.4 什么反而没那么难

- Rec/Fav/Find/Zox **仓库继续单例**——不必每侧栏复制一份数据。  
- 多开几个 `NSPanel` 本身在 AppKit 里不稀奇。  
- 单侧栏时代已经拆好：检测 / Jump / 列表 / chrome 边界清楚，多侧栏是 **chrome 层从 1→N + Jump 带 PID**，不是推翻架构。

### 3.5 工作量粗估（供讨论）

| 项 | 量级 |
| --- | --- |
| detect 返回数组 + 单测 | 小 |
| PID→Controller 对账 + 几何 | 中 |
| Jump 签名带 PID + 回归 | 中（正确性关键） |
| Path 每实例 + Focus 菜单 | 小～中 |
| hide 策略 + 双 Open 手测 | 中 |
| **合计** | **中等重构**，不是新项目；但比「再加一个 path 源」重一截 |

### 3.6 何时值得做

| 更值得 | 不太值得 |
| --- | --- |
| 经常 **同时** 开 ≥2 个系统 Open/Save，且都要 Jump | 几乎总是一个 dialog |
| 单侧栏「跟错 frontmost」已经烦到你 | 只是理论洁癖 |
| 接受维护 N 个 chrome 的测试成本 | 想尽量少 HITL |

**折中（比全多侧栏便宜）**：仍单侧栏，但多候选时 **菜单/status 明确当前 host**，或 **手动选附着目标**，Jump 仍只打一个 PID。

---

## 4. 对比一览

| | 现在（单侧栏） | 多侧栏（讨论模型） |
| --- | --- | --- |
| 侧栏数量 | 1 | = eligible panel 数 |
| 选目标 | 自动挑 1 个 PID | 每个 PID 自有侧栏 |
| Path | 1 份 | 每侧栏 1 份 |
| Rec/Fav/Find/Zox | 全局 | 全局（共享） |
| Jump 绑定 | 隐式当前 PID | **显式 PID（必须）** |
| 多 Open 并排 | 可能跟错/只服务一个 | 可并排服务；实现与测试更重 |
| 生命周期 | 跟「被选中的」dialog | 跟 **各自** dialog |

---

## 5. 相关代码入口（便于对照）

| 模块 | 路径 |
| --- | --- |
| 检测 | `apps/DialogJumper/Sources/DialogJumperCore/FileDialogDetector.swift` |
| Fingerprint | `…/FileDialogFingerprint.swift` |
| Jump | `…/FolderJumpExecutor.swift` |
| 侧栏 | `apps/DialogJumper/Sources/DialogJumper/AttachedPathToolbarController.swift` |
| 编排 | `…/AppDelegate.swift` |
| Finder 源 | `…/FinderWindowsReader.swift` |
| Zoxide 源 | `…/ZoxideReader.swift` |
| 产品说明 | 仓库根 `README.md` |

---

## 6. 给评审人的问题（可选）

1. 多 Open 是否是你们真实高频场景？  
2. hide：dialog 在就常显，还是仅 host 前台显示？  
3. 能否接受先做「单侧栏 + 显式选目标」，再上 N 侧栏？  
4. Jump 串台的测试谁来做 HITL？  

（本文只陈述原理与改造面，不预设必须改多侧栏。）
