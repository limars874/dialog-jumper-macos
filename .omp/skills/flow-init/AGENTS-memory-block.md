<!-- The section flow-init writes into the repo-root AGENTS.md (OMP/Codex auto-loads it every session).
     A standalone section; leave setup's ## Agent skills block untouched.
     It costs context every turn, so keep it to reflexes that must always be present — the craft lives in the skills; this only points. -->

## Project memory (flow-light)

Memory lives in `docs/`.

- **At session start / on a new session / continuing a task**: read `progress.md` first to resume. If the current user message is the same task → trust it and continue; if it's a new task → judge from the message and rewrite progress via flow-progress.
- **Before acting**: read `constraints.md` if present. If its `Status` is `confirmed`, obey it; if `draft` or missing, use it only as review context. For direction read `roadmap.md` with the same status rule. For "how did we get here" read `journal.md`; for lessons read `learnings.md`; for a past decision's why read `docs/adr/`; for domain terms read `docs/context.md`.
- **Main-line priority**: current user message > code and verification evidence > confirmed memory files > `progress.md` (progress only) > draft memory files and history.
- **Maintenance**: one event can qualify for several trace files — apply each skill's own bar, in this order, and skip what doesn't clear it: `flow-progress` whenever the resume state changed (cheap, usually yes); `flow-journal` only if the wrap has replay value; `flow-reflect` only if a lesson cost real time. Never write the same content to two files.
