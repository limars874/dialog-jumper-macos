---
name: flow-progress
description: Rewrite the resume snapshot at docs/progress.md. Use after finishing a meaningful step, when the next action changes, or when a key decision or blocker changes — so a fresh session can pick up where this one left off.
---

# Rewrite the resume snapshot

Keep `docs/progress.md` current, so a fresh session can continue from it alone. Write it in the format in [PROGRESS-FORMAT.md](./PROGRESS-FORMAT.md).

## The test that tells you it's good

Ask: **if the context vanished right now, could the next run continue from this file alone?** If not, something's missing — add it. If a line wouldn't help that next run, cut it.

The snapshot is done when it passes that test and reads as the current state.
