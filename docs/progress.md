# Resume snapshot

## Goal
Dialog Jumper：标准 macOS Open/Save 上的 Folder Jump 侧栏（Path / Recents / Favorites / Finder / Zoxide）。

## Doing now
无进行中实现票。lab 可用；多侧栏改造已否决（外部评审：不划算）。

## Done (this arc)
- Tickets **01–06 / 08 / 09 done**；**07 cancelled**
- Jump：⇧⌘G 链；不代 Open/Save
- 列表 **Rec | Fav | Find | Zox**；单行；★ / ⎘；Favorites ↑↓✕
- **左侧拖柄**：拖文件夹 file URL → Open/Save **原生导航**（与 Jump 点击分离）
- Find：↻ + Automation；Zox：↻ + `zoxide query -l`；均 cap 50
- 菜单 **Jump on List Click**（单击 Jump / 只填 Path；双击始终 Jump）
- 侧栏几何：优先 dialog **右侧**；**整窗顶对齐**（含标题栏高度）
- 菜单栏 DJ 固定宽；软失败 status；revoke 可恢复

## Key context
- Run：`apps/DialogJumper/scripts/run-dev-app.sh`
- Release：`apps/DialogJumper/scripts/package-release.sh` + `.github/workflows/release.yml`（tag `v*`）
- README：仓库根 `README.md`
- 多侧栏讨论笔记：`docs/notes/single-vs-multi-sidebar.md`（结论：先不搞）
- Pack：`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`

## Next (optional)
- 推送 tag 验证 Actions Release
- matrix Save / 多宿主手测

## Blockers
无。
