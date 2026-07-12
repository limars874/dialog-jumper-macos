# 05 — Recent Folders

**What to build:** 附着 toolbar 展示 Recent Folders；用户点选即 Folder Jump。列表按 last-used 排序、最多 10 条、路径去重。成功 Jump 与可可靠观察到的 Open/Save 落点写入 Recents；失效项可见并标记不可用。

**Blocked by:** 04 — Dialog-attached side toolbar（Path）

**Status:** done

- [x] toolbar 可见 Recents 列表（文件夹名 + 路径副标题）
- [x] 点选 → 立即 Folder Jump（复用已有 executor）
- [x] 写入：成功 Jump；以及能可靠观察到的 Open/Save 落点目录
- [x] last-used 排序；上限 10；同路径去重并刷新时间戳
- [x] 不可达/已删等：标记不可用，点击说明原因，不 jump
- [x] 不做 fuzzy search，不把最近文件当 Recent Folder

## Implementation notes

- `RecentsRepository`（Core）：`record(url)` / `list()`；path dedupe + last-used desc + cap 10；`DirectoryPresenceReading` 探活
- 持久化：`UserDefaultsRecentsStore`（JSON，`dialogJumper.recentFolders`）；测试用 `InMemoryRecentsStore`
- 写入：仅 **成功 Folder Jump**（Open/Save 落点跨 app 观察不可靠，MVP 不接，避免假写入）
- `AttachedPathToolbarController`：Path 下方 Recents 列表（名 + 路径副标题）；available 点击 → 同 `FolderJumpExecutor`；unavailable 标记 + alert 说明，不 jump
- `AppDelegate`：成功 jump 后 `record` 并刷新列表；chrome 显示边沿刷新 availability
- Tests：`RecentsRepositoryTests` 7 项（排序/去重/上限/不可用/持久化/非文件）；全套 33 tests 绿
- 未做：fuzzy search、Recent Files、系统 Recents 同步
