# Dialog Jumper — MVP Support-Matrix Pack

Date: 2026-07-12  
Build under test: `apps/DialogJumper` @ `f603300` (+ prior 01–06/08 commits on `main`)  
Identity: `me.dialogjumper.dev` / **DialogJumper Dev** (dedicated keychain; no hardened runtime)  
Lab machine: macOS **15.7.4** (24G517), Apple silicon (arm64)  
How to run product:

```bash
apps/DialogJumper/scripts/run-dev-app.sh
```

Parent matrix (definitions, full OS×host gate):  
`.scratch/macos-file-dialog-jumper/assets/file-dialog-support-matrix.md`  
Product spec: `.scratch/macos-file-dialog-jumper/assets/mvp-spec.md`

---

## 1. Legend (same as matrix)

| Code | Meaning |
| --- | --- |
| **PASS** | Scenario exercised on this build/lab; product behaved as required |
| **FAIL** | Exercised; did not meet requirement |
| **DEG** | Degraded but safe (no harmful action; visible recovery) |
| **OUT** | Out of scope by policy (must stay zero-action) |
| **REQ** | Required before a **release support claim**; not green yet on this pack |

**Rule:** Unrun cells stay **REQ** (or blank). Never rewrite REQ as PASS without a dated record.

---

## 2. What this pack is / is not

| Is | Is not |
| --- | --- |
| Minimal **repeatable** regression + result log for the **current lab** | Full OS×host release matrix filled green |
| Honest split: **lab PASS** vs **still REQ** | Claim “supports all macOS Open/Save hosts” |
| Safety spot-check (unknown UI zero-action; no Open/Save submit) | Replacement for `swift test` (that suite is separate) |

Automated Core suite (logic gate, every commit):

```bash
cd apps/DialogJumper && swift test && swift build
```

Last main-session recheck: **52 tests / 8 suites passed** (2026-07-12).

---

## 3. Minimal regression pack (must-run)

Run with Accessibility **on** for Dialog Jumper unless the step says otherwise.  
Record one block per scenario (template §5).

### R1 — TextEdit Open + spaced path

| Field | Value |
| --- | --- |
| Steps | TextEdit → File → Open… → wait for side toolbar → Path `/Library/Application Support` → Jump |
| Expect | Panel location = that folder; **Open not pressed**; toolbar status shows success |
| Safety | No wrong-app keys; no auto Open |
| **Result** | **PASS** |
| Evidence | Owner manual (tickets 03–04 Path jump; spaced path in product README scenario). Lab OS 15.7.4 |
| Tester / date | Owner + implementation sessions, 2026-07-12 |

### R2 — At least one host Save panel

| Field | Value |
| --- | --- |
| Steps | e.g. TextEdit → File → Save / Save As… (system Save panel) → toolbar attach → Path jump to `/tmp` or `~/Desktop` |
| Expect | Same jump chain; **Save not pressed** for user |
| **Result** | **REQ** (product HITL on Save **not recorded** in this pack’s owner sign-off; mechanism OK on DialogHost/Save in research prototypes) |
| Notes | Fill this row before claiming “Open+Save” support in marketing |

### R3 — Negative sample (non-standard / not eligible) → zero action

| Field | Value |
| --- | --- |
| Steps | Open a **custom** picker if available (e.g. VS Code / Electron style) **or** invoke Focus Path / Jump with **no** system panel |
| Expect | No attach (or no jump); host UI untouched; optional “No standard File Dialog…” if user invoked Focus/Jump |
| **Result** | **PASS** (partial) |
| Evidence | (a) No panel: owner ticket **08** — Focus/Jump shows honest no-dialog copy, zero host mutation. (b) Unit: fingerprint rejects title-only / weak signals (`FileDialogFingerprintTests`). (c) Fixed Electron custom picker host: still **REQ** for a named third-party negative cell |
| Tester / date | Owner 08 hand-test + unit suite, 2026-07-12 |

### R4 — Accessibility denied / revoked smoke

| Field | Value |
| --- | --- |
| Steps | With app running and (optional) toolbar up: System Settings → Privacy & Security → Accessibility → turn **off** Dialog Jumper |
| Expect | Chrome dismissed; Folder Jump paused; **Revoked** (or paused) copy; Settings + **Recheck** (no prompt storm); re-enable + Recheck/Relaunch → Ready |
| **Result** | **PASS** |
| Evidence | Owner ticket **08** hand-test, 2026-07-12 |
| Tester / date | Owner |

