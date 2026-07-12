# Resume snapshot

## Goal
Dialog Jumper macOS MVP + UX polish — **本轮收尾**。

## Doing now
无进行中实现票。

## Done (this arc)
- Implementation tickets **01–06 / 08 / 09 done**；**07 cancelled**（无全局热键）
- Favorites add 信任 path（同 Recents）；Recents/Favorites 整行可点 + `.activeAlways` hover
- Runtime recovery：revoke 拆 chrome + 一次性 alert + Recheck
- Support-matrix pack：`.scratch/dialog-jumper-mvp/assets/mvp-support-matrix-pack.md`（lab PASS vs REQ 诚实）
- UX polish：DEBUG-only NSLog、干净菜单、软失败无 modal、toolbar 顶栏收紧

## Key context
- App：`apps/DialogJumper` · `scripts/run-dev-app.sh`（DialogJumper Dev，no hardened runtime）
- Jump：⇧⌘G → PathTextField → directed click → Return；不代 Open/Save
- Glossary：`docs/context.md`（Recent Folder = 成功 Jump 后的候选）
- Constraints：`docs/constraints.md`（整行 hit-test、activeAlways、冷启动沉淀等）

## Next (optional, not open tickets)
- Pack R2 Save HITL；多宿主 / 多 OS matrix 填格
- 多屏 geometry residual
- 新能力需新 grill / tickets

## Blockers
无。
