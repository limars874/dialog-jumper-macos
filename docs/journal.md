# Journal

## [2026-07-11] 初始化 flow-light memory layer
- **Did**: 在 greenfield 仓库中创建 progress、constraints、roadmap、learnings 与 journal，并将读取规则接入 `AGENTS.md`。
- **Decided**: Owner 确认当前 constraints 与 roadmap；尚未选定 Stack 或 milestones。下一步是提供首个真实任务或项目方向。
- **Refs**: `AGENTS.md`, `docs/progress.md`, `docs/constraints.md`, `docs/roadmap.md`, `docs/learnings.md`, `docs/journal.md`

## [2026-07-11] 绘制 macOS File Dialog Wayfinder map
- **Did**: 建立 [探索 macOS File Dialog 快速 Folder Jump 的 MVP 路线](../.scratch/macos-file-dialog-jumper/map.md)，创建八个命名 tickets，并连接 frontier 与 blocking 关系；未解决任何 ticket。
- **Decided**: Destination 是 handoff-ready MVP spec；范围聚焦标准 File Dialog 的 Folder Jump，允许直接分发、完全 on-device、native Swift 优先但不锁死。
- **Refs**: `.scratch/macos-file-dialog-jumper/`, `docs/context.md`, `docs/progress.md`, `docs/roadmap.md`, `docs/constraints.md`

## [2026-07-11] 明确 File Dialog 系统能力边界
- **Did**: 解决 [查明 macOS File Dialog 的系统能力与权限边界](../.scratch/macos-file-dialog-jumper/issues/01-macos-file-dialog-capabilities.md)，写入带 Apple 一手来源的研究资产并更新 map。
- **Decided**: 方向进入 prototype；baseline 为 non-sandbox Developer ID 直发 + Accessibility。跨进程 detection/navigation 与 MAS sandbox 均不得在实测前承诺。
- **Refs**: `.scratch/macos-file-dialog-jumper/assets/macos-file-dialog-capabilities.md`, `.scratch/macos-file-dialog-jumper/map.md`

## [2026-07-11] 验证 Folder Jump 候选机制
- **Did**: 解决 [验证 Folder Jump 候选机制并选出可行路径](../.scratch/macos-file-dialog-jumper/issues/02-folder-jump-mechanism.md)，在 DialogHost、Save Panel 和 TextEdit 中运行 throwaway AX prototype，并由 owner 复核结果。
- **Decided**: 采用 `⇧⌘G` + AX PathTextField + 定向 synthetic click + Return；纯 AX menu 不可用。未授权 TCC 分支未声称已验证。
- **Refs**: `.scratch/macos-file-dialog-jumper/prototypes/ax-dialog-probe/RESULTS.md`, `.scratch/macos-file-dialog-jumper/map.md`

## [2026-07-12] 打通 activation 真路径
- **Did**: 在 [选择 Folder Jump 的 activation interaction](../.scratch/macos-file-dialog-jumper/issues/03-activation-interaction.md) 中运行 throwaway prototype；定位并修复 shortcut 冲突与 File Dialog 假阴性 detection；owner 确认 TextEdit Open Panel + `⌥⌘J` 可打开 palette。
- **Decided**: 默认 shortcut 候选改为 `⌥⌘J`；detection 用 OpenAndSavePanelService + AX fingerprint，不用 CG window list 作为存在性 gate。MVP mode 组合尚未锁定。
- **Refs**: `.scratch/macos-file-dialog-jumper/prototypes/activation-interaction/RESULTS.md`, `/tmp/dialog-jumper-activation.log`

## [2026-07-12] 对照 Default Folder X 交互
- **Did**: owner 指出当前 palette 只是技术可达、UI 未定，并要求对照收费竞品 Default Folder X；整理官方手册与产品页中的 dialog-attached 模型。
- **Decided**: 暂不锁定 shortcut/menu 组合。先在 A dialog-attached / B floating palette / C hybrid 中选定主交互；jump 执行层可复用。
- **Refs**: `.scratch/macos-file-dialog-jumper/assets/default-folder-x-interaction-model.md`, `.scratch/macos-file-dialog-jumper/prototypes/activation-interaction/RESULTS.md`

