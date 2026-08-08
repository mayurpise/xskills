#!/usr/bin/env bash
# Deterministic ruleset sync: mirror selected open-code-review rulesets into the
# xreview skill's bundled rulesets/ dir at a pinned commit. Files there are VERBATIM
# upstream mirrors — do NOT edit; re-fetching the same SHA is byte-identical. Because
# they live under skills/xreview/, install.sh ships them alongside the skill.
#
# The pin is the commit recorded in UPSTREAM.lock, and it is the default so that a
# routine run — including the pre-push hook — can never pull unreviewed upstream code
# into the repo. Moving the pin is a deliberate act: pass REF explicitly.
#
# Usage:
#   scripts/sync-upstream.sh          # verify against the pinned commit in UPSTREAM.lock
#   scripts/sync-upstream.sh --check  # report drift only, write nothing (CI/hook dry-run)
#   REF=main scripts/sync-upstream.sh # move the pin to upstream main's current HEAD
#   REF=<sha|tag|branch> scripts/sync-upstream.sh   # move the pin to a specific ref
#
# Exit codes: 0 = up to date, 3 = changed (drift), 2 = network/fetch error.
# Deps: git, curl (no jq/gh).

set -euo pipefail

UPSTREAM="alibaba/open-code-review"
explicit_ref="${REF:-}"
DEST="skills/xreview/rulesets"
RULE_PREFIX="internal/config/rules/rule_docs"

# Rulesets to mirror (basenames under $RULE_PREFIX upstream). Edit to change coverage.
RULES=( default.md python.md ts_js_tsx_jsx.md )

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

cd "$(git rev-parse --show-toplevel)"
LOCK="$DEST/UPSTREAM.lock"

# No explicit REF -> re-verify the recorded pin, and keep the lock's ref label so a
# routine run does not rewrite it. Explicit REF -> that ref becomes the new pin.
if [[ -z "$explicit_ref" && -f "$LOCK" ]]; then
  REF="$(awk '$1=="commit:"{print $2}' "$LOCK")"
  ref_label="$(awk '$1=="ref:"{print $2}' "$LOCK")"
else
  REF="${explicit_ref:-main}"
  ref_label="$REF"
fi
[[ -n "$REF" ]] || { echo "sync-upstream: no pin in $LOCK and no REF given" >&2; exit 2; }

# Resolve REF -> commit SHA (deterministic pin). A 40-hex REF is used as-is.
# `|| sha=""` keeps a failed ls-remote (offline) from aborting under `set -e` before
# the guard below can report it as the documented exit-2 network error.
if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
  sha="$REF"
else
  sha="$(git ls-remote "https://github.com/$UPSTREAM" "$REF" 2>/dev/null | cut -f1)" || sha=""
fi
[[ -n "${sha:-}" ]] || { echo "sync-upstream: could not resolve $UPSTREAM@$REF (offline?)" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
changed=0

# "<upstream path>|<local basename under $DEST>"
declare -a MAP=( "LICENSE|LICENSE" )
for r in "${RULES[@]}"; do MAP+=( "$RULE_PREFIX/$r|$r" ); done

for pair in "${MAP[@]}"; do
  up="${pair%%|*}"; base="${pair##*|}"
  if ! curl -fsSL "https://raw.githubusercontent.com/$UPSTREAM/$sha/$up" -o "$tmp/f" 2>/dev/null; then
    echo "sync-upstream: fetch failed: $up" >&2; exit 2
  fi
  dest="$DEST/$base"
  if [[ -f "$dest" ]] && cmp -s "$tmp/f" "$dest"; then continue; fi
  changed=1; echo "  changed: $base"
  [[ $check_only -eq 0 ]] && { mkdir -p "$DEST"; cp "$tmp/f" "$dest"; }
done

if [[ $check_only -eq 0 ]]; then
  mkdir -p "$DEST"
  {
    echo "# Verbatim upstream mirror — do not edit. Managed by scripts/sync-upstream.sh."
    echo "upstream: https://github.com/$UPSTREAM"
    echo "license:  Apache-2.0"
    echo "ref:      $ref_label"
    echo "commit:   $sha"
    echo "rules:"
    printf '  - %s\n' "${RULES[@]}"
  } > "$LOCK"
fi

if [[ $changed -eq 1 ]]; then
  echo "sync-upstream: rulesets updated to $UPSTREAM@${sha:0:12}"; exit 3
fi
echo "sync-upstream: up to date at $UPSTREAM@${sha:0:12}"; exit 0
