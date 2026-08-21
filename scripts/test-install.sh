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

# --- Claude-only skills stay out of other tools' skill dirs ---
HOME="$fake_home" "$repo/install.sh" --cursor >/dev/null
[[ -d "$fake_home/.cursor/skills/scrub" ]] \
  || fail "cursor install missing a portable skill (scrub)"
[[ -e "$fake_home/.cursor/skills/xsecurity" ]] \
  && fail "cursor install shipped the Claude-only xsecurity skill"

echo "PASS: Claude-only skills are skipped for non-Claude tools"

# --- piped install (curl | bash) must fetch xskills, never install $PWD ---
# Read from stdin the script has no path, so a $PWD-based root resolution silently
# installs whatever tree the user happens to stand in. XSKILLS_TARBALL points the
# bootstrap at this repo so the check needs no network.
decoy="$fake_home/decoy"
mkdir -p "$decoy/skills/notxskills"
printf 'NOT XSKILLS\n' > "$decoy/AGENTS.md"
printf '# not an xskills skill\n' > "$decoy/skills/notxskills/SKILL.md"

tarball="$fake_home/xskills.tar.gz"
git archive --format=tar.gz --prefix=xskills/ HEAD > "$tarball"

piped_home="$fake_home/piped"; mkdir -p "$piped_home/.claude"
(cd "$decoy" && HOME="$piped_home" XSKILLS_TARBALL="file://$tarball" \
   bash -s -- --claude --config < "$repo/install.sh" >/dev/null)

[[ -e "$piped_home/.claude/skills/notxskills" ]] \
  && fail "piped install took skills from \$PWD instead of fetching xskills"
grep -qF 'NOT XSKILLS' "$piped_home/.claude/CLAUDE.md" \
  && fail "piped install wrote \$PWD's AGENTS.md as the global config"
cmp -s "$repo/AGENTS.md" "$piped_home/.claude/CLAUDE.md" \
  || fail "piped install did not write the fetched xskills AGENTS.md"

echo "PASS: piped install fetches xskills instead of installing \$PWD"
