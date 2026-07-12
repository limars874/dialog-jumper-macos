---
name: flow-reflect
description: Record a lesson. Use when a fix took 2+ verification loops, debugging ran past 3 attempts, you changed approach mid-task, or the user corrected a wrong assumption.
---

# Record a lesson

A **lesson** is abstract guidance the next run applies — a heuristic, not a snippet. Write what to do differently, in a line or two; a concrete code template anchors the next agent on the wrong details.

1. State the lesson as guidance the next run would follow. One idea, ≤2 lines.
   - Done when a fresh agent, reading that line alone, knows what to do differently — with no code to copy.
2. Append it to `docs/learnings.md`:
   `- [<date>] <lesson> — context: <what worked / what failed, one clause>`
   Take the date from the environment or `date +%F` — don't guess it.
3. If the lesson is stable and worth making a hard rule, propose graduating it: draft it as a constraint, show the owner, and add it to `docs/constraints.md` only on their confirmation. **`Status` is file-level**, so mind the file it lands in:
   - If `constraints.md` is `Status: confirmed`, the confirmed rule goes in and stays binding.
   - If it's `draft` (or missing status), a confirmed rule buried in a draft file binds nothing — so graduating is also the moment to ask the owner to review the whole file and flip it to `confirmed`. If they won't confirm the file yet, the lesson stays in `learnings.md` as guidance; don't add it to a file that can't carry it.
   A one-off stays in learnings.
4. On graduation, **delete the lesson's entry from `docs/learnings.md`** — a rule lives in exactly one place, and it now lives in constraints. Keeping both means drift and double injection. If the graduation is worth remembering, the journal records it; learnings holds only live guidance.

Record only lessons worth the next run's attention — a surprise that cost real time, not a routine step.
