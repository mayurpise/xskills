#!/usr/bin/env bash
# Derives the xsecurity scan engine — the scan workflow plus its seven agents — from
# the user's locally installed claude-security plugin, rebranded into the xsecurity
# namespace so the xskills xsecurity skill runs self-contained:
#   ~/.claude/agents/xsecurity.md, ~/.claude/agents/xsecurity-*.md
#   ~/.claude/workflows/xsecurity-scan.js
#
# Why derive instead of vendor: the plugin's LICENSE grants a modify-for-internal-use
# license only and forbids redistributing the plugin or modified versions, so the
# engine files never enter this repository. This script rebuilds them on each user's
# machine from that user's own plugin install, which the license permits.
#
# Idempotent: re-running overwrites the derived files (they are regenerated, never
# hand-edited; re-run after a plugin update to pick up the new version). Safe when
# the plugin is absent: prints how to install it and exits 0, so install.sh can call
# it unconditionally.
#
# Usage: scripts/port-claude-security.sh    (also run by install.sh for Claude Code)
set -euo pipefail

CACHE="$HOME/.claude/plugins/cache"
AGENTS_DEST="$HOME/.claude/agents"
WORKFLOWS_DEST="$HOME/.claude/workflows"

# The claude-security install the plugin manager actually uses: installed_plugins.json
# is authoritative (the cache can hold stale rc dirs that sort -V would rank above the
# release); fall back to the most recently modified cache dir when jq is unavailable.
SRC=""
PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"
if command -v jq >/dev/null 2>&1 && [[ -f "$PLUGINS_JSON" ]]; then
  SRC="$(jq -r '[.plugins | to_entries[] | select(.key | startswith("claude-security@"))
                 | .value[].installPath] | first // empty' "$PLUGINS_JSON" 2>/dev/null || true)"
fi
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  SRC="$(find "$CACHE" -mindepth 3 -maxdepth 3 -type d -path '*/claude-security/*' 2>/dev/null | xargs -r ls -td 2>/dev/null | head -1 || true)"
fi
if [[ -z "$SRC" || ! -f "$SRC/workflows/scan.js" || ! -d "$SRC/agents" ]]; then
  echo "  ! engine no claude-security plugin install found under $CACHE"
  echo "           install it in Claude Code (/plugin install claude-security), then run"
  echo "           scripts/port-claude-security.sh to derive the xsecurity engine"
  exit 0
fi

mkdir -p "$AGENTS_DEST" "$WORKFLOWS_DEST"

# Namespace rewrite applied to every derived file. Expression order matters:
#   1. agent types first (claude-security:scan-inventory, …:explore), so the later
#      rewrites cannot eat their prefix;
#   2. the workflow name claude-security:scan (only bare references remain after 1);
#   3. the orchestrator's initialPrompt /claude-security:claude-security → /xsecurity,
#      before the catch-all would mangle it;
#   4. plugin-root skill paths → the installed xsecurity skill (baked absolute $HOME,
#      since ${CLAUDE_PLUGIN_ROOT} does not exist for user-level agents);
#   5. brand prose;
#   6. catch-all for what remains (the orchestrator's name:, /claude-security menu
#      references, plain mentions).
rebrand() {
  sed -e 's/claude-security:\(scan-inventory\|scan-researcher\|scan-verifier\|patch-generator\|patch-verifier\|explore\)/xsecurity-\1/g' \
      -e 's/claude-security:scan/xsecurity-scan/g' \
      -e 's|/claude-security:claude-security|/xsecurity|g' \
      -e "s|\${CLAUDE_PLUGIN_ROOT}/skills/claude-security|$HOME/.claude/skills/xsecurity|g" \
      -e 's/Claude Security/xsecurity/g' \
      -e 's/claude-security/xsecurity/g'
}

for src in "$SRC"/agents/*.md; do
  base="$(basename "$src" .md)"
  if [[ "$base" == "claude-security" ]]; then
    new="xsecurity"                       # the orchestrator keeps the bare name
  else
    new="xsecurity-$base"                 # scan-researcher → xsecurity-scan-researcher, …
  fi
  # rebrand the body, then pin the frontmatter name to the file's derived name.
  rebrand < "$src" | sed -e "0,/^name: .*/s//name: $new/" > "$AGENTS_DEST/$new.md"
  echo "  ✓ agent    $new → $AGENTS_DEST/$new.md"
done

rebrand < "$SRC/workflows/scan.js" \
  | sed -e 's/^export const meta={name:"scan"/export const meta={name:"xsecurity-scan"/' \
  > "$WORKFLOWS_DEST/xsecurity-scan.js"
echo "  ✓ workflow xsecurity-scan → $WORKFLOWS_DEST/xsecurity-scan.js"

# A leftover reference means a rewrite rule missed a form the plugin added; the
# derived engine would then dispatch a namespace that may not exist. Surface it.
leftover="$(grep -l 'claude-security' "$WORKFLOWS_DEST/xsecurity-scan.js" "$AGENTS_DEST"/xsecurity*.md 2>/dev/null || true)"
[[ -n "$leftover" ]] && echo "  ! engine unrewritten claude-security references remain in: $leftover"

echo "  ✓ engine   derived from plugin $(basename "$(dirname "$SRC")")@$(basename "$SRC")"