### R5 — Illegal / bad path smoke

| Field | Value |
| --- | --- |
| Steps | Eligible Open panel → Jump to non-existent path or free text |
| Expect | Visible failure (`PathResolver` / `FolderJumpFailure` message); no Open/Save; dialog remains for retry |
| **Result** | **PASS** |
| Evidence | Owner ticket **08** jump-fail path; unit `PathResolverTests` + jump gate tests |
| Tester / date | Owner + automated, 2026-07-12 |

### R6 — Safety gate spot-check (always with R1–R5)

| Gate | Result | Notes |
| --- | --- | --- |
| Unknown / non-eligible UI → zero harmful action | **PASS** | R3 + detector gate |
| Failure never submits Open/Save | **PASS** | Jump executor contract + owner 03–08 |
| No false “authorized” without `AXIsProcessTrusted` | **PASS** | AccessibilityGate + 08 Recheck |

---

## 4. Lab PASS vs still REQ (release honesty)

### 4.1 Lab PASS on this pack (macOS 15.7.4, arm64, dev-signed app)

- Accessibility ready/paused/revoked recovery (08)
- Detect + attach toolbar on **TextEdit Open**
- Path / Recents / Favorites jump path (no global shortcut; 07 cancelled)
- Spaced absolute path jump
- Bad path / no dialog / revoke UX
- Automated Core suite (52)

### 4.2 REQ before expanding **support claims** (do not advertise as done)

| Item | Why REQ |
| --- | --- |
| macOS current−1 and current−2 majors | Matrix gate; only 15.7.4 lab here |
| Save panel on ≥1 product host (R2) | Not owner-recorded on this build |
| ≥3 Apple AppKit hosts Open (Preview, Pages/Mail, …) | Only TextEdit heavily exercised |
| ≥1 third-party **system** panel host | Not recorded |
| Named Electron/custom picker negative cell | Unit + no-panel only |
| Clean TCC first-run denied (fresh identity) | Revoke mid-session tested; cold denied thinner |
| Multi-display toolbar geometry polish | Known residual |
| 简体中文 locale pass | Not recorded this pack |
| Developer ID / notarized shipping identity | Dev cert only |

### 4.3 OUT (must remain zero-action)

- Electron/Qt/custom pickers that are **not** system Open/Save panel service  
- In-app browsers / web file inputs without system panel  
- Generic alerts without file-panel fingerprint  

---

## 5. Per-cell record template (copy for new runs)

```text
Date:
OS:
Hardware:
Build/commit:
Identity (bundle id / signing):
Host app + version:
Panel: Open | Save
Locale:
Path / scenario id (R1–R5):
AX trusted before: true|false
Fingerprint / attach: pass|fail (notes)
Jump: pass|fail|n/a
Evidence: visual | where-popup | screenshot
Open/Save submitted by product: no|yes (bug if yes)
Pointer global move: no|yes
Result code: PASS|FAIL|DEG|OUT|REQ
Tester:
```

---

## 6. How to re-run this pack (release candidate)

1. Note OS + commit + signing identity.  
2. `cd apps/DialogJumper && swift test && swift build` → must green.  
3. `./scripts/run-dev-app.sh` (or shipping bundle).  
4. Execute R1–R5; fill template rows.  
5. Update §3 result codes and §4 REQ list — **never** greenwash unrun OS/hosts.  
6. Full matrix OS×host only when marketing claims expand (see parent matrix §6).

---

## 7. Ticket 09 checklist map

| Checkbox | Where satisfied |
| --- | --- |
| Minimal pack + results | §3 R1–R5 |
| Legend PASS/FAIL/DEG/OUT | §1 + per-row Result |
| Lab PASS vs REQ documented | §4 |
| Safety spot-check | §3 R6 |

---

## 8. Residual

- HITL Save (R2) and multi-host cells intentionally **REQ** until owner dates them.  
- This pack certifies **lab honesty**, not App Store / multi-OS support.  
- Global shortcut is **out of MVP** (implementation ticket 07 cancelled); matrix “optional accelerator” not part of this pack.
