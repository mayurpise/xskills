---
name: scrub
description: "Review a target directory for reuse, quality, and efficiency with three parallel agents, tier every finding by how provable its fix is (mechanical swap, structural refactor, semantic change), then apply them within that safety envelope — Tier 1 and 2 automatically with a typecheck-and-test gate per file, Tier 3 only after you confirm. Skipping needs one of four cited reasons, and every finding surfaced appears in the report as applied or skipped. Use when the user says 'scrub this directory', 'clean up this code', 'apply the cleanup', 'review and fix', 'remove duplication', '/scrub', or wants findings fixed rather than only reported."
---

# Scrub: Code Review and Cleanup

Review a target directory for reuse, quality, and efficiency, then **apply every actionable finding** within a defined safety envelope. Skipping is the exception, not the default.

## Phase 1: Identify Target

The user must provide a target directory. If no directory is specified, ask the user which directory to review before proceeding.

1. **Clean-tree gate.** Run `git status --porcelain -- <target>`. Any output means uncommitted work sits in scope: stop and ask the user to commit or stash it first (or explicitly confirm scrubbing a dirty tree). This gate is what makes the Tier 2 failure revert (`git checkout <file>`) provably safe, and keeps every per-file commit free of work that is not scrub's own.
2. **Inventory, don't read.** Glob all source files under the target recursively (e.g., `.py`, `.ts`, `.tsx`, `.rs`, `.go`, `.java` — whatever languages are present) and record the list with sizes and languages. Do **not** read the files here: the Phase 2 agents cannot see this session's context and read their own material; the parent reads only the files named in findings, during Phase 3 triage.
3. **Resolve the validation commands.** From the repo's own config (CI workflow, `Makefile`, `package.json`, `pyproject.toml`, `Cargo.toml`, …), resolve the project's typecheck command and test command once (e.g., `tsc --noEmit` + vitest for TS, `mypy` + `pytest` for Python, `cargo check` + `cargo test` for Rust). These exact commands are what every gate below runs.

## Phase 2: Launch Three Review Agents in Parallel

Use the Agent tool to launch all three agents concurrently in a single message. Pass each agent the full list of files from Phase 1. Review agents are **read-only** — they return findings; only the parent edits files. Where the runner supports model selection, dispatch them on a mid-tier model: each pass is scoped read-and-summarize work, and triage and application stay with the parent.

### Agent 1: Code Reuse Review

1. **Search for existing utilities and helpers** that could replace newly written code. Common locations: utility directories, shared modules, adjacent files.
2. **Flag any new function that duplicates existing functionality.** Suggest the existing function to use instead.
3. **Flag any inline logic that could use an existing utility** — hand-rolled string manipulation, manual path handling, custom environment checks, ad-hoc type guards, etc.

### Agent 2: Code Quality Review

1. **Redundant state**: state duplicating existing state, cached values that could be derived, observers/effects that could be direct calls
2. **Parameter sprawl**: adding new parameters to a function instead of generalizing or restructuring
3. **Copy-paste with slight variation**: near-duplicate blocks that should be unified
4. **Leaky abstractions**: exposing internal details that should be encapsulated
5. **Stringly-typed code**: raw strings where constants/enums/branded types already exist
6. **Unnecessary JSX nesting**: wrapper elements adding no layout value
7. **Unnecessary comments**: comments explaining WHAT, narrating the change, or referencing the task/caller — keep only non-obvious WHY

### Agent 3: Efficiency Review

1. **Unnecessary work**: redundant computations, repeated file reads, duplicate network/API calls, N+1 patterns
2. **Missed concurrency**: independent operations run sequentially
3. **Hot-path bloat**: blocking work on startup or per-request/per-render hot paths
4. **Recurring no-op updates**: unconditional state/store updates inside polling loops, intervals, or event handlers — add change-detection guards. If a wrapper takes an updater/reducer callback, verify it honors same-reference returns
5. **Unnecessary existence checks**: pre-checking file/resource existence (TOCTOU anti-pattern)
6. **Memory**: unbounded data structures, missing cleanup, event listener leaks
7. **Overly broad operations**: loading all items when filtering for one

## Phase 3: Triage & Tier Every Finding

Aggregate all findings from the three agents. **Every finding gets a tier** — no subjective "not worth it" skipping.

### Tier 1 — Mechanical swap (apply freely)

Fix is provably output-preserving. No contract change, no semantic shift.