## [2026-07-12] 锁定 activation interaction contract
- **Did**: 关闭 [选择 Folder Jump 的 activation interaction](../.scratch/macos-file-dialog-jumper/issues/03-activation-interaction.md)；对照 DFX 后由 owner 确认 dialog-attached side toolbar 为 MVP 主交互。
- **Decided**: dialog-attached side toolbar 为主交互；初始落库误写 Search，后由 correction 改为 Path/Recents/Favorites；shortcut 仅加速器（候选 ⌥⌘J）。
- **Refs**: `.scratch/macos-file-dialog-jumper/issues/03-activation-interaction.md`, `.scratch/macos-file-dialog-jumper/map.md`, `.scratch/macos-file-dialog-jumper/assets/default-folder-x-interaction-model.md`

## [2026-07-12] 纠正 MVP sources：去掉 fuzzy Search
- **Did**: owner 指出 ticket 03 不应含 Folder Search；回改 ticket 03/map/RESULTS/context，并继续 ticket 04 grilling。
- **Decided**: MVP sources = **Path + Recents + Favorites**；不做 fuzzy Folder Search、文件搜索、app launcher。
- **Refs**: `.scratch/macos-file-dialog-jumper/issues/03-activation-interaction.md`, `.scratch/macos-file-dialog-jumper/issues/04-folder-sources-search-behavior.md`, `docs/context.md`

## [2026-07-12] 锁定 folder sources contract
- **Did**: 关闭 [确定 MVP 的 folder sources 与搜索行为](../.scratch/macos-file-dialog-jumper/issues/04-folder-sources-search-behavior.md)；先纠正 ticket 03 误含 Search，再 grilling 锁定 Path/Recents/Favorites 语义。
- **Decided**: Path 严格失败；Recents 上限 10 且 last-used；Favorites 显式管理；失效可见不 jump；不做 fuzzy Folder Search。
- **Refs**: `.scratch/macos-file-dialog-jumper/issues/04-folder-sources-search-behavior.md`, `docs/context.md`, `.scratch/macos-file-dialog-jumper/map.md`

## [2026-07-12] 锁定 on-device architecture
- **Did**: 关闭 [选择 on-device folder discovery 与 indexing 架构](../.scratch/macos-file-dialog-jumper/issues/05-on-device-discovery-architecture.md)；因无 fuzzy search 收敛为本地 Path/Recents/Favorites 存储。
- **Decided**: 采用 app-local resolver + stores + bookmarks；拒绝 Spotlight/FSEvents 全盘索引与系统 Recents/Finder 收藏同步。
- **Refs**: `.scratch/macos-file-dialog-jumper/assets/on-device-discovery-architecture.md`, `.scratch/macos-file-dialog-jumper/map.md`

## [2026-07-12] 锁定权限 onboarding contract
- **Did**: 关闭 [设计权限 onboarding、撤销与失败恢复](../.scratch/macos-file-dialog-jumper/issues/06-permission-onboarding-recovery.md)。澄清开发期 AX 成功来自已 trusted 宿主，不是免权限；owner 接受正式产品必须申请 Accessibility。
- **Decided**: MVP 仅 Accessibility；Explain→Settings→recheck；拒绝/撤销/不支持/路径与 jump 失败均有可见恢复；不首启 IM/Automation/FDA。
- **Refs**: `.scratch/macos-file-dialog-jumper/issues/06-permission-onboarding-recovery.md`, `.scratch/macos-file-dialog-jumper/prototypes/permission-onboarding/`

