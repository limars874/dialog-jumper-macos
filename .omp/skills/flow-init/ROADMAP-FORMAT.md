# roadmap.md Format

`docs/roadmap.md` holds the plan (what, in what order) and the progress (what's done) in one file. Its file-level `Status` says whether it is committed direction. No time estimates.

## Structure

```md
# Roadmap

> Status: draft
> Owner confirmation required before this document guides future work.

## Milestones
- 🚧 M1 <current milestone, one line>
- 📋 M2 <next>

## Phases (current milestone)

### Phase 1 · <name>
- **Goal**: <one line, user-facing>
- **Depends on**: <none / Phase X>
- **Success criteria**: <2-5 observable behaviours>
- **Plans**:
  - [ ] 1-1 <plan, one line>

## Progress
| Phase | Plans done | Status |
|---|---|---|
| 1 | 0/1 | in progress |
```

## Rules

- **Status is file-level.** Use `confirmed` only when the file contains owner-provided or owner-confirmed direction. Use `draft` when material content is inferred from code, inferred from history, or filled in by the model. Missing status means draft.
- **Draft is not direction.** Use a draft roadmap as planning input, not as committed project direction.
- **Milestone → Phase → Plan.** A small project can use just Phases + a checklist.
- **Success criteria are observable, user-facing behaviours** — not implementation steps.
- **No time estimates.**