- Utility swap where old and new produce identical output (`` `$${x.toFixed(2)}` `` → `formatCurrency(x)` when both yield `$1.23`)
- Constant hoisting, lifting to module scope
- `useMemo` / `memo` wrapping when inputs are already stable
- Dead-code removal of module-private symbols (verify zero consumers via grep first); removing an exported/public symbol is a contract change → Tier 3
- Import consolidation, barrel re-export

**Action:** apply, run typecheck.

### Tier 2 — Structural refactor (apply with per-file validation)

Fix changes code shape but preserves public contract. Callers continue to work without modification.

- Extracting a duplicated component/function to a shared location
- Splitting a component to isolate re-renders
- Pre-computing values to flatten a hot comparator
- Selector factoring (when callers stay unchanged)
- Guarding no-op store updates

**Action:** apply per file. After each file, run the Phase 1 typecheck and scoped test commands. On failure, `git checkout` that file (safe — the Phase 1 clean-tree gate guarantees it holds only scrub's change) and move the finding to the skip report with category `(b)`.

### Tier 3 — Semantic change (confirm before applying)

Fix changes a public contract, output, or signature. Callers may need updates. Behavior may visibly shift.

- Function signature changes (positional → options bag, added/removed params)
- Enum / const-object conversions when callers use string literals
- Prop regrouping (handlers bag, options bag)
- Format changes that alter rendered output (e.g., `'0'` → `'0.00'`)
- Type widening/narrowing that affects consumers

**Action:** do **not** apply silently. List all Tier 3 findings together, show the proposed diff shape, and ask the user: *"Apply these N Tier 3 changes? [y / pick / skip]"*

### The four valid skip categories

A finding may be skipped **only** when one of these is true:
- **(a) Output would change.** Existing utility does not produce identical output for the input domain. Cite the divergent case.
- **(b) Broke a test.** Applied, tests failed, auto-reverted. Cite the test name.
- **(c) Contradicts a project rule.** CLAUDE.md / project docs explicitly forbid the pattern. Cite the rule.
- **(d) Unlocked.** A Tier 2/3 finding whose changed surface has no covering test, and none can be cheaply added. Behavior preservation cannot be proven, so it is not applied on typecheck alone. Cite the untested surface. (Tier 1 is exempt — a mechanical swap is output-preserving by definition.)

"Mechanical churn," "out of scope," "cosmetic," "low impact," and "not worth it" are **not** skip categories.

## Phase 4: Apply

### Budget

Hard caps per scrub run:
- **Max 30 findings applied**
- **Max 500 net lines changed**

When findings exceed the budget, stop at the cap and surface the remainder as a tiered continuation prompt: *"Applied 30 of N. Tier 1 remaining: X. Tier 2 remaining: Y. Tier 3 awaiting confirm: Z. Continue?"*

### Order

1. All Tier 1 first, grouped by file.
2. Then Tier 2, grouped by file, with per-file validation gate.
3. Then Tier 3, only after user confirmation.

### Per-file commit

Each file's fixes commit independently with a conventional message (`refactor(scope): scrub — <what changed in this file>`). One file = one commit = one revertable unit. Do **not** push; leave that to the user.

### Gates

- Before applying any Tier 2/3 finding: confirm a test covers the changed surface. If none exists and one cannot be cheaply added, skip as `(d)` — do not apply a structural or semantic change on typecheck alone.
- After Tier 1: the Phase 1 typecheck command must pass.
- After each Tier 2 file: the Phase 1 typecheck + scoped test commands must pass. On failure: revert the file, classify `(b)`.
- After Tier 3: full project test suite must pass before handing back.

## Phase 5: Report

Conclude with a structured report in this exact shape:

```
## Scrub Report

### Applied
- Tier 1: N findings across M files — commits <sha1>..<shaN>
- Tier 2: N findings across M files — commits <sha1>..<shaN>
- Tier 3: N findings applied after confirmation

### Skipped
<one line per skipped finding>
- <file>:<line> — <category (a|b|c|d)> — <one-sentence evidence>

### Pending confirmation (Tier 3)
<list if user declined or postponed>

### Budget
- Findings applied: N / 30
- Lines changed: N / 500
- Remaining: <continuation list if truncated>
```

The skip section must be exhaustive. If a finding was surfaced by any agent, it appears either under Applied or under Skipped — no finding silently disappears.
