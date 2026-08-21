---
name: work-tracker
description: "Route long-form work products into the right docs/ location and track status in a sharded tracker (docs/tracker/INDEX.md + one file per major work). Enforces read-one-file token discipline and the verify-first protocol: re-confirm a gap still exists against main before writing any code. Use when the user says 'build a work tracker', 'consolidate status', 'reconcile the docs', 'where should this go', 'track this work', 'start a backlog', '/work-tracker', or before starting any multi-item backlog."
---

# Work Tracker & Docs Routing

Status lives in a **sharded tracker**: a thin index plus one file per major work. Detail lives in source docs. Verify a gap before building it.

Sharding exists for token economy — you read the index (cheap, bounded) and open exactly the one tracker you need, never the whole backlog.

## Red Flags - STOP if you're:

- Reading more than one tracker file for a single task
- Rewriting a whole tracker file to flip one row (Edit the row instead)
- Creating a tracker for work under ~5 items or one session — use the in-session task list
- Restating an item in more than one place — one item, one line, one file
- Implementing a backlog item without re-verifying the gap exists on main
- Putting status in a plan/audit/design doc instead of the tracker
- Marking a row DONE without evidence (SHA, PR, or grep hit)
- Marking `blocked:` without naming the blocking ID, or starting a blocked item

**One item, one line, one file. Read the index, open one tracker. Verify before coding.**

---

## Part A: Output Routing

Long-form **non-code** output (>~20 lines) goes to a file; chat gets a 3-5 bullet summary + the path.

| Output type | Destination |
|---|---|
| Report / analysis | `docs/` |
| Research | `docs/research/` |
| Plan | `docs/` or `draft/` |
| Audit | `docs/audit/` |
| Goals / OKRs | `docs/goals/GOALS.md` — owned by the `okr` skill |
| Tracker index | `docs/tracker/INDEX.md` |
| Per-work tracker | `docs/tracker/<slug>.md` |

**Exempt, stays inline:** code, diffs, test output, review feedback.

Register new docs in the project's docs index.

## Part B: Sharded Tracker

### When a tracker is warranted

Create or update a tracker only when work is **≥5 items or spans sessions**. Below that, the in-session task list is the whole system — a tracker file is pure overhead.

Beyond that threshold, build/reconcile when: status is scattered across docs, the user asks to consolidate/track, or you're starting a multi-item backlog.

### Layout

```
docs/tracker/
  INDEX.md            # rollup only — one line per tracker. The default read.
  <slug>.md           # one major work: items + verify protocol
  archive/<slug>.md   # finished; INDEX keeps a single line
```

**One tracker per major work** — a feature, a migration, an audit remediation. IDs are namespaced by tracker (`AUTH-1`, `PERF-7`), so they stay short and never collide.

### Size caps (enforce, don't drift)

| File | Cap | On breach |
|---|---|---|
| `INDEX.md` | ~40 lines | archive finished trackers |
| `<slug>.md` | ~20 open items / ~100 lines | split into two trackers, or archive shipped items |

When a tracker's items are all DONE: move it to `archive/`, collapse its INDEX row to one `done` line.

### Item format — one line, no duplication

```
- [ ] AUTH-3 · swap token middleware · P1 · blocked:AUTH-2 · docs/auth.md
- [x] AUTH-2 · provider config · a1b2c3d
- [x] ~~AUTH-5~~ · superseded by OIDC default · won't-do
```

Fields, `·`-separated, all optional after the summary: priority, `blocked:<ID>`, source-doc path. A DONE row carries its evidence (SHA/PR) and drops everything else. There is **no** separate backlog table, detail section, or source-doc map — the row is the only representation.

Multi-step items nest; parent stays `- [ ]` until every child is checked:

```
- [ ] AUTH-4 · migrate auth to OIDC · P0 · docs/auth.md
  - [x] provider config
  - [ ] token middleware
```

### Status

`- [x]` = done. `- [ ]` = everything else. In-progress is marked by partially-checked subtasks or a `wip` tag — not a taxonomy. `won't-do` rows are struck and excluded from counts.

Do not add further states. A row is done or it is not; anything else is deliberation the reader ignores.

### Progress

Bars live **only in INDEX.md**, one per tracker plus an overall. Individual trackers carry no bar — it would go stale on every edit and force a rewrite.

- 10 cells, `█`/`░`, then percent and counts.
- Percent = `(done + 0.5 × wip) ÷ (total − won't-do)`, rounded.
- Recompute **only the touched tracker's row** and the overall line. Leave other rows untouched.
- Keep concurrent wip ≈3 or fewer; finishing beats starting.

### Verify-first protocol (mandatory)

Before starting any item, write **no code** until all four pass:

1. **Re-read** the item row and its source doc.
2. **Verify the gap exists on main** — `git log` for related commits **and** `grep` the named symbol. Already there → gap closed.
3. **Confirm still required.**
4. **Flip stale rows with evidence** — shipped → `- [x]` + SHA; obsolete → struck + `won't-do`.

Embed these four lines verbatim at the top of each tracker.

### Read discipline (the token budget)

- Default read is `INDEX.md` alone. Open a `<slug>.md` only when you act on it.
- Locate a row with `grep -n '<ID>' docs/tracker/<slug>.md`, not a full Read.
- Flip a row with `Edit` on that one line. Never rewrite the file to change status.
- Reconcile **only the tracker you touched**. A repo-wide sweep happens on explicit request, not per task.
- Never mirror tracker detail back into chat — report the delta (rows flipped, new percent).

### Maintenance

- Evidence goes inline on the DONE row. **Never add a changelog or status-history section** — git history is the log.
- Retiring a superseded doc: repoint inbound references to the tracker **first**, then delete.
- Detail stays in source docs; status stays in the tracker. Never both.

## Templates

`docs/tracker/INDEX.md`:

```markdown
# Tracker Index

**Overall: [░░░░░░░░░░] 0% — 0/0**

| Tracker | Progress | Open | Note |
|---|---|---|---|
| [auth](auth.md) | `[░░░░░░░░░░] 0%` | 0 |  |
```

`docs/tracker/<slug>.md`:

```markdown
# <Work name>

> Verify-first: 1) re-read row + source doc · 2) `git log` + grep the symbol on main ·
> 3) confirm still required · 4) flip shipped/obsolete rows with evidence. Then code.

- [ ] AUTH-1 · <one line> · P1 · `docs/<source>.md`
```

## Workflow

```
1. Routing-only? → Part A destination → write file → 3-5 bullets + path → register in docs index.
2. <5 items / single session? → in-session task list, no tracker file. Stop.
3. Read docs/tracker/INDEX.md. Pick the matching tracker; absent → scaffold one from the template
   and add its INDEX row.
4. Open that ONE tracker. Run verify-first on the item. Gap closed → Edit the row to [x] + evidence.
5. Execute. Expand multi-step items into the in-session task list; collapse back to checkboxes at the end.
6. Edit the touched rows; recompute that tracker's INDEX row + the overall bar.
7. All items done → move to archive/, collapse the INDEX row.
8. Report the delta only: rows flipped, new percent.
```
