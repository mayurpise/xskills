# xreview audit — xskills repo

**Date:** 2026-08-08
**Mode:** audit (inferred — request named the repo with no reference to a change; working tree was clean)
**Scope:** repo root
**Commit:** caa0fe5

## What this code is

`xskills` distributes agent instructions and skills to Claude Code, Cursor, and Copilot.
The executable surface is 4 shell scripts (369 lines); everything else is markdown consumed
as agent instructions. Trust and failure boundaries: `install.sh` writes into the user's
`$HOME` config dirs, `scripts/sync-upstream.sh` fetches third-party code over the network
into the repo, and `hooks/pre-push` gates `git push` on the result. There are no tests.

## Critical (1)

### [bug] `install.sh:171` — `--config` silently overwrites the user's global `CLAUDE.md` with no backup, contradicting the documented safety guarantee

The header states the contract at line 18:

> `# Safety: an existing destination is backed up to <file>.bak before it is replaced;`

`install_file()` only backs up when a non-empty 4th argument is passed (`install.sh:85,91`).
`install_config_global()` passes three arguments:

```bash
install_file "$AGENTS_SRC" "$CLAUDE_CONFIG" "config Claude Code"     # :171 — no backup arg
install_cursor_config "$CURSOR_CONFIG"                               # :174 — same, backup="" 
```

**Failure:** a user with an existing `~/.claude/CLAUDE.md` runs `./install.sh --config` —
the command README labels "recommended" — and their file is replaced by `AGENTS.md`. No
`.bak` is written. The content is unrecoverable.

Verified on this machine: `~/.claude/CLAUDE.md` exists (10018 bytes), differs from
`AGENTS.md`, and no `.bak` is present. The differing content is substantial — global rules
for NVIDIA stack defaults, `uv` Python tooling, subagent cost discipline, and work-tracking
that `AGENTS.md` does not carry.

The rationale comment at `install.sh:80-82` explains the omission:

> `# Repo-sourced targets (skills, hook, global config) are git-recoverable, so no backup is kept.`

That reasoning holds for the *source* but not the *destination*. `~/.claude/CLAUDE.md` is
the user's own file and is not in any repo. The guarantee at line 18 is the one users read.

**Smallest fix:** pass the backup flag on both global-config calls.

```diff
-    install_file "$AGENTS_SRC" "$CLAUDE_CONFIG" "config Claude Code"
+    install_file "$AGENTS_SRC" "$CLAUDE_CONFIG" "config Claude Code" backup
```
```diff
-    install_cursor_config "$CURSOR_CONFIG"
+    install_cursor_config "$CURSOR_CONFIG" backup
```

## Important (3)

### [bug] `hooks/pre-push:19` — drift message tells the user to commit a path that does not exist

```bash
3) echo "pre-push: upstream mirror updated — commit vendor/open-code-review, then push again." >&2; exit 1 ;;
```

`vendor/open-code-review` was the pre-`7c4213f` location. The rulesets now live at
`skills/xreview/rulesets/`; `vendor/` is absent from the repo. **Failure:** on any drift the
push is blocked and the user is directed at a nonexistent path — `git add
vendor/open-code-review` errors, leaving no obvious way forward. Encountered live during
this session's push.

**Smallest fix:** `commit skills/xreview/rulesets`.

### [silent-failure] `scripts/sync-upstream.sh:34` — offline runs die at exit 128 with no message; the documented exit-2 path and its error text are unreachable

```bash
sha="$(git ls-remote "https://github.com/$UPSTREAM" "$REF" 2>/dev/null | cut -f1)"
[[ -n "${sha:-}" ]] || { echo "sync-upstream: could not resolve $UPSTREAM@$REF (offline?)" >&2; exit 2; }
```

Under `set -euo pipefail` (line 15), a failing command substitution in an assignment aborts
the script immediately. When the network is down, `git ls-remote` exits 128, `pipefail`
propagates it, and the script exits **before** line 36 — so the friendly message never
prints, and stderr is already suppressed by `2>/dev/null`.

Reproduced:

```
$ bash -c 'set -euo pipefail; sha="$(git ls-remote https://github.com/nonexistent/repo main 2>/dev/null | cut -f1)"; echo "MESSAGE REACHED"'
$ echo $?
128        # "MESSAGE REACHED" never printed
```

**Impact:** two documented contracts break. The header (line 12) promises `2 = network/fetch
error`; offline yields 128. `hooks/pre-push:20` branches on exit 2 to print *"upstream sync
skipped (offline/fetch error); pushing anyway"* — that branch never fires for this path, so
the push falls through the `*)` catch-all and proceeds with zero output. The user gets no
indication the mirror was not checked.

Line 36's `(offline?)` hint is also misdirecting: it is only reachable when `ls-remote`
succeeds and prints nothing, i.e. the ref does not exist upstream.

**Smallest fix:** let the failure reach the guard instead of aborting.

```diff
-sha="$(git ls-remote "https://github.com/$UPSTREAM" "$REF" 2>/dev/null | cut -f1)"
+sha="$(git ls-remote "https://github.com/$UPSTREAM" "$REF" 2>/dev/null | cut -f1)" || sha=""
```

