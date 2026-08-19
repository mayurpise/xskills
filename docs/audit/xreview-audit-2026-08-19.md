# xreview audit — xskills repo

**Date:** 2026-08-19
**Mode:** audit (inferred — request named the whole codebase with no reference to a change; working tree was clean)
**Scope:** repo root
**Commit:** d6bbe3c
**Previous audit:** [`xreview-audit-2026-08-08.md`](xreview-audit-2026-08-08.md) — all four of its
Critical/Important findings verified fixed on main before this run began.

## What this code is

`xskills` distributes agent instructions and skills to Claude Code, Cursor, and Copilot. The
executable surface has roughly quadrupled since the last audit: 4 shell scripts (~460 lines) plus
three Python helpers under `skills/xsecurity/scripts/` (1,759 lines) that render the xsecurity
report and patch products. Trust and failure boundaries: `install.sh` writes into the user's
`$HOME` config dirs and now also fetches and executes a remote tarball; `scripts/sync-upstream.sh`
fetches third-party content into the repo; and the three Python scripts each call
`shutil.rmtree()` on a path derived from an argument. The only test before this run was
`scripts/test-install.sh` (53 lines), covering `install.sh` alone.

## Critical (1)

### [bug] `install.sh:39,47` — the no-clone installer installs the current directory, not xskills

`SCRIPT_DIR` was resolved from `${BASH_SOURCE[0]:-$0}`. Read from stdin — which is exactly the
documented `curl … | bash` path — bash reports the script as `main`, not a path, so
`dirname` yields `.` and **`SCRIPT_DIR` becomes `$PWD`**. The bootstrap guard then asked the
wrong question:

```bash
if [[ ! -d "$SKILLS_DIR" || ! -f "$AGENTS_SRC" ]]; then    # :47 — tests $PWD, not the script
```

Any directory that happens to hold a `skills/` dir and an `AGENTS.md` satisfies it, so the fetch
never runs and **that directory is installed instead of xskills**.

**Failure, reproduced.** A decoy tree with `AGENTS.md` and `skills/notxskills/SKILL.md`, then the
README's one-liner run from inside it:

```
$ cat install.sh | HOME=$fake bash -s -- --claude --config
  ✓ skill  Claude Code/evil/SKILL.md → …/.claude/skills/evil/SKILL.md
  ✓ config Claude Code               → …/.claude/CLAUDE.md
$ cat $fake/.claude/CLAUDE.md
THIS IS NOT XSKILLS - a different project AGENTS.md
```

This matters beyond a wrong install. `AGENTS.md` is a de-facto standard filename, so any checkout
carrying one plus a `skills/` dir triggers it — and the payload is *instructions*: the tree's
`AGENTS.md` becomes the user's global `~/.claude/CLAUDE.md` and its `SKILL.md` files land in
`~/.claude/skills/`, read by every future session. A repo shipping a hostile `skills/*/SKILL.md`
gets it installed globally by a user who ran the xskills installer from that checkout.

The comment at `:44` states the intent the code failed to implement — *"there is no repo beside
the script, only the script itself"* — while the code consults `$PWD`.

**Same root cause, second symptom:** inside a function `BASH_SOURCE[0]` is `main` under stdin
execution, so `print_usage` (`:77`) ran `sed` against a file named `main`:

```
$ cat install.sh | bash -s -- --help
sed: can't read main: No such file or directory      # exit 2, no usage printed
```

**Fixed** — test the script's own path, and reuse it for the usage block:

```diff
-SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
+SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
+SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
-if [[ ! -d "$SKILLS_DIR" || ! -f "$AGENTS_SRC" ]]; then
+if [[ ! -f "$SCRIPT_PATH" || ! -d "$SKILLS_DIR" || ! -f "$AGENTS_SRC" ]]; then
-  sed -n '/^# Usage:/,/^#$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
+  sed -n '/^# Usage:/,/^#$/p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
```

Locked by a new case in `scripts/test-install.sh` that pipes the installer from inside a decoy
tree (pointing `XSKILLS_TARBALL` at a local `git archive`, so no network) and asserts the decoy's
content never reaches the fake `$HOME`. Verified failing before the fix, passing after.

## Important (5)

### [bug] `skills/xsecurity/scripts/render_report.py:232` — an explicit `"line": null` threw away the whole render

`item.get("line", 0)` defaults an **absent** line to `0`, but an **explicit `null`** falls through
to `int(str(None))` and raises:

