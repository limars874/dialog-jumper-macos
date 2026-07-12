# Resume snapshot

## Goal
实现 Dialog Jumper MVP（依据 handoff-ready spec）。

## Doing now
**Ticket 08 done** — runtime failure / Accessibility revoke recovery。Next: 09 support-matrix pack。

## Key context
- App：`apps/DialogJumper` via `scripts/run-dev-app.sh`（dedicated keychain sign, no hardened runtime）
- Jump：⇧⌘G + PathTextField + directed click + Return（产品代用户走这条链，不是再绑全局热键）
- Toolbar：dialog-attached Path + Recents + Favorites；hide when host not frontmost；dismiss on Cancel
- Recents：成功 Jump 写入；≤10 last-used；UserDefaults
- Favorites：显式 add/remove/reorder；add 信任 path（同 Recents，不 probe/bookmark）；UserDefaults
- Menu bar：状态 + Focus Path + Accessibility（Request / **Recheck** / Settings / Relaunch）；07 全局 shortcut cancelled
- Recovery：ready→paused = revoked UX（拆 chrome、一次性 alert、Settings+recheck）；Jump/Focus 失败可见 `FolderJumpFailure` 文案；无假授权、无 prompt 风暴
- Spec：`.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`（shortcut 原为 optional；现 MVP 不实现）

## Next
09 support-matrix MVP pack。

## Blockers
无。
