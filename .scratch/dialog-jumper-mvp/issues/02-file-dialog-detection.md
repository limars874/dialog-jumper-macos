# 02 — 标准 File Dialog 检测

**What to build:** 当系统标准 Open/Save File Dialog 出现时，Dialog Jumper 能可靠识别为 eligible；对自定义 / Electron / Qt 等非标准选择器保持零动作。用户（或调试表面）能区分“已检测到 eligible dialog”与“无/不支持”。

**Blocked by:** 01 — App shell + Accessibility 诚实门禁

**Status:** done

- [x] 仅在 Accessibility trusted 时进行跨进程检测
- [x] 使用系统 Open/Save panel 路径 + 多信号 AX fingerprint（非单一 role、非英文标题硬编码）
- [x] TextEdit（或等价 Apple host）标准 Open Panel 可被识别为 eligible
- [x] 至少一种非标准 / 自定义 picker 负样本：零 jump、零有害操作
- [x] 低置信度时不宣称 detected、不触发后续 Jump

## Implementation notes

- Core: `FileDialogFingerprint` multi-signal score (OpenPanel/SavePanel id, window+AXSystemDialog); English title alone scores 0
- Core: `FileDialogDetector` only runs when `authorization == .ready`; scans `openAndSavePanelService` + AX windows
- App menu: `File Dialog: detected (open, TextEdit)` vs `none / not eligible` vs detection paused
- Menu bar glyph: `DJ●` when eligible
- Tests: fingerprint eligibility + VSCode bundle negative + title-only negative (`swift test` 10 tests)
- Manual: open TextEdit Open Panel → menu should show detected; quit panel → none
