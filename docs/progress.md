# Resume snapshot

## Goal
实现 Dialog Jumper MVP（依据 handoff-ready spec）。

## Doing now
**Ticket 05 done** — Recent Folders 已落地（repository + toolbar list + tests）。

## Key context
- App：`apps/DialogJumper` via `scripts/run-dev-app.sh`（dedicated keychain sign, no hardened runtime）
- Jump：⇧⌘G + PathTextField + directed click + Return
- Toolbar：dialog-attached Path + Recents；hide when host not frontmost；dismiss on Cancel
- Recents：成功 Jump 写入；≤10 last-used；path dedupe；UserDefaults 持久化
- Spec：`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

## Next
06 Favorite Folders 与 07 shortcut/menubar 可并行（均依赖 04，05 已完成）→ 08 → 09。

## Blockers
无。
