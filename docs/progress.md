# Resume snapshot

## Goal
实现 Dialog Jumper MVP（依据 handoff-ready spec）。

## Doing now
**Ticket 09 done** — MVP support-matrix 最小验收包已落盘。Implementation tickets **01–06 / 08 done**；**07 cancelled**；**09 done**.

## Key context
- App：`apps/DialogJumper` via `scripts/run-dev-app.sh`（DialogJumper Dev，no hardened runtime）
- Jump：⇧⌘G + PathTextField + directed click + Return；不代点 Open/Save
- Toolbar：Path + Recents + Favorites；host 非前台隐藏；Cancel 拆除
- 无全局 shortcut（07 砍）
- Recovery：revoke 拆 chrome + 一次性 alert + Recheck（无 prompt 风暴）
- **验收包**：`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`  
  - Lab PASS：TextEdit Open+空格路径、revoke、坏路径、无 panel 零动作、52 unit tests  
  - 仍 REQ：Save HITL、多 OS、多宿主、命名负样本、shipping identity — **不得对外 greening**

## Next
无强制 implementation 票。可选：补 R2 Save 手测写入 pack；多宿主 / 多 OS 填 matrix；打磨 residual（多屏 geometry 等）。

## Blockers
无。
