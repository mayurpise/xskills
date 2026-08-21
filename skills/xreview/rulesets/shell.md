<!-- First-party xskills ruleset — NOT part of the upstream mirror. The mirrored
     files are the ones listed in rulesets/UPSTREAM.lock, managed by
     scripts/sync-upstream.sh; this file is authored and maintained in xskills. -->

> Favor precision over recall: only raise an issue when you are confident it is a real defect, and stay silent when the surrounding context is unclear. Treat correctness and destructive-path findings as blocking, and style or idiom suggestions as non-blocking.

#### Quoting and Word Splitting
- Unquoted variable or command-substitution expansions (`$var`, `$(cmd)`) where the value can contain spaces, globs, or be empty — word splitting and pathname expansion rewrite the argument list
- `$@` unquoted, or `$*` where per-argument integrity matters; `"$@"` is almost always what was meant
- A variable holding multiple arguments as one string instead of an array; expanding it unquoted to "make it work" is the symptom
- Filenames from expansion passed to commands without `--`, so a leading `-` becomes an option (`rm "$f"` vs `rm -- "$f"`)
- Do not report deliberately unquoted expansions of controlled, split-intended lists that a comment or the surrounding idiom makes clear

#### `set -e` / `-u` / `pipefail` Interactions
- `local var=$(cmd)` (or `export`/`declare` with assignment): the builtin's exit status masks `cmd`'s failure under `set -e`; declare and assign separately when the failure matters
- A function or script ending in `[[ cond ]] && cmd` returns nonzero when the condition is false — a silent failure signal to callers, fatal under `set -e` at the call site
- Commands inside `if`/`while`/`&&`/`||` contexts are exempt from `set -e`; a multi-command body relying on `-e` inside such a context silently tolerates mid-body failures
- Pipelines without `pipefail` report only the last command's status; a failing producer (`curl … | tar`) goes unnoticed
- `set -u` with optional variables accessed bare instead of `${var:-}`; conversely, `${var:-default}` hiding a typo'd variable name
- A `cd` whose failure is not handled (`cd "$d" || exit`, or `set -e` in effect) before destructive or path-relative operations

#### Error Handling and Cleanup
- `mktemp` without a `trap … EXIT` cleanup, leaking temp files/dirs on every early exit
- A later `trap … EXIT` silently replacing an earlier one, dropping its cleanup
- `rm -rf` on a path built from a variable that can be empty or unset (`rm -rf "$dir/"…` → `rm -rf /…`); require the variable validated or the path fenced first — blocking
- Overwriting a destination without backup or `cmp`-style idempotence where the header or docs promise recoverability
- Exit codes: scripts that document distinct exit codes but return a shell default (the last command's status) on some paths

#### Command Execution and Input
- `eval`, or `bash -c` on strings assembled from untrusted input — command injection
- `read` without `-r` mangling backslashes; `read` loops without `IFS=` trimming whitespace it should keep
- Parsing `ls` output in loops; use globs (`nullglob` guarded) or `find -print0 | while IFS= read -r -d ''`
- `echo` for arbitrary data (`-n`/`-e` interpretation, leading-dash loss); use `printf '%s\n'`
- Untrusted values interpolated into a `sed`/`awk`/`jq` program string instead of passed as data (`--arg`, `-v`)

#### Portability and Robustness
- Bashisms (`[[`, arrays, `local`, process substitution) under a `#!/bin/sh` shebang
- Missing shebang, or a shebang that disagrees with the features used
- `which` for existence checks; `command -v` is the reliable form
- Relative paths that assume the caller's CWD where the script means its own directory (resolve from `${BASH_SOURCE[0]}` — and note stdin execution yields no path)

Do not report: pure style (backticks vs `$( )`, `function` keyword), patterns a ShellCheck directive comment explicitly silences, or POSIX-compliance concerns in a file whose shebang and surrounding scripts are explicitly bash.
