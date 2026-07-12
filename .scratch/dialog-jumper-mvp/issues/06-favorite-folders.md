# 06 — Favorite Folders

**What to build:** 用户可显式管理 Favorite Folders（添加/移除/排序）并持久化；toolbar 列出收藏；点选即 Folder Jump。失效收藏不静默删除。不同步 Finder 边栏。

**Blocked by:** 04 — Dialog-attached side toolbar（Path）

**Status:** done

- [x] 可从当前 dialog 路径 / Path 成功目标 / Recents 等显式添加收藏
- [x] 可移除、可重排；顺序用户控制且持久化（bookmark 身份优先）
- [x] toolbar 展示 Favorites（名 + 路径副标题）；点选即 Jump
- [x] 失效项可见 + 不可用标记；不静默删除
- [x] 不自动同步 Finder 边栏收藏
- [x] 重启 app 后收藏与顺序仍在

## Implementation notes

- Core: `FavoritesRepository` + `UserDefaultsFavoritesStore` / `InMemoryFavoritesStore`
  - Explicit user order (array index); soft capacity **40**
  - Path dedupe on add; unavailable never silently deleted
  - Optional URL `bookmarkData` (`.minimalBookmark`) stored when creatable; **identity/dedupe remains path-based** (`standardizingPath`); resolve falls back to saved path if bookmark fails
  - No Finder sidebar import/export; no security-scoped start/stop (non-sandbox)
- UI: `AttachedPathToolbarController`
  - Path section: **Jump** + **★ Favorite** (explicit add from path field via PathResolver)
  - Recents + Favorites sections; Favorites rows reuse full-hit `FolderListRowControl` (`.activeAlways` hover) with sibling ↑↓✕ manage buttons
  - Click available → jump; unavailable → alert, no jump
- App: holds repository; refresh lists on chrome show / after manage / after successful jump
- Tests: `FavoritesRepositoryTests` (order, dedupe, remove, reorder, unavailable, persist, capacity, invalid add)
- Residual risks for owner hand-test:
  - Manage button hit targets are small (↑↓✕)
  - Bookmark resolve path rewrite on rename not persisted back to store (path remains primary)
  - Chrome taller (460) — may clip on very short dialogs
