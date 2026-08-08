# dotai

AI coding tool configs that reduce wasted tokens and prevent scope creep — for Claude Code, Cursor, and GitHub Copilot.

## Install

```bash
git clone https://github.com/mayurpise/dotai.git
cd dotai
./install.sh --config
```

See the [repo](https://github.com/mayurpise/dotai) for all options.

---

## Why dotai

Why [CLAUDE.md](https://github.com/mayurpise/dotai/blob/main/CLAUDE.md) and the skills under [`skills/`](https://github.com/mayurpise/dotai/tree/main/skills): two levers that shape LLM behavior. **CLAUDE.md** controls _how_ the model responds in every session; the skills control _what_ it does in specific high-risk workflows (`/scrub` for code cleanup, `/xreview` for high-signal review of a PR or diff, `/minimalist` for writing and restructuring code with a minimal diff, `/lean-python-docs` for keeping Python documentation lean, `/work-tracker` for durable cross-session status, `/okr` for objectives and key results above that status). Together they reduce wasted tokens, prevent scope creep, and make outputs reliably actionable.

### CLAUDE.md

**Token Efficiency**

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Absolute Mode** | Eliminates filler, hedging, emotional softening, continuation bias. A typical Claude response without guidance adds 20-40% padding — this strips it. |
| **Output routing** | Reports >20 lines go to a file; console returns 3-5 bullets. Prevents the context window from being consumed by long inline prose. |
| **Gated clarifying questions** | "Ask only when blocked" stops the back-and-forth loop that doubles session length. LLMs default to asking; this default is reversed. |
| **Thinking frameworks as conditionals** | Frameworks (First Principles, Expert Panel, etc.) only fire when the trigger condition matches. Without this, models apply heavy reasoning scaffolding to trivial prompts. |
| **No comments by default** | Cuts generated code size. Comments on obvious code are pure token waste in both generation and future context loads. |

**Steering Better Decisions**

**Simplicity First + Surgical Changes** work as a pair against the LLM's strongest failure mode: pattern-matching to "best practices" and gold-plating. Models trained on public code associate quality with abstractions, interfaces, and configurability. These rules explicitly override that bias:
- "Minimum code that solves the problem" — no strategy patterns for a single calculation
- "Touch only what is required" — no opportunistic reformatting, type-hint additions, or adjacent cleanup
- The anti-patterns table gives _negative_ examples, which suppresses trained associations more effectively than positive rules alone

**Goal-Driven Execution** converts vague tasks into verifiable checkpoints before the model touches code. This matters because LLMs default to optimistic execution — they start writing and discover ambiguity mid-flight, which leads to restarts and rework. Stating assumptions upfront surfaces disagreements cheaply.

**Precedence ordering** (User Prefs → Absolute Mode → Coding Guidelines → Workflow) gives the model an explicit conflict-resolution rule. Without it, models blend instructions inconsistently when they conflict.

**Workflow Rules** (test before commit, clean status before push, conventional commits) encode guardrails that prevent the most common agentic failure: a model that makes changes, declares success, and leaves the repo in a broken state.

---

### skills/scrub

**Token Efficiency**

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Phase 1: scope upfront** | Globs and reads every source file once before agents launch. The three agents share that single read pass instead of each re-globbing and re-reading independently — a 3x cut in file-IO tokens. Also forces the user to confirm the target directory when missing, so agents never wander off-scope. |
| **Phase 2: three parallel agents** | Wall-clock time cut by ~3x vs sequential. Each agent receives the same file list but focuses on one dimension (reuse / quality / efficiency), preventing cross-contamination that bloats findings. |
| **Structured report template** | Exact schema (Applied / Skipped / Pending / Budget) means the LLM doesn't improvise format. Format improvisation inflates output tokens and makes results hard to parse programmatically. |
| **Budget caps (30 findings / 500 lines)** | Hard stops a runaway session before it consumes unbounded context. Also forces prioritization — the model must rank, not just list. |

**Steering Better Decisions**

**Tiered classification (T1/T2/T3)** is the central safety mechanism. It maps directly to risk:
- T1 (mechanical swap): apply freely — no human needed
- T2 (structural refactor): apply with per-file validation gate — catch regressions early
- T3 (semantic change): never apply silently — always confirm

Without this, models either over-apply (making risky changes autonomously) or under-apply (flagging everything as "needs review"). The tiers give precise autonomy boundaries.

**Skip category constraints** are unusually strong: only four valid reasons to skip a finding (output would change, test broke, project rule forbids it, or the changed Tier 2/3 surface is untested and can't be locked). "Low impact," "cosmetic," and "not worth it" are explicitly invalid. This prevents the model's natural conservatism — LLMs frequently self-censor findings they judge as minor, creating silent gaps in the audit. The constraint forces completeness.

**"Skipping is the exception, not the default"** in the opening line sets the execution posture before the model reads any rules. Framing bias is real: a prompt that opens with "be thorough" produces more findings than one that opens with "be careful." This phrasing front-loads the aggressive posture.

**Per-file commits** reduce the blast radius of any single bad application. One file = one revertable unit. Without this instruction, models batch changes across files into one commit, making targeted rollbacks impossible.

**Gates between tiers** (typecheck after T1, typecheck + tests after each T2 file) create mandatory feedback loops. Without gates, errors in early files compound silently into later files, and the final state is broken in ways the model can't attribute to a specific change.

---

### skills/xreview

**Token Efficiency**

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Diff-scoped, dimension-gated** | Reviews only changed code, and each conditional dimension runs only when the diff warrants it (silent-failure pass only if error handling changed, type-design only if a type changed). Unwarranted passes are never spent. |
| **Risk-ranked units in audit mode** | Audit mode is inferred from the request, not switched on by a flag — the model already knows whether it was asked about a change or about the code itself, so a mode switch would only add a way to get it wrong. It lifts the diff bound for brownfield code, but never reads a repo file-by-file: it inventories, ranks units by trust boundary / churn / untested surface, and reviews highest-risk first — so a truncated budget cuts the least valuable work, and the report names what it skipped. |
| **Validate-then-filter before output** | Candidate bugs are re-checked and everything under 80 confidence is dropped *before* the report is written, so tokens aren't spent describing findings that won't survive. |
| **One structured report shape** | Fixed Critical / Important / Suggestions / Strengths schema prevents format improvisation across runs and keeps the output parseable. |

**Steering Better Decisions**

**Two disciplines merged.** Broad coverage (nine dimensions catch whole classes of defect — bugs, security, performance, CLAUDE.md compliance, silent failures, test gaps, comment rot, weak type invariants, needless complexity) is paired with a strict validation gate. Coverage without the gate is noisy; the gate without coverage is narrow. Together they produce a report that is both wide and trustworthy.

**Adversarial validation as the trust mechanism.** Every bug, silent-failure, and CLAUDE.md candidate is re-checked with a refute-by-default pass that must state a concrete failure (which inputs → what wrong result) before the finding survives. This directly targets the plausible-but-wrong finding that erodes reviewer trust — the failure mode that makes teams ignore automated review.

**Confidence banding with an 80 gate** converts the model's natural tendency to surface everything into a ranked, filtered list. Below 80 is discarded; 80–89 is Important; 90–100 is Critical. The explicit false-positive list (pre-existing issues, linter-catchable nits, correct-but-suspicious code) names the exact categories to suppress.

**Path-scoped CLAUDE.md compliance** flags a violation only when the rule governs the changed file's path and can be quoted verbatim — preventing the common error of applying a rule out of its scope.

**Report-by-default, post-on-request** separates seeing findings from publishing them: terminal output always; inline PR comments only in PR mode with `--comment`. Outward-facing writes never happen implicitly.

---

## skills/minimalist

### Token Efficiency

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Classify-first gate (§0)** | Forces NEW / CHANGE / REFACTOR / MIXED up front. A mixed task is split before any code is touched, so the model never interleaves two intents and then unwinds the tangle — the single largest source of refactor rework. |
| **Manifest freeze before coding (§1)** | The model commits to exact files and signatures up front, so it cannot wander into unplanned files or abstractions mid-session. Unplanned scope is the largest source of wasted generation; freezing the surface area caps it. |
| **Definition of done as a hard stop (§2)** | Tests-as-spec for new behavior, lock tests for refactors — "stop when the named tests pass" is a termination signal. Without it, models keep elaborating extra branches, defensive checks, and speculative helpers long after the task is met. |
| **Deletion pass on the diff (§5)** | Every added function or parameter must justify itself in one line or be removed. This inverts the default additive bias, shrinking both the diff and the context every future session must load. |

### Steering Better Decisions

**Classify before coding** — one decision at the top selects the definition of done. NEW/CHANGE write tests *toward* intended behavior; REFACTOR writes characterization tests *against* current behavior (bugs included); MIXED must split into REFACTOR then CHANGE, never interleaved. This blocks the common failure of "improving" behavior under the banner of a refactor.

**Smallest diff, not least code** — a behavior-neutral rename or extract that *adds* lines is a success. The objective is the smallest change that satisfies the task type's definition of done, not the least total code. Stating the target explicitly stops the model from "cleaning up" during a refactor and silently changing behavior.

**Out-of-scope defaults** name the gold-plating explicitly — no abstraction under 3 call sites, no config for a single caller, no class where a function works, no error handling for impossible inputs. Models associate these patterns with quality; stating them as _defaults to avoid_ overrides the trained bias more reliably than a generic "keep it simple."

**Neutrality gate for refactors (§6)** — the same lock tests must pass unmodified before and after. "If you had to edit a test to make it pass, behavior changed" converts a fuzzy judgment into a hard, checkable rule. Bug-for-bug behavior is preserved unless fixing the bug *is* the task, in which case it reclassifies to a behavior change.

**Self-critique gate (§6)** makes the model report pass/fail on an explicit checklist (every line traces to a test, every abstraction has ≥3 call sites, no speculative generality, no unrelated edits, lock tests unchanged for refactors) before declaring done. An explicit checklist catches over-engineering that a vague "review your work" misses.

**Relationship to /scrub** — minimalist governs code being written or restructured; `/scrub` reviews code already written across a directory. The §5 deletion pass is a scrub on the model's own diff and hands off to `/scrub` for the surrounding tree.

---

## skills/lean-python-docs

### Token Efficiency

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Pre-write filter, not a cleanup pass** | The WHY-not-WHAT test is applied *as* each doc line is typed, so redundant docstrings and narrating comments are never generated — cheaper than writing them and stripping them later. |
| **One-line docstring default** | Public surfaces get a single summary line; a body is added only when a caller would otherwise get it wrong. Caps the largest source of doc bloat — multi-paragraph essays on trivial helpers. |
| **Explicit CUT list** | Names the exact AI over-productions to suppress: signature-restating docstrings, boilerplate `Args/Returns/Raises`, section-header comments, changelog comments. Every suppressed block is context no future session has to load. |

### Steering Better Decisions

**Comment the WHY, never the WHAT** — the governing rule. Documentation earns its place only by carrying what the code cannot: intent, constraints, rationale, external references. A doc line that restates the code is deleted. This inverts the model's trained bias toward exhaustive docstrings.

**Rename over comment** — `d` → `elapsed_seconds` instead of `# d is elapsed seconds`. A clearer name is self-maintaining; a comment drifts. The skill routes the model to the name first.

**Respect project overrides** — where a project mandates docstrings on a surface (or marks domain notes as intentional), the one-line docstring is trimmed lean, never removed. The discipline cuts *redundancy*, never *required* documentation, so it composes with stricter house rules instead of fighting them.

**Relationship to /minimalist** — minimalist governs the *diff*; lean-python-docs governs the *prose inside it*. minimalist's Standards defer to this skill for every Python docstring and comment, so a minimal-change task inherits doc discipline without duplicating the rules.

---

## skills/work-tracker

### Token Efficiency

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Tracker floor (~5 items)** | Work below that threshold, or inside a single session, uses the ephemeral task list and writes no file at all. Most tasks never pay the tracker's cost — the largest saving in the skill, because it applies to the common case. |
| **Sharded index + per-work files** | `docs/tracker/INDEX.md` is a bounded rollup (~40 lines) and the only default read; individual `docs/tracker/<slug>.md` files are opened one at a time. A monolithic tracker charges a full-file read for every status flip, and grows without limit. |
| **One item, one line, one file** | A single checkbox row carries ID, priority, blocker, and source link — there is no second view of the same item. Trackers that repeat an item across a dashboard, a backlog table, and a detail section charge for every copy on each edit, and the copies drift out of agreement. |
| **Edit rows, never rewrite files** | `grep -n` locates a row; a single-line edit flips it. Combined with recomputing only the touched tracker's rollup, a status change costs a few lines instead of two full documents. |
| **Git history is the audit log** | Evidence (SHA/PR) lives inline on the DONE row. No changelog or status-history section is kept, because `git log` already stores it. |

### Steering Better Decisions

**Verify-first protocol** is the reason the skill exists. Before any backlog item, four steps gate the first line of code: re-read the row and its source doc, verify the gap still exists on main (`git log` plus a grep for the named symbol), confirm it is still required, then flip shipped or obsolete rows with evidence. Stale status is not a cosmetic problem — it causes an agent to re-implement work that already shipped, which is expensive in tokens and worse in review time. The four steps are embedded verbatim in every tracker so future sessions inherit the gate.

**Status lives in exactly one place.** Detail belongs in source docs; status belongs in the tracker; neither duplicates the other. The moment status appears in two files they drift, and a reader cannot tell which is current. Retiring a superseded doc repoints its inbound references first, so nothing dangles.

**Binary status by default** — done or not-done, with richer states added only when a project genuinely needs them. An eight-state taxonomy invites debate over which state a row is in, which is deliberation the model pays for and the reader ignores.

**Progress bars live only in the index.** Per-file bars go stale on every edit and force a rewrite to correct — putting them in one place means a status flip touches one line, not two documents.

**Relationship to the native task list** — Claude Code's task tools are ephemeral working memory scoped to one session; the tracker is durable committed state. A tracker row expands into the task list at pick-up and collapses back to a checkbox plus a SHA at completion. The two layers only both exist when work actually outlives the session, which is what the tracker floor enforces.

---

## skills/okr

### Token Efficiency

| Mechanism | How it saves tokens |
|-----------|-------------------|
| **Objective floor** | A goals file is written only when work spans multiple objectives across a planning period. A single feature or bug never becomes an objective — it stays a tracker row or a task-list entry, so the common case pays nothing. |
| **One file, read whole** | Objectives are few (~5 cap) and reviewed as a set, so `docs/goals/GOALS.md` is a single bounded file rather than a shard. There is no index to keep in sync — the opposite choice from the tracker, made because the access pattern is holistic review, not one-item action. |
| **Bars only on headers** | Attainment bars render on the overall and per-objective lines, never per KR row. Moving a metric edits one `Current` cell plus two header bars — never a full-file rewrite. |
| **Metric, not restatement** | A KR is a single measurable row that links down to the tracker doing the work; the tasks are not copied up. Status appears once — the KR shows the metric, the tracker shows the tasks — so the two layers never drift. |

### Steering Better Decisions

**Outcomes here, outputs in the tracker.** The skill's reason to exist is the altitude split: a goal is a metric moving (an outcome), a tracker item is a task shipping (an output). Conflating them produces "objectives" that are really to-do lists — measured by activity instead of result. Each KR carries a metric, a baseline, a target, and a link down to the `docs/tracker/<slug>.md` that moves it, so the outcome and the work that drives it stay connected without being duplicated.

**Verify-first on every metric.** A `Current` value moves only against evidence — a measurement, command output, dashboard, or SHA — never from memory or optimism. The same four-step gate the tracker applies before code, this skill applies before a number changes, because a goals file that drifts optimistic is worse than none: it reports success that did not happen.

**Attainment is mechanical; status is a judgment.** Attainment is computed from baseline, target, and current by one direction-agnostic formula, so it cannot be talked up. Status (`on-track` / `at-risk` / `off-track` / `met` / `dropped`) is a separate confidence call — a KR can sit at 90% attainment and still be `at-risk` when the last stretch is the hard part. Keeping the two distinct stops a good-looking number from hiding a stalled objective.

**Relationship to /work-tracker** — the tracker owns outputs at work-item altitude; `/okr` owns outcomes at objective altitude. A KR's Work column links down to the tracker(s) whose completion moves the metric, and creating that tracker is a `/work-tracker` handoff. The two only both exist when work is large enough to have measurable objectives above its task list.

---

## Combined Effect

1. **Defensive rules** — explicit anti-patterns, skip constraints, gates, and budget caps that limit how much damage an autonomous agent can do
2. **Token discipline** — output routing, gated questions, and format templates that make sessions leaner without losing quality
