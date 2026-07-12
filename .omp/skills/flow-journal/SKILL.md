---
name: flow-journal
description: Append a session record to docs/journal.md — what happened, what was decided, and the relevant refs. Use when wrapping a session or a meaningful chunk of work, or after a commit worth remembering.
---

# Record what happened

`docs/journal.md` is the append-only history of the project: what each session did and decided, in order. It answers "how did we get here" — the reasoning trail git commits don't hold. Write the entry in the format in [JOURNAL-FORMAT.md](./JOURNAL-FORMAT.md).

This is a capability, not a ceremony. Record at a natural wrap point — a session end, a milestone, a decision worth keeping — not after every step. Write only entries with **replay value**: a decision, turning point, or context that git and history alone wouldn't show. A journal that logs everything becomes noise no one reads.

Keep the three trace files distinct:
- **journal** — what happened this session, chronological (here).
- **progress** — where the work is now, a snapshot (flow-progress).
- **learnings** — the abstract lesson to apply next time (flow-reflect). A lesson may be drawn from a journal entry, but the two are separate lines.

The entry is done when it says what changed, what was decided and why, and points to the relevant refs — enough that a teammate reading it later knows what this session was about.

## Out of scope
Searching past raw conversation logs (the platform's own JSONL under `~/.codex/sessions/` etc.) is a retrieval capability for a future tool, not this skill. This skill only appends the written record.
