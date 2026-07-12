# constraints.md Format

`docs/constraints.md` tells a future agent **how to work in this repo** — the durable rules every task obeys. Its file-level `Status` says whether the document is binding.

## Structure

```md
# Constraints

> Status: draft
> Owner confirmation required before this document is binding.

## Stack (locked choices — don't swap without reason)
- All HTTP goes through `src/lib/http.ts`, not fetch/axios directly — one place for retry + auth.

## Architecture
- Accessibility reads stay in the detection layer, not app lifecycle or UI.
  - Evidence: `NativeDialogDetector`, `NativeDialogClassifier`.
  - Avoid: reading AXUIElement from a coordinator or a view controller.

## Style (conventions the code can't reveal on its own)
- Money is always the `Money` type, never a bare number.

## Large constraint sets (split out when big)
- Frontend: see `docs/frontend.md`
- Backend: see `docs/backend.md`
```

## Rules

- **Status is file-level.** Use `confirmed` only when the file contains owner-provided or owner-confirmed content. Use `draft` when material content is inferred from code, inferred from history, or filled in by the model. Missing status means draft.
- **Draft is not binding.** Use draft constraints as review context, not as rules future tasks must obey.
- **A constraint is how to work in *this* repo — a durable local pattern, not generic advice and not the current structure.** Write the boundary, layering, or dependency direction that survives a refactor. Which type currently does what, and one-off mechanisms (keybindings, MVP flows, exact UX), are implementation facts, not constraints — leave them out.
- **Write from evidence; the file is proof, not the subject.** Back each rule with a source/test file or a pattern repeated across files, cited as evidence — "AX reads stay in the detection layer; evidence `NativeDialogDetector`", never "`NativeDialogDetector` exclusively does AX reads" (which locks the type, so any refactor reads as a violation). Never build a rule from a single accidental implementation detail.
- **Name the anti-pattern when it sharpens the rule.** A short "Avoid: …" makes a boundary concrete without pinning it to one type.
- **Few strong boundaries beat an inventory.** A handful of real layering / dependency / seam rules is worth more than a per-file list of who does what.
- **Rules, not terms or rationale.** A domain term belongs in `docs/context.md`; a one-off decision's why belongs in `docs/adr/`; a standing rule belongs here.
- **Split when it grows.** When frontend or backend constraints get long, move them to `docs/frontend.md` / `backend.md` and leave a pointer here.
