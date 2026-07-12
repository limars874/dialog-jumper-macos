# Resume snapshot

## Goal
实现 Dialog Jumper MVP（依据 handoff-ready spec）。

## Doing now
idle；tickets **01–03** done。

## Key context
- App：`apps/DialogJumper` — Accessibility gate + File Dialog detection + Path Folder Jump
- Run：`cd apps/DialogJumper && swift run DialogJumper`
- Detected glyph：`DJ●`；菜单 `Jump to Path…`（eligible 时）
- Jump：`⇧⌘G` → PathTextField → directed click → Return；严格 Path 失败
- Frontier next：**04 — Dialog-attached toolbar Path**

## Next
Claim / implement `04-dialog-attached-toolbar-path.md`（若已存在）或 toolbar attach ticket。

## Blockers
(none) — ticket 03 人工 TextEdit 验收留给 owner。
