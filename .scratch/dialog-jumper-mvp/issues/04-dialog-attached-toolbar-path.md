# 04 — Dialog-attached side toolbar（Path）

**What to build:** eligible File Dialog 出现时，自动附着 side toolbar（DFX 轻量侧栏形态，非 Large Bezel、非 floating palette 主路径）；toolbar 提供 Path Input 并驱动已实现的 Folder Jump。Dialog 消失则拆除 chrome。

**Blocked by:** 03 — Path Input → Folder Jump 端到端

**Status:** done

- [x] eligible dialog 出现 → 自动附着 side toolbar；非 eligible / 低置信度 → 不附着
- [x] toolbar 含 Path Input，确认后对**该** dialog 执行 Folder Jump
- [x] dialog 关闭或失去资格 → chrome 拆除，无残留干扰
- [x] 主交互符合 spec：附着 UI，而非依赖独立 palette 作为主路径
- [x] 多屏/移动 dialog 时 toolbar 行为可接受（不挡住关键控件到不可用）

## Implementation notes

- `FileDialogGeometry`：AX frame → Cocoa rect；右侧优先，空间不足贴左侧
- `AttachedPathToolbarController`：floating utility panel，0.5s 跟随 dialog；dismiss on none
- Path field + Jump / Return → 复用 `FolderJumpExecutor`；toolbar 成功不弹 modal（状态行反馈）
- 菜单改为 Focus Path on Toolbar…；Edit 菜单仍支持 ⌘V
- Tests：geometry left/right placement（26 tests total）
- Owner 手测：TextEdit Open → 侧栏出现 → paste path → Jump
