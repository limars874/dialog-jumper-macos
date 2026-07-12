---
name: flow-init
description: Set up the flow-light memory layer for this repo — create the docs/ memory files and wire AGENTS.md so the host reads them. Run once, after setup-matt-pocock-skills.
disable-model-invocation: true
---

# Set up the flow-light memory layer

Scaffold the project memory the companion flow relies on, and teach the host to read it:

- **Resume state** — `docs/progress.md`, the snapshot a fresh session reads to continue
- **Constraints** — `docs/constraints.md`, the project-wide rules every task obeys after owner confirmation
- **Roadmap** — `docs/roadmap.md`, the milestones work rolls up to after owner confirmation
- **Lessons** — `docs/learnings.md`, what past runs learned

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write. It is idempotent: update files in place and preserve the user's edits.

Run after `setup-matt-pocock-skills` — that skill owns the issue tracker, triage labels, domain docs, and `docs/context.md`. This skill owns only the memory layer and leaves setup's files alone.

## Process

### 1. Explore
Read the current state; don't assume:
- `AGENTS.md` at the repo root — does it already hold setup's `## Agent skills` block? (The memory section co-locates there.) Read `CLAUDE.md` only to confirm whether it delegates to `AGENTS.md`. Is there already a `## Project memory (flow-light)` section, and in which file?
- `docs/` — do `progress.md` / `constraints.md` / `roadmap.md` / `learnings.md` already exist?
- Whether the repo has real code (brownfield — constraints can be inferred) or is empty (greenfield).

### 2. Present findings and ask
Summarise what's present and what's missing, then settle the memory section in `AGENTS.md` — the setup section and memory section should live side by side:
- If setup's `## Agent skills` block already exists in `AGENTS.md`, write the memory section right after it. Don't split active project rules across `AGENTS.md` and `CLAUDE.md`.
- If setup hasn't run, create or update `AGENTS.md`; leave `CLAUDE.md` as a compatibility shim when present.
- If a `## Project memory (flow-light)` section already exists in a different file, say so and move it beside setup's block in `AGENTS.md`.
- **Host-readability check**: the memory layer only works if the host auto-loads the file every session. OMP/Codex reads `AGENTS.md`; a perfectly co-located section the host never reads is worthless.

For a brownfield repo, also confirm you'll read the code to draft the constraints, and they'll review that draft before it's binding.

### 3. Write the skeleton
Create any missing file in `docs/`, each in its owning format:
- `progress.md` — the flow-progress skill owns its format; seed it minimal:
  ```md
  # Resume snapshot
  ## Goal
  Set up the flow-light memory layer
  ## Doing now
  idle
  ## Key context
  (none)
  ## Next
  (none)
  ## Blockers
  (none)
  ```
- `constraints.md` — see [CONSTRAINTS-FORMAT.md](./CONSTRAINTS-FORMAT.md); set file `Status` from the source of its content.
- `roadmap.md` — see [ROADMAP-FORMAT.md](./ROADMAP-FORMAT.md); set file `Status` from the source of its content.
- `learnings.md` — just a `# Lessons` heading; the flow-reflect skill owns its entry format.
- `journal.md` — just a `# Journal` heading; the flow-journal skill owns its entry format.

Then add a `## Project memory (flow-light)` section to `AGENTS.md` (from [AGENTS-memory-block.md](./AGENTS-memory-block.md)), beside setup's `## Agent skills` block. Update it in place if it already exists; leave setup's block untouched. Keep `docs/progress.md` tracked in git, so any machine can resume.

### 4. Infer constraints (brownfield only)
You're mapping the code to find **durable local patterns** — how to work in *this* repo — not cataloguing the current structure. Reading code tells you what *is*; a constraint is what *should hold across refactors*. Start from the code and let the rules follow; don't fill a generic template. **Write from evidence**: a rule needs a source/test file or a pattern repeated across files behind it — never a single accidental detail. And **abstract each observation up to a boundary** (see CONSTRAINTS-FORMAT): "AX reads stay in the detection layer; evidence `NativeDialogDetector`" — never "`NativeDialogDetector` exclusively does AX reads". Which type does what, and current mechanisms (keybindings, MVP flows, exact UX), are implementation facts — leave them out unless they express a boundary that should survive a refactor.

Sweep in focused passes and abstract each into a principle:
- **Stack** — package.json / pyproject / lockfiles / config → the locked stack and libraries → `## Stack`.
- **Architecture** — directory layout, module boundaries, import direction → the layering / dependency-direction rules → `## Architecture`.
- **Style** — conventions the code holds consistently but that aren't self-evident → `## Style`.

Prefer a handful of strong boundaries over a per-file inventory. Route by kind: a domain term belongs in `docs/context.md` (domain-modeling's territory), a rule belongs in constraints. Report that a secrets file exists; read its values never. Mark anything uncertain "unsure". Existing code is evidence for a draft, not product intent by itself.

Set status by source: `confirmed` only when the file contains owner-provided or owner-confirmed content; `draft` when material content is inferred from code, inferred from history, or filled in by the model. If mixed or uncertain, use `draft` and show the user what needs confirmation.

### 5. Confirm and finish
Show the drafted `constraints.md` (and `roadmap.md`) to the user before relying on them — durable memory earns a human pass. Only confirmed documents are binding. Let them edit. Then set `progress.md` to the user's real task, or "idle".

Append the first entry to `journal.md` (`## [<date>] <title>` with **Did** / **Decided** / **Refs** bullets — the flow-journal skill owns the format), recording the initialization: greenfield or brownfield, which memory files were created, the `Status` of constraints/roadmap, the owner's choices, and the next useful step. Keep it short — it records the event, not the content of constraints or roadmap. This is the trace line's origin entry.

Tell the user the memory layer is live, and that `flow-progress`, `flow-journal`, and `flow-reflect` maintain it from here.
