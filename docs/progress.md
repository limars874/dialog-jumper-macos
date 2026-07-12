# Resume snapshot

## Goal
Dialog Jumper：标准 macOS Open/Save 上的 Folder Jump 侧栏（Path / Recents / Favorites / Finder）。

## Doing now
无进行中实现票。产品在 **lab 可用 + 持续 polish** 状态。

## Done (this arc)
- Implementation tickets **01–06 / 08 / 09 done**；**07 cancelled**（无全局热键）
- Jump 内核：⇧⌘G → PathTextField → directed click → Return；不代 Open/Save
- 侧栏列表：**Recent | Favs | Finder** segment；单行 `名字 + path`；截断显示 `…`
- Recents/Finder 行：★ 收藏、⎘ 复制全路径；Favorites：↑↓✕
- 小钮 hover（`TinyActionButton` + `.activeAlways`）
- **Finder tab**：点 ↻ 拉打开的 Finder 窗路径（AppleScript + Automation）；`capacity = 50`
- Info.plist：`NSAppleEventsUsageDescription`（否则常不弹 Automation）
- 菜单栏：固定槽 28pt + monospaced，`DJ` / `DJ!` / `DJ●` 不抖
- 软失败只 status；revoke / Accessibility 硬恢复可 alert
- Support-matrix pack：lab PASS vs REQ 诚实记账

## Key context
- Run：`apps/DialogJumper/scripts/run-dev-app.sh`（DialogJumper Dev，no hardened runtime）
- Spec：`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`
- Pack：`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`（R2 Save 等仍 REQ）
- Constraints：`docs/constraints.md`（整行 hit-test、activeAlways、冷启动沉淀、检测 fingerprint 等）
- Finder 读取：`FinderWindowsReader`（window 索引枚举，勿 `every Finder window` 脆弱循环）

## Next (optional)
- matrix：Save HITL、多宿主 / 多 OS
- 多屏 geometry residual
- 新 path 来源 / 能力需另开范围

## Blockers
无。