```
$ python3 render_report.py <run-dir>
render_report.py: finding F1 line None is not an integer     # exit 1
```

Nothing is written — no JSONL, no revision stamp — so a scan that has already spent its whole
token budget produces no machine-readable products until the pipeline is re-run against corrected
input. The two spellings of the same missing information disagreed: one is tolerated, the other is
fatal. `line` is not in the required-field list, so tolerating it is the consistent reading.

**Fixed:** `raw_line = item.get("line") or 0`. Note this also folds `""` to `0` where it
previously refused; both mean "no line number".

### [bug] `skills/xsecurity/scripts/patch_artifacts.py:595` — `patches.jsonl` could split one record across two lines

`render_report.py` escapes the three separators `json.dumps(ensure_ascii=False)` leaves raw
(`SEPARATOR_ESCAPES`, U+0085/U+2028/U+2029) precisely because its JSONL is line-delimited.
`patch_artifacts.py` writes the parallel `patches.jsonl` product and did not:

```
render_report.jsonl_line: '{"id": "F1", "decline_reason": "before\\u2028after"}'  -> 1 line
patch_artifacts style   : '{"id": "F1", "decline_reason": "before after"}'   -> 2 lines
```

The fields are agent-authored (`decline_reason`, `title`, `summary`, claim `evidence`), and
`str.splitlines()` breaks on all three characters, so a line-based reader sees one truncated
record and one fragment. **Fixed** by applying the sibling's existing escape table.

### [test-gap] `skills/xsecurity/scripts/` — 1,759 lines with no tests, including three `rmtree` paths

Criticality 8. `remove_workspace`, `remove_patch_run` (`patch_artifacts.py`) and `remove_run_dir`
(`render_report.py`) each delete a directory derived from an argument, fenced only by name checks
on the path and its two parents. Nothing asserted those fences hold. This is the same shape as the
backup guarantee that silently broke before the last audit and only got a test afterwards.

**Fixed:** `scripts/test-xsecurity-scripts.py` — characterization tests that every deviation from
the `<report>/.xsecurity-run/patch-<ts>/scratch-F<n>` layout (wrong leaf name, missing `patch-<ts>`
parent, not under `.xsecurity-run`, no `.git` of its own) is refused **and left on disk**, that the
one fenced shape is removed without touching its parent, plus regression tests for the two bugs
above. Verified: the deletion tests pass against unmodified code (they lock existing behavior); the
two regression tests fail against it.

### [bug] `skills/scrub/SKILL.md:1` — the only skill with no frontmatter, so it can never be model-invoked

Six of the seven skills declare `name:` and `description:`; `scrub` declared neither. Its listing
falls back to the H1, so the model sees `scrub: Scrub: Code Review and Cleanup` — no trigger
phrases — and cannot select it the way `/xreview`, `/minimalist` and the rest are selected. It is
reachable only by typing the slash command. (`xsecurity` has no auto-invocation either, but says so
deliberately with `disable-model-invocation: true`.) **Fixed** by adding frontmatter with a
description drawn from the skill's own phases.

### [comment] `skills/scrub/SKILL.md:5-6` — installation prose describing a layout that no longer exists

> This file (`scrub.md`) is stored flat in the repo. Each tool expects it at `scrub/SKILL.md`
> inside its skills directory.

The file is `skills/scrub/SKILL.md` and is already in the per-skill layout; there is no `scrub.md`
anywhere in the repo. Left over from the same restructure that produced the last audit's stale
`vendor/open-code-review` message. The whole 18-line block also duplicates the README's install
section inside a file loaded into context on every `/scrub` run — token waste in a repo whose
premise is token efficiency. **Fixed:** section removed; the README remains the single source.

## Suggestions (3)

### [bug] `patch_artifacts.py:550` — a multi-line `decline_reason` breaks the `PATCHES.md` bullet

`decline_reason` is validated with `field()` (newlines allowed, correct for the `F<n>.md`
paragraph) but interpolated raw into a markdown list item. **Fixed** by folding it with the
file's existing `line_field()` at the bullet site only.

### [simplify] `render_report.py:537` — a dict used as a set

`seen = {}` … `seen[finding["id"]] = True` is a set spelled as a dict. **Fixed:** `set()` / `.add()`.

### [simplify] `render_report.py:431` — an alias that only shadows its source

`reportable: list[Finding] = findings` is never reassigned and is used twice; the reader has to
hold two names for one list. **Fixed:** removed, call sites use `findings`.

