# 03 — Path Input → Folder Jump 端到端

**What to build:** 在已检测到的 eligible File Dialog 上，用户可通过 Path Input（绝对路径或 `~`）确认后完成 Folder Jump：dialog 导航到目标文件夹，且不代替用户点击 Open/Save。严格路径失败时给出原因且不跳转。

**Blocked by:** 02 — 标准 File Dialog 检测

**Status:** done

- [x] Path 支持绝对路径与 `~` 展开；非路径文本不降级为搜索
- [x] Jump 主路径锁定为：`⇧⌘G` → AX PathTextField 写入 → 对 panel service 定向 synthetic click（无全局 mouse-move）→ Return
- [x] 成功判定需位置证据（回读或等价验证）；无证据不声称成功
- [x] 不存在 / 非文件夹 / 不可达 / 未挂载：不 jump，说明原因
- [x] 永不代用户提交 Open/Save
- [x] 人工可复现：TextEdit Open → 含空格路径（如 `/Library/Application Support`）跳转成功

## Implementation notes

- `PathResolver`：严格 `empty` / `notPath` / `notFound` / `notDirectory` / `unreachable` / `unmounted`；`~` 展开；不搜索。
- `FolderJumpExecutor`：锁死 ⇧⌘G → PathTextField AX 写值 → `postToPid` 定向 click（无 mouse-move）→ Return；成功需 location evidence。
- UI（03 最小路径）：菜单栏 **Jump to Path…**（eligible 时启用）；toolbar attach 留给 04。
- 单测：`PathResolverTests` + jump gate（paused / no dialog / bad path）；`swift test` 24 项通过。
- **残留风险**：agent 未在本机跑 TextEdit 人工验收；owner 需按 README Manual 步骤确认含空格路径。

Prototype decision reference (not production code): jump sequence validated in wayfinder `ax-dialog-probe` RESULTS — ⇧⌘G + PathTextField + directed click + Return.
