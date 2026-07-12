# 01 — App shell + Accessibility 诚实门禁

**What to build:** 用户能启动 Dialog Jumper 的 native macOS app，立刻看到 Accessibility 是否可用；未授权时产品诚实停用 Folder Jump 能力，并提供打开系统 Accessibility 设置与重新检查的路径。不索取 Input Monitoring、Automation 或 Full Disk Access。

**Blocked by:** None — can start immediately.

**Status:** done

- [x] 可运行的 native macOS app 壳（非 sandbox MVP 方向；菜单栏或同等常驻入口可接受）
- [x] 以 `AXIsProcessTrusted()`（或等价 recheck）为唯一“已授权”信号，禁止假授权文案
- [x] 未授权：明确暂停 Jump 相关能力，并提供 Open Accessibility Settings + Recheck
- [x] 授权后 recheck 进入 ready；从设置返回后状态正确更新
- [x] 不在首启请求 Input Monitoring / Automation / Full Disk Access

## Implementation notes

- App: `apps/DialogJumper` (`swift run DialogJumper`)
- Core gate: `DialogJumperCore.AccessibilityGate` maps only `isProcessTrusted` → `ready` | `paused`
- Menu bar: `DJ` / `DJ!`; Open Settings + Recheck; 1s poll after Settings return
- Tests: `swift test` — AccessibilityGateTests (3)
- No IM / Automation / FDA APIs on launch
