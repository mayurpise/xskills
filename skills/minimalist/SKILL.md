---
name: minimalist
description: "Write the smallest change that satisfies the definition of done for the task type. A pre-coding discipline: classify the task (NEW / CHANGE / REFACTOR / MIXED), freeze a manifest, lock the definition of done (tests toward new behavior, or characterization tests against existing behavior for refactors), execute surgically, delete code not traceable to a passing test, then run a critique gate. 'Minimal' means smallest diff, not least code — a large behavior-neutral refactor can be correct. Use when the user says 'minimal code', 'smallest change', 'no gold-plating', 'refactor', 'restructure', 'rename', 'extract', 'inline', 'preserve behavior', '/minimalist', or before writing or modifying implementation code."
---

# Minimal-Change Coding Protocol

Applies to every coding task. Governing rule: write the smallest change that
satisfies the definition of done for this task type — no code not traceable to it.
"Minimal" = smallest DIFF, not least total code. A large behavior-neutral rename
can be correct; a small behavior-changing edit is not.

## 0. Classify first (determines the definition of done)
State the type, then follow the matching §2 branch:
- NEW      — greenfield code, new behavior intended
- CHANGE   — feature/behavior change in existing code
- REFACTOR — existing code, behavior MUST NOT change
- MIXED    — refactor + change → SPLIT into REFACTOR then CHANGE, never interleave
Do not proceed until classified. If MIXED and unsplit, stop and split.

## 1. Plan and freeze (all types) — before writing any code
Output a manifest FIRST, then write only to it:
- Files to touch (exact paths)
- Functions/classes to add or change (exact signatures)
- Out of scope for this task (see §3)
- [REFACTOR/CHANGE] Blast radius: every caller/importer of the changed surface
- [REFACTOR] Behavior lock relied on (which tests, confirmed green pre-change)
- [REFACTOR] What is guaranteed unchanged (signatures, returns, exceptions, side effects)
No file, function, parameter, or abstraction outside the manifest. If the task forces
a deviation, amend the manifest explicitly with a reason — never add silently.

## 2. Definition of done (branch by §0 type)

### NEW / CHANGE — test-as-spec (write tests TOWARD intended behavior)
- Write failing tests encoding the task. These ARE the definition of done.
- Write only implementation that turns a currently-failing test green.
- Stop when named tests pass. No code for cases no test covers.
- Never weaken or delete a test to make code pass.

### REFACTOR — behavior lock (write tests AGAINST current behavior)
- Lock behavior BEFORE touching code:
  - Covered already → run, confirm green, record. That is the lock.
  - Not covered → write characterization tests pinning CURRENT behavior (including
    current quirks/bugs) before changing anything. Assert what it does now, not what
    it should. That is the lock.
  - Cannot lock it → say so and stop. Do not refactor unlocked code.
- The SAME lock tests must pass before AND after, UNMODIFIED. If you had to change a
  test to pass, behavior changed — that is a violation, not a refactor.
- No change to public signatures, returns, raised exceptions, or side effects unless
  the task explicitly asks (any such change reclassifies to CHANGE per §0).
- Preserve bug-for-bug behavior unless the task is to fix the bug; if fixing,
  reclassify, update the lock to the new expectation, and note it.
- Prefer mechanical reversible steps (rename, extract, inline) over rewrites. If a
  rewrite is genuinely simpler than incremental change, say so and confirm before
  replacing working code.

## 3. Out-of-scope defaults (all types) — do NOT do unless a test requires it
- No error handling for inputs that cannot occur in the calling context
- No configuration/parameters for a single caller
- No abstraction (class, base, interface, strategy) until ≥3 real call sites exist
- No new class where a module-level function works
- No logging, caching, retries, or validation not demanded by a test
State task-specific additions in the §1 manifest.

## 4. Surgical scope (all types; strict)
- Touch only lines required for the goal. Every changed line traces to it.
- Do NOT improve, reformat, re-type-hint, or reword adjacent code, comments, or style.
- Match existing idioms and style even where you disagree. Consistency > preference.
- Remove only imports/variables YOUR change orphaned. Note other dead code; don't delete.
- No opportunistic dependency bumps, config edits, or file moves.

## 5. Deletion pass (all types) — after done, before presenting
Re-read the full diff. For EACH function, class, parameter, and abstraction added:
justify in one line why it cannot be inlined or removed while tests stay green, OR
remove it. Deleting must break no test. Present the justification list with the diff.

## 6. Critique gate (all types) — verify and report pass/fail
- [ ] Every changed line traces to a specific test or the stated goal
- [ ] Every abstraction has ≥3 current call sites or a test that requires it
- [ ] No speculative generality, config, or error handling
- [ ] Diff contains zero unrelated edits (style, adjacent code, non-orphaned imports)
- [ ] [NEW/CHANGE] Named tests green; no test weakened
- [ ] [REFACTOR] Lock tests unchanged and green pre- AND post-change; no signature/
      return/exception/side-effect change
- [ ] [REFACTOR/CHANGE] All callers in blast radius still compile/pass
- [ ] A senior engineer would not call this overcomplicated
If any fails, revise before presenting. Do not present failing work with caveats.

## Standards (all types, non-negotiable)
- **Changed code passes the project's own typechecker, linter, and formatter** —
  resolve them from the repo (CI config, Makefile, package.json, pyproject). The gate
  covers the changed code; pre-existing violations elsewhere are not yours to sweep (§4).
- Tests: one behavior per test, arrange-act-assert, no logic in tests, fixtures over
  setup duplication, parametrize over copy-paste, assert on behavior not implementation
  (pytest terms — apply the project framework's equivalents)
- No dead code orphaned by the change
- Python specifics: docstrings/comments follow the `lean-python-docs` skill (WHY not
  WHAT); type hints on all changed signatures; a Python project with no established
  tooling defaults to `mypy --strict` + `ruff check` (incl. C901) + `ruff format`
- One task type per commit (conventional): `feat:`, `fix:`, `refactor:` — never mix
