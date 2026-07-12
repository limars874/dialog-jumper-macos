# Resume snapshot

## Goal
Dialog Jumper MVP 已落地；当前在 **UX polish**（清 debug / 冗余文案与提示）。

## Doing now
**Polish pass（grill-with-docs 已确认）** 已实现：
- NSLog 仅 `#if DEBUG`；菜单无 `panelServices` lab 串
- 菜单三行状态；去掉 File Dialog 独立行与 Request
- 软失败只 status；revoke / Accessibility paused 可 alert
- Toolbar 去 hint 与 header 教学串
- Glossary：**Recent Folder** = 成功 Jump 后的候选

## Key context
- App：`apps/DialogJumper` / `scripts/run-dev-app.sh`
- Jump 内核未改；07 仍 cancelled
- 验收包仍在：`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`（R2 Save 等仍 REQ）

## Next
Owner 手测 polish；可选：R2 Save 填 pack、多宿主、多屏 residual。

## Blockers
无。
