---
name: xreview
description: "Review a GitHub pull request, the local working diff, or existing code for high-signal issues across nine dimensions — bugs and logic, security, performance, CLAUDE.md compliance, silent failures, test coverage, comment accuracy, type design, and simplification — then independently validate every candidate finding before reporting so false positives are filtered out. Infers its own scope: diff when there are changes to review, whole-code audit when the request or the repo state calls for one. Terminal report by default; posts inline PR comments only with --comment. Use when the user says 'review this', 'review my changes', 'review the PR', 'code review', 'check my diff', 'review before I commit', 'audit this codebase', 'review the whole repo', 'audit this module', 'brownfield review', '/xreview', or before opening or merging a pull request."
---

# xreview: High-Signal Code Review

Review changed code and report **only issues that survive validation**. Two disciplines, merged: broad multi-dimension coverage (catch whole classes of defect), and a strict validate-then-filter gate (every candidate is re-checked against the real code before it reaches the report). A false positive erodes trust and wastes reviewer time — quality over quantity, always.

## Operating assumptions

- Every tool call has a clear purpose. Do not make exploratory or test calls.
- **Diff mode (default):** review only **changed** code — the diff and its immediate context. Do not audit the whole codebase or flag pre-existing issues the change did not introduce.
- **Audit mode:** the scope is existing code, not a diff. Pre-existing issues are the *point*; the "changed code only" rule and the pre-existing-issue filter are lifted for that run. Every other discipline — validation gate, confidence bands, smallest-diff fixes, false-positive suppression — is unchanged. The mode is **inferred, never flagged** (Phase 0).
- **Fixes follow the smallest diff.** Every fix or suggestion you propose must itself obey the `minimalist` skill: the smallest change that resolves the issue, with no new abstraction, configuration, or defensive code the fix does not require.
- **Execution model:** if your tool can launch parallel subagents (e.g. Claude Code's Agent/Task tool), dispatch the change summary and each applicable dimension in Phase 2 as parallel agents, and validate findings in parallel in Phase 3. If not, perform each pass yourself in sequence. The phases and gates below are identical either way.

## Invocation

The command takes no mode switch. `/xreview` figures out what to review from the request and the repo state; an optional PR or path only says *where* to look.

| Command | Behavior |
|---------|----------|
| `/xreview` | Review the local working diff (staged + unstaged + untracked). If the diff is empty, review the last commit. If there is nothing to review either way, audit the repo. |
| `/xreview <PR>` | PR mode. Review the given GitHub PR (number or URL) via `gh`. |
| `/xreview <path>` | Scope to that file or directory. If it has changes in the working diff, review those; if it has none, audit the code there. |
| `/xreview --comment` | PR mode only. Post findings as inline PR comments (default is terminal-only). |

`--comment` is the only flag, and it stays one because it writes to GitHub — a side effect must be asked for, never inferred. Everything else is inferred from the request and the repo state.

## Phase 0 — Scope and skip check

1. **Resolve the target.** Take the first rule that matches, in order:
   1. A PR number/URL was given → **PR mode** (`gh pr view`, `gh pr diff`).
   2. The request asks about existing code rather than recent work — "audit this codebase", "review the whole repo", "review this module/service", "is this code safe", "what should I fix before refactoring", or any ask naming code with no reference to a change → **audit mode** (Phase 0A).
   3. A path was given and nothing under it appears in the working diff or the last commit → **audit mode** on that path. Reviewing a diff that does not exist is not a useful reading of the request.
   4. Otherwise → **local mode** (`git diff` for unstaged, `git diff --staged`, and untracked files). If that diff is empty, review the last commit. If the last commit is empty of reviewable source too, fall through to **audit mode**.

   State the resolved mode and scope in one line before reviewing, so a wrong inference is visible immediately and cheap to correct.
2. **Skip conditions (PR mode).** Stop and report the reason without reviewing if the PR is closed, is a draft, is trivial/automated (e.g. dependency bump, generated lockfile), or you have already left a review on it (`gh pr view <PR> --comments`). Still review PRs authored by an AI.
3. **Gather guideline files.** Collect paths (not contents yet) of every relevant `CLAUDE.md`: the repo root one, plus any in a directory containing a file in scope. A `CLAUDE.md` governs a file **only** if it shares that file's path or a parent of it.
4. **Summarize the change.** Produce a short summary of what changed and the author's intent (PR title/description in PR mode; commit messages or the diff itself in local mode; in audit mode, what the code in scope is *for* — see Phase 0A). Pass this summary to every downstream pass — intent context prevents false positives.

## Phase 0A — Audit mode scoping (audit mode only)

There is no diff to bound the work, so scope is bounded explicitly. Never review a whole repo file-by-file in one pass.

1. **Inventory.** Enumerate source files under the given path (repo root if none). Exclude vendored/generated/third-party trees, lockfiles, build output, and fixtures. Report the file count and rough line count you are working from.
2. **Establish intent.** Read the README, entry points, and any architecture docs to state in 2–4 lines what this code does and what its trust and failure boundaries are. This substitutes for the PR description and is what keeps audit findings grounded.
3. **Prioritize into units.** Group files into review units (module, package, or directory — roughly one coherent responsibility each). Rank units by risk, highest first:
   - trust boundaries: request handlers, parsers, deserialization, auth, file/path and subprocess ops, SQL;
   - state and concurrency: shared mutable state, caches, locks, background tasks, transactions;
   - churn and complexity: `git log --format= --name-only -n 500 | sort | uniq -c | sort -rn` for hot files; largest and deepest-nested files;
   - untested surface: source with no corresponding test file.
4. **Review unit by unit,** highest risk first. Run Phases 1–4 per unit. If a subagent runner is available, dispatch units in parallel.
5. **Budget honestly.** If you cannot cover every unit, cover the top-ranked ones fully and **state in the report exactly which units were not reviewed and why**. A silently truncated audit reads as a clean bill of health — never let it.

## Phase 1 — Select applicable dimensions

Run only the dimensions the scope warrants. In **audit mode**, read each "Run when" condition against what the code in the unit *contains* rather than what a diff changed (e.g. run `silent-failure` if the unit has catch/except blocks at all; run `security` if it touches any of the listed surfaces).

| Dimension | Run when | Category label |
|-----------|----------|----------------|
| **Bugs & logic** | Always | `bug` |
| **CLAUDE.md compliance** | A governing `CLAUDE.md` exists | `claude-md` |
| **Silent failures** | Error handling, catch/except blocks, fallbacks, or optional-chaining were added or changed | `silent-failure` |
| **Test coverage** | New behavior/logic was added, or test files changed | `test-gap` |
| **Comment accuracy** | Comments, docstrings, or docs were added or modified | `comment` |
| **Type design** | A type/interface/data model was added or materially changed | `type-design` |
| **Security** | The diff touches input handling, auth/permissions, secrets, serialization, SQL/queries, HTML/templating, file/path ops, or crypto | `security` |
| **Performance** | The diff adds loops over collections, DB/network calls, allocations on a hot path, or resource acquisition | `perf` |
| **Simplification** | Always | `simplify` |

**Language-specific checks (bundled, no dependency).** This skill ships verbatim rulesets in its own `rulesets/` directory (`default.md` always; plus `python.md`, `ts_js_tsx_jsx.md`). For each file in scope, consult `rulesets/default.md` and the file matching its language (Python → `python.md`; TS/JS/TSX/JSX → `ts_js_tsx_jsx.md`), and fold any violations into the dimensions above — **diff-introduced** violations in diff/PR mode, any violation in audit mode. If no ruleset matches the language, use `default.md` only. Never fetch over the network. (Mirrored from alibaba/open-code-review, Apache-2.0; provenance in `rulesets/UPSTREAM.lock`.)

## Phase 2 — Review each dimension

Each pass returns candidate findings. Every finding carries: category label, file and line, a one-line description, the concrete reason it was flagged, and a **confidence score 0–100** (below). Give each pass the change summary from Phase 0.

**Confidence bands** (used for gating in Phase 4):
- **0–25** likely false positive, or (diff/PR mode) pre-existing → discard
- **26–50** minor nitpick not rooted in a rule → discard
- **51–75** valid but low impact → discard unless it is a `claude-md` violation you can quote verbatim
- **76–89** important, real → **Important**
- **90–100** critical bug or explicit rule violation → **Critical**

**Audit-mode reading of the dimensions below.** Wherever a dimension says "changed", "new", or "introduced by the diff", read it as "present in the unit under review". The diff-relative qualifiers exist to suppress noise from unrelated code, not to protect existing defects. Two substitutions matter most: `bug` and `security` drop the "introduced by the diff" requirement but keep the *provability* requirement in full (you must still state inputs → wrong result); and `perf` covers regressions already in the code, not just ones a diff adds. What does **not** change: "the code did not need it" still kills a finding, so absent abstraction, configuration, or defensive handling is still not a finding, and stylistic disagreement with an existing codebase is still not a finding.

### Bugs & logic (`bug`)
Flag only defects provable from the changed code plus its immediate context. Highest value:
- Will not compile/parse: syntax/type errors, missing imports, unresolved references.
- Wrong regardless of input: clear logic errors, inverted conditions, off-by-one, wrong operator.
- Null/undefined mishandling, race conditions, resource leaks, obvious security holes (injection, unsafe deserialization, secret exposure) **introduced by the diff**.
Do not flag anything you cannot confirm without reading far outside the diff — defer it to validation instead of dropping context-dependent guesses into the report.

### CLAUDE.md compliance (`claude-md`)
For each changed file, read only the `CLAUDE.md` files that govern its path (Phase 0). Flag a violation only when you can **quote the exact rule** being broken and the violation is unambiguous. Ignore rules scoped to other paths, and rules the code explicitly silences (e.g. an inline lint-ignore).

### Silent failures (`silent-failure`)
Audit changed error handling. Flag: empty catch blocks; catch blocks that only log and continue when they should propagate; broad catches that swallow unrelated errors; fallback to defaults/null/mock behavior on error without logging or user feedback; retries that exhaust silently; optional chaining that skips an operation that should fail loudly. For each, name the specific errors the handler could hide and the user/debugging impact.

### Test coverage (`test-gap`)
Assess **behavioral** coverage of the new logic, not line coverage. Flag untested critical paths, missing negative/boundary cases, and uncovered error branches. Rate criticality 1–10; report only 8–10 as Important-tier gaps, 5–7 as suggestions. Skip trivial getters/setters. Note tests coupled to implementation rather than behavior. Do not demand 100% coverage.

### Comment accuracy (`comment`)
Cross-check changed comments/docstrings against the code they describe. Flag: comments that are factually wrong or now stale, signatures that disagree with documented params/returns, and comments that restate obvious code (recommend removal). Prefer WHY over WHAT. Advisory only.

### Type design (`type-design`)
For new/changed types, assess whether illegal states are representable, whether invariants are enforced at construction and every mutation, and whether internals leak. Flag: anemic models, exposed mutable internals, invariants enforced only by documentation, missing constructor validation. Suggest the smallest change that closes the gap — do not propose over-engineered type gymnastics. Advisory unless a missing invariant causes a concrete `bug`.

### Security (`security`)
Flag only vulnerabilities **introduced by the diff** and provable from the changed code plus immediate context: injection (SQL/command/template), XSS or unescaped output, secrets/credentials committed or logged, missing or incorrect authorization on a changed path, unsafe deserialization, path traversal, weak or misused crypto. State the attack path — what untrusted input reaches what sink. Overlaps `bug`; prefer `security` for these vulnerability classes. Do not raise generic hardening the diff did not necessitate. Validated in Phase 3.

### Performance (`perf`)
Flag concrete regressions the diff introduces: an N+1 query, a network/DB call inside a loop, an unbounded allocation or copy on a hot path, a resource (file/connection/lock) acquired but not released. Name the cost and when it bites. Advisory; skip speculative micro-optimization and anything a profiler would be needed to prove.

### Simplification (`simplify`)
On the code in scope, suggest behavior-preserving simplifications: reduce nesting, remove redundant abstraction, collapse a needless indirection, replace nested ternaries with if/else. **Never** change behavior. Advisory; prefer clarity over brevity.

This pass runs on every review, so it carries the strictest noise bar of any dimension — an always-on pass that emits style opinions would drown the findings that matter. Raise a simplification only when it removes **real** complexity a reader has to hold in their head: a branch, a level of nesting, an abstraction with one call site, a variable that exists only to be returned. Never raise: formatting, naming, idiom preference, a rewrite of equal complexity, or anything a formatter settles. If a unit yields no simplification that clears that bar, report none — that is the expected result on well-written code. In audit mode, cap this pass at the few highest-value simplifications per unit rather than listing every candidate.

## Phase 3 — Validate every candidate (the gate)

This is what makes the report trustworthy. For **each** `bug`, `silent-failure`, `security`, and `claude-md` candidate, run an independent check whose sole job is to confirm the issue is real:
- **`bug` / `silent-failure` / `security`:** verify against the actual code (read beyond the diff if needed) that the failure genuinely occurs. Reproduce the reasoning: given what inputs/state does it break, and to what wrong result or crash? If you cannot state a concrete failure, it does not survive.
- **`claude-md`:** confirm the quoted rule is in scope for this file's path and is actually violated by the changed lines.

Treat validation adversarially — default to refuting. If uncertain after checking, drop it. `test-gap`, `comment`, `type-design`, `perf`, and `simplify` findings skip this gate but must still be concrete and high-value.

## Phase 4 — Filter to high signal

Keep a finding only if it is **validated (Phase 3, where applicable) and confidence ≥ 80**. Then drop anything matching this false-positive list — never flag:
- Pre-existing issues the change did not introduce. *(Diff and PR mode only — this filter is off in audit mode, where pre-existing issues are the target.)*
- Code that looks like a bug but is correct.
- Pedantic nitpicks a senior engineer would not raise.
- Issues a linter/formatter catches (do not run the linter to verify).
- General quality, coverage, or security-hardening concerns not tied to a provable defect or a governing `CLAUDE.md` rule. *(In diff and PR mode the defect must also be diff-introduced.)*
- Rules a `CLAUDE.md` states but the code explicitly silences.
- A missing abstraction, config option, or defensive handling the change did not need — flagging absent gold-plating contradicts the `minimalist` skill's smallest-diff discipline.

## Phase 5 — Report (terminal)

Always output to the terminal in this shape. If nothing survived, say so plainly.

```
## Review — <PR #N | local working diff | audit: <path>>

<one-line summary of what changed, or of what the audited code does>

### Critical (N)
- [<category>] <file>:<line> — <issue>. <why it fails: inputs → wrong result>.

### Important (N)
- [<category>] <file>:<line> — <issue>. <concrete impact>.

### Suggestions (N)
- [<category>] <file>:<line> — <suggestion>.

### Strengths
- <what the change does well>
```

In **audit mode**, append a coverage section — an audit is only trustworthy if its blind spots are stated:

```
### Coverage
- Reviewed: <N units / M files> — <unit names, risk-ranked>
- Not reviewed: <units skipped> — <reason: out of budget, vendored, generated>
```

If the audit spans more than a handful of units, route the full report to a markdown file per the repo's output-routing rules and return the summary plus the path.

If no issues survived: `No issues found. Checked bugs, CLAUDE.md compliance, and the applicable dimensions.`

In **local and audit mode**, stop here — never post anywhere. In **PR mode without `--comment`**, stop here. Continue to Phase 6 only in PR mode with `--comment`.

## Phase 6 — Post inline PR comments (`--comment`, PR mode only)

1. If no issues survived, post one summary comment via `gh pr comment`:
   > ## Code review
   > No issues found. Checked bugs, CLAUDE.md compliance, and the applicable dimensions.
2. Otherwise post **one comment per unique issue** with the host's inline-comment tool (e.g. `mcp__github_inline_comment__create_inline_comment`; else `gh pr comment` referencing the location). Never duplicate a comment.
   - Small, self-contained fix → include a committable suggestion block, but **only** if committing it fully resolves the issue.
   - Larger or multi-site fix → describe the problem and the fix without a suggestion block.
   - Cite each governing `CLAUDE.md` with a link.
   - Link code with the exact permalink format (renders in Markdown): `https://github.com/<owner>/<repo>/blob/<full-sha>/<path>#L<start>-L<end>` — full SHA (not `$(git rev-parse HEAD)`), correct repo, `#L` notation, at least one line of context on each side.
