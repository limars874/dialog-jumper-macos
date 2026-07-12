# Constraints

> Status: confirmed
> Owner confirmed on 2026-07-11; graduated batches 2026-07-12 (UI/dispatch + detection/git).
> Rule: graduated lessons are removed from `docs/learnings.md` (single home in constraints).

## Stack

尚未确定。

## Architecture

已确认的项目边界：
- Folder discovery、search、路径、文件名与目录索引必须完全留在本机，不得上传或云同步。
  - Evidence: owner 在 [探索 macOS File Dialog 快速 Folder Jump 的 MVP 路线](../.scratch/macos-file-dialog-jumper/map.md) 制图时确认 `on-device` boundary。
- 跨进程 File Dialog / Open-Save panel 探测：必须先用 panel-service identity + 安全 fingerprint 选定候选，再读 AX；禁止用泛化「browser + text field + buttons」一类启发式直接扫前台 app。
  - Evidence: 初版 AX 误选 WeChat（2026-07-11）。
- 判断 panel **是否存在/eligible** 时，优先 `NSWorkspace.runningApplications` + AX window fingerprint；**不得**把 `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` 当作存在性前提（panel service 可被 AX 读到却不在该列表）。
  - Evidence: activation prototype 在 frontmost=TextEdit 时假阴性（2026-07-12）。

## UI (dialog-attached chrome)

- 侧栏/toolbar 列表行（Recents、Favorites 及后续同类）必须**整行可点**：由行本身拥有 hit-test（或等价地把 hit 目标置于最上层）。禁止「透明 button + 上层 label」叠层导致只有缝隙可点。
  - Evidence: ticket 05 Recents 手测（2026-07-12）。
- 附着在他 app File Dialog 旁的 floating chrome 上的 hover / cursor tracking，必须在**本 app 非 active**（宿主或 panel service 前台）时仍生效。AppKit 下 NSTrackingArea 使用 `.activeAlways`，不得用仅 active-app 生效的选项（如 `.activeInActiveApp`）充当 hover 方案。
  - Evidence: ticket 05 Recents hover 全灭后改为 `activeAlways`（2026-07-12）。

## Process (dispatch / memory)

- 冷启动 subagent **不会**继承主会话聊天。手测或纠偏得到的交互/实现约束，须先写入 `docs/learnings.md`；稳定后毕业进本文件并**从 learnings 删除对应条**（一处存放），且派工 brief 明文写出；禁止声称「下一票会自动吃到本轮对话经验」。
  - Evidence: owner 纠正 06 派工假设（2026-07-12）。
- 提交 Swift/app 工程时：确认 `.gitignore` 含 `.build/`（及同类构建产物）；`git add` 只纳入源码、docs、ticket 等应跟踪文件，禁止把 `.build/` 或 `dist/` 二进制一并提交。
  - Evidence: ticket 01 首次 commit 误纳入 `.build`（2026-07-12）。

## Style

尚未确定。
