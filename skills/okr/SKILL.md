---
name: okr
description: "Track objectives and their key results (OKRs) one altitude above the work tracker: a north-star objective plus measurable KRs (metric, baseline, target, current, status), each linking down to the docs/tracker/<slug>.md work that moves it. Outcomes here, outputs in the tracker. Use when the user says 'set a goal', 'define objectives', 'OKRs', 'key results', 'north star', 'what are we aiming for', 'quarterly goals', 'track progress toward', '/okr', or before starting a multi-objective planning period."
---

# Goals & Key Results

Objectives and their key results live in **one file per planning period**: `docs/goals/GOALS.md`. A goal is an **outcome** (a metric moving), not an **output** (a task shipping). Outputs live in the work tracker; a KR links down to the tracker(s) that move it.

Altitude, top to bottom:

| Layer | Owns | Unit | Lives in |
|---|---|---|---|
| **goal** (this skill) | outcomes | objective + KR (metric) | `docs/goals/GOALS.md` |
| **work-tracker** | outputs | work item (task) | `docs/tracker/<slug>.md` |
| task list | session steps | checkbox | ephemeral, in-session |

## Red Flags — STOP if you're:

- Setting a goal for a single deliverable — that is a work item; use the tracker or task list
- Writing a KR with no metric or target — if it can't be measured, it's a task, not a key result
- Restating a tracker work item as a KR — the KR is the outcome; the tracker item is the task that moves it
- Carrying more than ~5 objectives in a period — OKRs lose meaning past a handful; drop or merge
- Updating a `Current` value without evidence (a measurement, command, dashboard, or SHA)
- Duplicating status between `GOALS.md` and a tracker — the KR shows the metric; the tracker shows the tasks
- Rewriting the whole file to move one number — Edit the `Current` cell, recompute two bars

**A goal is a metric with a target. Outcomes here, outputs in the tracker. Update with evidence.**

---

## When a goals file is warranted

Create `docs/goals/GOALS.md` only when work spans **multiple objectives across a planning period** (a quarter, a milestone) and involves more than one stream of tracker work. A single feature or bug does not get an objective — it gets a tracker row or a task-list entry.

## Layout

```
docs/goals/
  GOALS.md              # current period's objectives + KRs. Read whole.
  archive/<period>.md   # closed periods, e.g. 2026-Q2.md
```

Unlike the sharded tracker, `GOALS.md` is a **single file read whole** — objectives are few and reviewed together. On period close, move it to `archive/<period>.md` and start a fresh `GOALS.md`.

## Objective & KR format

- **Objective** — one qualitative, directional line. Inspiring, not measurable. `O1`, `O2`, …
- **Key Result** — one measurable outcome. `O1-KR1`, `O1-KR2`, … Fields: metric, baseline, target, current, status, work link.
- IDs are namespaced by objective so they stay short and never collide.

Bars appear only on the **overall** and **objective** header lines — never per KR row — so a metric tick edits one cell plus two header bars, never the whole file.

### Attainment

- Per KR: `attainment = clamp01((current − baseline) ÷ (target − baseline))`. Direction-agnostic — set `baseline`/`target` correctly and a "decrease latency" KR computes the same way as an "increase revenue" one. Baseline must differ from target: equal values mean nothing has to move, which makes it a task, not a KR — route it to the tracker.
- Per objective: mean of its KR attainments, `dropped` KRs excluded.
- Overall: mean of objective attainments.
- Bar: 10 cells `█`/`░`, then percent. Same rendering as the tracker index.

### Status

A KR's status is a **confidence call**, separate from mechanical attainment: `on-track`, `at-risk`, `off-track`, `met`, `dropped`. A KR at 90% attainment can still be `at-risk` if the last 10% is the hard part. Only these five. `dropped` KRs are struck and excluded from every count and mean.

## Verify-first protocol (mandatory)

Before updating a `Current` value or marking a KR `met`, write no change until all four pass:

1. **Re-read** the KR row and the linked tracker(s).
2. **Verify the metric with evidence** — a measurement, command output, dashboard, or SHA. Never move a number from memory or optimism.
3. **Confirm the KR still maps to a live objective** — superseded → `dropped`.
4. **Update `Current` + status**, note the evidence, recompute the objective bar and the overall bar.

Embed these four lines verbatim at the top of `GOALS.md`.

## Read & edit discipline (the token budget)

- Default read is `GOALS.md` whole — it is small and reviewed as a set.
- Move a metric with an `Edit` on the one `Current` cell, then recompute the two header bars. Never rewrite the file.
- Recompute **only the touched objective's bar** and the overall line. Leave other objectives untouched.
- Report the delta only: which KR moved, old → new, new attainment. Never mirror the whole table back into chat.
- Evidence goes inline as the source note on the row. **No changelog or history section** — git log is the record.

## Template

`docs/goals/GOALS.md`:

```markdown
# Goals — 2026-Q3

> Verify-first: 1) re-read KR row + linked tracker · 2) verify the metric with evidence ·
> 3) confirm the KR still maps to a live objective · 4) update Current + status, recompute bars.

**Overall [██████░░░░] 58%** · on-track 2 · at-risk 1 · off-track 0 · met 1 · dropped 0

## O1 · Make the product feel instant
`[██████░░░░] 58%` · Horizon: 2026-Q3 · Owner: <name>

| KR | Metric | Base | Target | Current | Status | Work |
|----|--------|------|--------|---------|--------|------|
| O1-KR1 | p95 latency (ms) | 800 | 300 | 520 | at-risk | [perf](../tracker/perf.md) |
| O1-KR2 | error rate (%) | 2.0 | 0.5 | 0.5 | met | [reliability](../tracker/reliability.md) |

## O2 · Grow weekly active teams
`[███░░░░░░░] 30%` · Horizon: 2026-Q3 · Owner: <name>

| KR | Metric | Base | Target | Current | Status | Work |
|----|--------|------|--------|---------|--------|------|
| O2-KR1 | weekly active teams | 40 | 100 | 58 | on-track | [onboarding](../tracker/onboarding.md) |
```

## Workflow

```
1. Multiple objectives across a period, multi-stream work? No → tracker row or task list. Stop.
2. Read docs/goals/GOALS.md; absent → scaffold from the template.
3. Frame each objective (qualitative) and its KRs (metric, baseline, target). No metric → it's a task, route to the tracker.
4. For each KR, link the tracker(s) that move it in the Work column. Create the tracker via /work-tracker if missing.
5. To report progress: run verify-first on the KR, Edit the Current cell + status, recompute the objective bar + overall bar.
6. Period closes → move GOALS.md to archive/<period>.md, start fresh.
7. Report the delta only: KR moved, old → new, new attainment.
```