### [security] `scripts/sync-upstream.sh:18` — the mirror tracks upstream `main` rather than pinning, so third-party content is auto-ingested on every push

`REF="${REF:-main}"` resolves `main`'s current HEAD on each run (line 34), and
`hooks/pre-push` runs the sync automatically on every push to `main`. `UPSTREAM.lock` records
the resolved SHA but nothing ever reads it back — it is a provenance record, not a pin.

**Attack path:** a commit landing on `alibaba/open-code-review@main` (upstream compromise,
maintainer account takeover, or a malicious PR merge) → the next `git push` in this repo
fetches it into `skills/xreview/rulesets/` → the hook blocks and prompts the maintainer to
commit it → `install.sh` copies it to `~/.claude/skills/xreview/rulesets/`, where it is read
as instructions by a review agent. Ruleset markdown is agent-directed prose, so this is a
prompt-injection sink, not inert data.

This session demonstrated the ingest half unprompted: the push pulled `62e2b9979843` and an
upstream LICENSE reword arrived with it.

The header contradicts the behavior — lines 2-4 call it a *"Deterministic ruleset sync"* at a
*"pinned commit"*. It is deterministic only when `REF` is a SHA.

**Smallest fix:** default `REF` to the SHA already recorded in `UPSTREAM.lock`, so updates
become a deliberate act (`REF=main scripts/sync-upstream.sh`) rather than a push side effect.

## Suggestions (3)

### [bug] `install.sh:59` — `--help` omits the `-h | --help` line

```bash
print_usage() { sed -n '6,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
```

The usage block spans lines 7-16; the hardcoded range stops at 15, so the last entry never
prints. Confirmed by running `./install.sh --help`. A hardcoded line range drifts every time
the header changes — `sed -n '/^# Usage:/,/^#$/p'` would not.

### [test-gap] repo-wide — no tests exist for the installer's overwrite behavior

Criticality 6. `install.sh` writes into `$HOME` and its documented backup guarantee is
currently false (Critical above). One characterization test — seed a destination file, run
`--config`, assert a `.bak` appears — would have caught it. Not arguing for a full bash test
harness; this is the one path where a silent regression destroys user data.

### [simplify] `install.sh:201-225` — manual index arithmetic and indirect expansion where `shift` reads plainly

```bash
i=1
while [[ $i -le $# ]]; do
  arg="${!i}"
  ...
      next=$(( i + 1 ))
      if [[ $next -le $# && "${!next}" != --* ]]; then
        config_dir="${!next}"; i=$next
      fi
  ...
  i=$(( i + 1 ))
done
```

Two indirect expansions (`${!i}`, `${!next}`) and three index updates exist only to support
one lookahead for `--config <dir>`. A `while [[ $# -gt 0 ]]` loop with `$2` for the lookahead
and `shift` to advance drops the index variable and both indirections. Behavior-preserving;
advisory.

## Not findings (checked and refuted)

- **`[[ cond ]] && cmd` under `set -e`** (`sync-upstream.sh:26,53`; `install.sh:66,91,121,232-238`) — correct. A failing command to the left of the final `&&` is exempt from `set -e`; only the command following it is not. Verified.
- **`jq -e ... | index($cmd)`** (`install.sh:144`) — correct. `index` returning `0` for a first-position match is truthy under `jq -e`, which fails only on `false`/`null`. No off-by-one.
- **`printf -- "$CURSOR_FRONTMATTER"`** (`install.sh:100`) — variable format string is a real footgun, but the value is a literal constant (line 56) containing no `%` and no user input. Not exploitable here.
- **`--config -h` swallows `-h` as a directory** (`install.sh:213`) — the `!= --*` guard misses single-dash flags. Real but low impact and malformed input; below the reporting bar.
- **jq/hook fallbacks** (`install.sh:129,135,164`) — every degraded path prints an explicit message and returns cleanly. Correctly *not* silent failures.

## Strengths

- `install_file` is idempotent by content comparison (`cmp`), so re-running is a no-op and output distinguishes `=` unchanged from `✓` written.
- `install_claude_hook` writes jq output to a temp file and only moves it on success (`:158-165`), so a jq failure cannot truncate `settings.json`.
- `sync-upstream.sh` compares fetched bytes before writing (`:51`) and exits with distinct codes per outcome, which makes the hook's decision logic trivial.
- The pre-push hook fails open on network errors by design — the right default for a convenience mirror.

## Coverage

- **Reviewed: 4 units / 4 files (369 lines)** — `scripts/sync-upstream.sh` (network + subprocess trust boundary), `install.sh` (writes to `$HOME`, highest churn at 13 commits), `hooks/pre-push` (gates push), `hooks/work-tracker-sessionstart.sh` (6 lines, nothing to flag).
- **Not reviewed: markdown instruction files** (`AGENTS.md`, `docs/`, `skills/*/SKILL.md`, ~9 files) — prose consumed as agent instructions, not executable code. Auditing them for behavioral defects is not what the code dimensions measure; a prompt-quality review is a different exercise.
- **Not reviewed: `skills/xreview/rulesets/`** — verbatim third-party mirror, excluded as vendored per Phase 0A. Its supply-chain path is covered by the security finding above.
