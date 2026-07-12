# 08 — 运行时失败与撤销恢复

**What to build:** 用户在真实使用中遇到 unsupported host、Jump 失败、中途丢失 File Dialog、或 Accessibility 运行中被撤销时，都能看到明确状态与恢复动作；产品拆掉依赖 AX 的 chrome、取消 in-flight Jump，且绝不代点 Open/Save。

**Blocked by:** 03 — Path Input → Folder Jump 端到端; 04 — Dialog-attached side toolbar（Path）

**Status:** done

- [x] unsupported / 非标准 picker：零有害操作；可选说明“不是标准 File Dialog”
- [x] Jump 失败：可见可恢复错误；允许在 dialog 稳定后重试
- [x] 中途丢失 panel/焦点/AX 目标：中止 in-flight；不提交 Open/Save
- [x] Accessibility 运行中撤销：拆除 toolbar、停止 Jump、进入 denied/revoked 恢复（Settings + recheck）
- [x] 无假授权、无 prompt 风暴、无静默空操作

## Implementation notes

- Core pure session mapping: `AccessibilityGate.applyTrustChange` + `AccessibilitySessionTransition`
  - cold paused ≠ revoked；ready→paused 边沿 `justRevoked`（一次性 UI）
  - paused 且 `hadBeenReady` → revoked 文案（菜单 status / Folder Jump line）
  - paused→ready 清除 revoked presentation（authorization 回到 ready）
- Menu: **Recheck Accessibility**（只读 `trustReader` / `AXIsProcessTrusted`，不弹系统 prompt）
  - Request Accessibility 仍仅用户主动触发
- AppDelegate:
  - `!ready` 时 `attachedToolbar.dismiss()`，绝不附着
  - revoke 边沿一次性 NSAlert（Settings 按钮）；后续 0.5s poll 不再弹
  - Focus Path / Jump：`noEligibleDialog` / `accessibilityPaused` 走 `presentJumpFailure`（不再静默 return）
  - Jump 失败：toolbar `toolbarStatus` + alert `alertTitle`/`userMessage`；dialog 仍 eligible 可直接重试
- `FolderJumpFailure` 文案更偏恢复：dialogLost 明确 “nothing submitted”；noEligible 说明非标准 picker
- Executor 仍永不代点 Open/Save；dialogLost 等 failure 路径只中止
- Tests: `RuntimeRecoveryTests`（8）— transition 边沿 + recovery copy；全套 52 绿

## Owner manual steps

1. **Revoke mid-session:** 在 Accessibility 已允许、toolbar 附着时，System Settings 关掉 Dialog Jumper → 期望：chrome 拆除、菜单 “Revoked”、一次性 alert、Recheck 不弹系统 prompt；再打开开关 + Recheck/Relaunch → Ready。
2. **Jump fail:** 标准 panel 打开，Jump 到坏路径或干扰 Go to Folder → 可见失败文案；dialog 仍在可改路径重试。
3. **Dialog lost mid-jump:** Jump 过程中关掉 panel → “Jump interrupted / dialog disappeared / nothing submitted”；不 Open/Save。
4. **Unsupported:** 无 panel 或非标准 picker 时 Focus Path / Jump → “No standard File Dialog…”；宿主 UI 不被操作。

## Residual risks

- Clean TCC revoke 难自动化（签名/identity 归因）；依赖 owner 手测
- revoke alert 在 poll 边沿同步 modal，极端情况下可能与用户正在点菜单重叠
- Jump 中途 revoke：当前 executor 为同步序列，无法中途 cancel token；靠下一轮 poll 拆 chrome + 序列内 dialogLost/失败
