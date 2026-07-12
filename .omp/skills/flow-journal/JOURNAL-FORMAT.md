# journal.md Format

`docs/journal.md` is append-only, newest at the bottom. One entry per session or meaningful chunk of work.

## Structure

```md
# Journal

## [2026-07-09] <session title>
- **Did**: <outcome, one or two lines>
- **Decided**: <key decisions + why; "none" only if the entry earns its place another way>
- **Refs**: <commit sha, issue, PR, key files, or (none)>
```

## Rules

- **Append, never rewrite.** History stays — this is the opposite of progress.
- **Real dates only.** Take the date from the environment or `date +%F` — don't guess it.
- **Record decisions and why, not diffs.** git already holds the diffs; the journal holds the reasoning git can't.
- **One entry per wrap point, not per action.** If nothing worth remembering happened, write nothing.
- **History, not instruction.** A journal entry explains what happened; it doesn't override the current user message, code, confirmed constraints, confirmed roadmap, or ADRs.
