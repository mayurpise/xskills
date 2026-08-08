#!/usr/bin/env bash
# Guards install.sh's one destructive path: writing config over a file the user wrote.
# The header promises "an existing destination is backed up to <file>.bak before it is
# replaced" — a regression there silently destroys a user's global instructions, which
# is exactly what happened before this test existed. Runs against a throwaway $HOME.
#
# Usage: scripts/test-install.sh   (exit 0 = pass)

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
repo="$PWD"

fake_home="$(mktemp -d)"; trap 'rm -rf "$fake_home"' EXIT
sentinel="the user's own rules — must survive"

fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$fake_home/.claude"
printf '%s\n' "$sentinel" > "$fake_home/.claude/CLAUDE.md"

HOME="$fake_home" "$repo/install.sh" --claude --config >/dev/null

[[ -f "$fake_home/.claude/CLAUDE.md.bak" ]] \
  || fail "global config overwritten with no .bak"
grep -qF "$sentinel" "$fake_home/.claude/CLAUDE.md.bak" \
  || fail ".bak does not hold the user's original content"
cmp -s "$repo/AGENTS.md" "$fake_home/.claude/CLAUDE.md" \
  || fail "global config was not replaced with AGENTS.md"

# Second run must not clobber the .bak with the copy we just installed.
HOME="$fake_home" "$repo/install.sh" --claude --config >/dev/null
grep -qF "$sentinel" "$fake_home/.claude/CLAUDE.md.bak" \
  || fail "re-running install overwrote the .bak with installed content"

echo "PASS: install.sh backs up user-owned config before replacing it"

# --- arg parsing: an optional value follows --config only if it is not a flag ---
proj="$fake_home/proj"
HOME="$fake_home" "$repo/install.sh" --config "$proj" >/dev/null
[[ -f "$proj/CLAUDE.md" ]] || fail "--config <dir> did not write into the project dir"

HOME="$fake_home" "$repo/install.sh" --config -h | head -1 | grep -q '^Usage:' \
  || fail "--config -h swallowed the flag as a directory instead of showing usage"

HOME="$fake_home" "$repo/install.sh" --help | grep -q -- '-h | --help' \
  || fail "usage output is truncated — the header block and the sed range disagree"

if HOME="$fake_home" "$repo/install.sh" --bogus >/dev/null 2>&1; then
  fail "unknown flag did not exit non-zero"
fi

echo "PASS: install.sh argument parsing"