## Not findings (checked and refuted)

- **`shutil.rmtree(onerror=…)`** (`patch_artifacts.py:780,826`) — `onerror` is deprecated since
  3.12 in favor of `onexc`, and the scripts declare 3.9 compatibility, so this looked like a
  forward-compatibility break. Tested on Python 3.14.6: `onerror` is still accepted and still
  fires. Not removed; not a finding.
- **`clear_readonly` chmod on POSIX** (`:768`) — `stat.S_IWRITE` drops read/execute bits, but the
  helper exists for Windows read-only git objects, and on POSIX `unlink` depends on the parent's
  mode, not the file's. No failure path.
- **`install_file` losing a tmp file when `install_cursor_config` aborts** (`install.sh:118-121`) —
  reachable only if `cp` fails, which aborts the install anyway. Below the bar.
- **`.DS_Store` skip pattern matching only at the top level** (`install.sh:137`) — real gap, but
  the case-arm exists to keep editor junk out, not as a correctness control.
- **`printf -- "$CURSOR_FRONTMATTER"`**, **`jq … | index($cmd)`**, **`[[ cond ]] && cmd` under
  `set -e`** — re-checked, still correct; see the 2026-08-08 audit for the reasoning.
- **`verification_summary` refusing a malformed `votes.json`** (`render_report.py:394-403`) —
  looks like the same over-strictness as the `line` bug, but the vote record *is* the attestation.
  Refusing to render an unprovable one is the intended control.
- **`sync-upstream.sh` / `hooks/pre-push`** — the pin default, the offline exit-2 path and the
  drift message were the last audit's findings and are all correctly fixed.

## Verification

```
$ bash scripts/test-install.sh
PASS: install.sh backs up user-owned config before replacing it
PASS: install.sh argument parsing
PASS: piped install fetches xskills instead of installing $PWD
$ python3 scripts/test-xsecurity-scripts.py
PASS: test_deletion_fences
PASS: test_null_line_still_renders
PASS: test_jsonl_records_stay_on_one_line
$ bash scripts/sync-upstream.sh --check
sync-upstream: up to date at alibaba/open-code-review@62e2b9979843
$ ruff check skills/xsecurity/scripts/ scripts/test-xsecurity-scripts.py
All checks passed!
```

## Strengths

- The three Python helpers exist so that no diff byte and no confidence claim is ever re-typed by
  a model on its way to the user. That is the right boundary, and the validation in
  `build_finding` / `build_unit` is genuinely strict about it — `patch_written` cannot be recorded
  without all three claims `CONFIDENT`, and a missing `untested` flag is refused rather than
  guessed.
- Every destructive path is fenced by name before it deletes, and `remove_workspaces_in` degrades
  a refusal into a warning rather than aborting the run. The fences were already correct; they
  just had nothing asserting they stay that way.
- `atomic_write` / `atomic_write_bytes` (temp file, `fsync`, `os.replace`, unlink on any
  exception) means a crash mid-render cannot leave a half-written product.
- Confidence is clamped by the panel vote in code (`vote_confidence_ceiling`), so a finding cannot
  claim `high` that the voters did not unanimously confirm.
- Everything the last audit found was fixed properly rather than patched around — including
  writing the missing test for the data-loss path.

## Coverage

- **Reviewed: 7 units / 11 files (~2,270 lines).** `skills/xsecurity/scripts/patch_artifacts.py`
  (877 lines; subprocess + three deletion paths), `render_report.py` (651; artifact rendering +
  deletion), `write_scan_meta.py` (231; git subprocess), `install.sh` (293; writes to `$HOME`,
  fetches and executes a remote tarball), `scripts/sync-upstream.sh` (91; network trust boundary),
  `hooks/pre-push` + `hooks/work-tracker-sessionstart.sh` (28), `scripts/test-install.sh` (53).
- **Reviewed for cross-reference integrity only: the skill and doc markdown** (`AGENTS.md`,
  `README.md`, `docs/index.md`, `skills/*/SKILL.md`, `skills/xsecurity/{jobs,specs,role}`) — every
  referenced path, script name and flag was resolved against the tree; the two `scrub` findings
  came out of that pass. A prompt-quality review of the instruction prose is a different exercise
  and was not attempted.
- **Not reviewed: `skills/xreview/rulesets/`** — verbatim third-party mirror, excluded as vendored
  per Phase 0A. Its supply-chain path is pinned by `UPSTREAM.lock`, which was the last audit's
  security finding and is fixed.