## [2026-07-12] 锁定 support matrix
- **Did**: 关闭 [定义标准 File Dialog support matrix 与验收方法](../.scratch/macos-file-dialog-jumper/issues/07-support-matrix-acceptance.md)；写入 must-pass/degrade/out-of-scope 与复测模板。
- **Decided**: 支持边界=系统 Open/Save panel + 多信号 fingerprint；负样本零动作；发布宣称前填满 OS×host REQ 门禁。
- **Refs**: `.scratch/macos-file-dialog-jumper/assets/file-dialog-support-matrix.md`, `.scratch/macos-file-dialog-jumper/map.md`

## [2026-07-12] Handoff-ready MVP spec 确认
- **Did**: 关闭 [确认 handoff-ready MVP spec](../.scratch/macos-file-dialog-jumper/issues/08-confirm-mvp-spec.md)；汇总 01–07 为 `assets/mvp-spec.md`，owner 确认。
- **Decided**: Wayfinder destination 达成；后续进入 implementation planning，不再在本 map 内补方向决策。
- **Refs**: `.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`, `.scratch/macos-file-dialog-jumper/map.md`, `docs/roadmap.md`

## [2026-07-12] 发布 Dialog Jumper MVP implementation tickets
- **Did**: 按 `mvp-spec.md` 拆 9 张 tracer-bullet tickets 并写入 `.scratch/dialog-jumper-mvp/issues/`；owner 批准切分后发布。
- **Decided**: feature slug `dialog-jumper-mvp`；01 无阻塞可先开；05–07 并行依赖 04；09 收口验收。
- **Refs**: `.scratch/dialog-jumper-mvp/spec.md`, `.scratch/dialog-jumper-mvp/issues/`, `.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## [2026-07-12] Implement ticket 01 app shell
- **Did**: 落地 `apps/DialogJumper` 菜单栏壳 + Accessibility 诚实门禁；Core 可单测；`swift test` / `swift build` 通过。
- **Decided**: 仅用 `AXIsProcessTrusted` 映射 ready/paused；打开设置时可带 prompt，但不以返回值当已授权。
- **Refs**: `apps/DialogJumper/`, `.scratch/dialog-jumper-mvp/issues/01-app-shell-accessibility-gate.md`

## [2026-07-12] Implement ticket 02 File Dialog detection
- **Did**: 在 `DialogJumperCore` 加入 multi-signal fingerprint + panel service 检测；菜单栏展示 detected/none；`swift test` 10 项通过。
- **Decided**: 仅 trusted 时检测；OpenPanel/SavePanel 或 window+AXSystemDialog 才 eligible；纯英文 title 不计分。
- **Refs**: `apps/DialogJumper/Sources/DialogJumperCore/FileDialogDetector.swift`, `.scratch/dialog-jumper-mvp/issues/02-file-dialog-detection.md`

## [2026-07-12] Implement ticket 03 Path Folder Jump
- **Did**: 落地 `PathResolver` + `FolderJumpExecutor`（锁定 ⇧⌘G → PathTextField → 定向 click → Return）与菜单栏 Path 入口；单测 24 项；`swift test` / `swift build` 通过；ticket 03 标 done（TextEdit 人工项留给 owner）。
- **Decided**: 03 用菜单 Path 输入，不抢 04 toolbar；严格路径失败不降级搜索；无 location evidence 不报成功；永不代点 Open/Save。
- **Refs**: `apps/DialogJumper/Sources/DialogJumperCore/PathResolver.swift`, `FolderJumpExecutor.swift`, `.scratch/dialog-jumper-mvp/issues/03-path-folder-jump.md`

## [2026-07-12] Ticket 03 手测通过 + 实现 04 附着 toolbar
- **Did**: owner 确认 Path Jump（含粘贴修复）可用；勾 03 人工项。实现 dialog-attached Path side toolbar（04），26 tests 绿。
- **Decided**: toolbar 为 Path 主入口；成功不弹 modal；菜单仅聚焦 toolbar。
- **Refs**: `AttachedPathToolbarController.swift`, `FileDialogGeometry.swift`, issues/03–04
