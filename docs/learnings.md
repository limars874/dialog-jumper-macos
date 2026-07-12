# Lessons

- [2026-07-11] 同一 hashline edit 中，多操作 header 必须独立书写，不能加 body-row `+`；replace 与 append 结构复杂时拆成两次 edit。— context: 错把 `INS.TAIL:` 写入正文，经过两轮修正才恢复 ticket 结构。
- [2026-07-12] 为 File Dialog 选 global shortcut 前先实测冲突；`⌥Space` 在本机触发 panel 路径 breadcrumb，而不是应用热键。— context: owner 截图显示 `Macintosh HD > ...` breadcrumb，日志无 hotkey invoke。
- [2026-07-12] 细分决策题被 cancel 后，禁止用“带默认内容的 draft + 一键接受”直接关 ticket；必须先让 owner 明示内容范围，否则会把未确认项写进 resolved answer。— context: ticket 03 误落 Search，owner 事后澄清只要 Path+Recents+Favorites。
