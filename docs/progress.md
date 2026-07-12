# Resume snapshot

## Goal
实现 Dialog Jumper MVP（依据 handoff-ready spec）。

## Doing now
**Ticket 06 done** — Favorite Folders 已落地（repository + toolbar list/manage + tests）。

## Key context
- App：`apps/DialogJumper` via `scripts/run-dev-app.sh`（dedicated keychain sign, no hardened runtime）
- Jump：⇧⌘G + PathTextField + directed click + Return
- Toolbar：dialog-attached Path + Recents + Favorites；hide when host not frontmost；dismiss on Cancel
- Recents：成功 Jump 写入；≤10 last-used；path dedupe；UserDefaults 持久化
- Favorites：显式 add/remove/reorder；软上限 40；path 去重；bookmark 可选存储、路径为主键；失效可见不静默删
- Spec：`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## Next
07 shortcut/menubar → 08 runtime failure recovery → 09 support-matrix pack。

## Blockers
无。
