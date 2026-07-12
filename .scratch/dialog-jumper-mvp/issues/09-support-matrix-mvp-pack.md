# 09 — MVP support-matrix 最小验收包

**What to build:** 按 support matrix 提供可重复的最小 must-pass 验收包与记录方式，证明当前构建在约定场景下行为正确，并显式列出仍为 REQ、不得对外宣称的格子。

**Blocked by:** 05 — Recent Folders; 06 — Favorite Folders; 08 — 运行时失败与撤销恢复（**07 已 cancelled：无全局 shortcut**）

**Status:** done

- [x] 最小回归包可执行并留下结果：TextEdit Open + 空格路径；至少一宿主 Save；一负样本零动作；Accessibility denied 烟测；非法路径烟测
- [x] 每条结果可对照 matrix 图例（PASS / FAIL / DEG / OUT）
- [x] 文档标明 lab 已 PASS 与发布前仍 REQ 的 OS×host 项（不把未测格写成已支持）
- [x] 安全门禁抽检：未知 UI 零动作；失败不代提交 Open/Save

## Implementation notes

- Pack artifact: [`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`](../assets/mvp-support-matrix-pack.md)
- Parent matrix (full definitions): `../macos-file-dialog-jumper/assets/file-dialog-support-matrix.md` (via repo `.scratch/macos-file-dialog-jumper/…`)
- Lab: macOS 15.7.4 arm64; app `me.dialogjumper.dev`; automated **52** tests green
- **PASS (owner + lab):** R1 TextEdit Open + spaced path; R4 AX revoke/denied smoke; R5 bad path; R3 partial (no-panel zero-action + fingerprint unit); safety R6
- **REQ (not greenwashed):** R2 Save HITL on product build; multi-OS; multi-host; named Electron negative; clean first-run TCC; shipping identity
- 07 global shortcut cancelled — not part of pack

## Residual

- Owner may fill R2 Save + extra hosts by copying §5 template into the pack without changing PASS cells already dated.
