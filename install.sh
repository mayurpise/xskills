#!/usr/bin/env bash
# Installs the xskills skills and/or project config files for supported AI coding tools.
# AGENTS.md is the single source of truth; per-tool config files (CLAUDE.md, Cursor,
# Copilot) are generated at install time.
# Skills live under skills/<name>/SKILL.md and are installed to each tool's skills dir.
#
# Usage:
#   ./install.sh                        # skills for detected tools
#   ./install.sh --cursor               # skills for Cursor only
#   ./install.sh --claude               # skills for Claude Code only
#   ./install.sh --copilot              # skills for GitHub Copilot only
#   ./install.sh --all                  # skills for all three tools (forced, no detection)
#   ./install.sh --config               # skills + global config for detected tools
#   ./install.sh --config <dir>         # config into a project dir ONLY (no global skills)
#   ./install.sh --all --config         # skills + global config for all three tools
#   ./install.sh -h | --help            # show usage
#   no clone; flags go after `--`:
#   curl -fsSL https://raw.githubusercontent.com/mayurpise/xskills/main/install.sh | bash -s -- --config
#
# Safety: an existing destination is backed up to <file>.bak before it is replaced;
# files that are already identical are left untouched.
#
# Global config destinations (no dir given):
#   Claude Code  → ~/.claude/CLAUDE.md
#   Cursor       → ~/.cursor/rules/project.mdc
#   Copilot      → project-level only; supply a dir
#   AGENTS.md    → project-level only; supply a dir
#
# NOTE: "skills" (SKILL.md) are primarily a Claude Code construct. The Cursor and
# Copilot skill dirs are best-effort; verify those tools actually consume SKILL.md
# before relying on them. The Cursor global rules path below is likewise best-effort.
#
# Installing Claude skills also wires a global SessionStart hook into
# ~/.claude/settings.json that auto-activates the work-tracker skill each session
# (idempotent; settings.json is backed up before merge; needs jq).

set -euo pipefail

# Read from stdin (curl … | bash) bash reports the script as "main", not a path, so
# SCRIPT_DIR falls back to $PWD. Keep SCRIPT_PATH to tell the two cases apart below.
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_SRC="$SCRIPT_DIR/AGENTS.md"
SKILL_FILE="SKILL.md"

# Piped (curl … | bash) there is no repo beside the script, only the script itself.
# Fetch the tree it copies from and hand over to that copy. Test SCRIPT_PATH first:
# without it $PWD is searched instead, and any directory that happens to hold a
# skills/ and an AGENTS.md would be installed in place of xskills. Override the
# tarball to install a pinned revision: XSKILLS_TARBALL=…/archive/<sha>.tar.gz
if [[ ! -f "$SCRIPT_PATH" || ! -d "$SKILLS_DIR" || ! -f "$AGENTS_SRC" ]]; then
  command -v curl >/dev/null 2>&1 || { echo "xskills: curl is required to install from GitHub" >&2; exit 1; }
  BOOTSTRAP_DIR="$(mktemp -d)"
  trap 'rm -rf "$BOOTSTRAP_DIR"' EXIT
  echo "  ↓ fetching xskills…"
  curl -fsSL "${XSKILLS_TARBALL:-https://github.com/mayurpise/xskills/archive/refs/heads/main.tar.gz}" \
    | tar -xz --strip-components=1 -C "$BOOTSTRAP_DIR"
  bash "$BOOTSTRAP_DIR/install.sh" "$@"   # set -e propagates a failing install
  exit 0
fi

# Per-tool skills install roots
CURSOR_SKILLS_ROOT="$HOME/.cursor/skills"
CLAUDE_SKILLS_ROOT="$HOME/.claude/skills"
COPILOT_SKILLS_ROOT="$HOME/.copilot/skills"

# Global config install paths
CURSOR_CONFIG="$HOME/.cursor/rules/project.mdc"
CLAUDE_CONFIG="$HOME/.claude/CLAUDE.md"

# Claude SessionStart hook (auto-activates the work-tracker skill every session)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
HOOK_SRC="$SCRIPT_DIR/hooks/work-tracker-sessionstart.sh"
HOOK_DEST="$HOME/.claude/hooks/work-tracker-sessionstart.sh"

# xsecurity scan engine (Claude only): derived on this machine from the user's
# installed claude-security plugin — its license permits internal-use modification
# but not redistribution, so the engine is never shipped in this repo.
PORT_SRC="$SCRIPT_DIR/scripts/port-claude-security.sh"

CURSOR_FRONTMATTER='---\ndescription: Project-level coding and agent guidelines\nalwaysApply: true\n---\n\n'

# Print the Usage block from this file's header. Matched by pattern, not line
# numbers, so editing the header cannot silently truncate the output.
print_usage() {
  sed -n '/^# Usage:/,/^#$/p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
}

# Membership test: has <needle> <list...>
has() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# Back up an existing file to <file>.bak so an overwrite is recoverable.
backup_if_exists() {
  if [[ -f "$1" ]]; then
    cp "$1" "$1.bak"
    echo "    ↳ backed up existing → $1.bak"
  fi
  return 0
}

# Copy src→dest idempotently: skip if identical, overwrite otherwise.
# Skills and the hook are ours to own — the destination only ever holds a previous
# copy of this repo's file, so no backup is kept. Pass a non-empty 4th arg to back
# up first, required anywhere the destination may hold a file the user wrote:
# project dirs and the global config paths (~/.claude/CLAUDE.md et al).
# Portable same-file/same-content handling via cmp (no realpath dependency).
install_file() {
  local src="$1" dest="$2" label="$3" backup="${4:-}"
  if cmp -s "$src" "$dest" 2>/dev/null; then
    echo "  = $label unchanged → $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  [[ -n "$backup" ]] && backup_if_exists "$dest"
  cp "$src" "$dest"
  echo "  ✓ $label → $dest"
}

# Generate the Cursor config (frontmatter + CLAUDE.md) and install it via install_file.
install_cursor_config() {
  local dest="$1" backup="${2:-}"
  local tmp; tmp="$(mktemp)"
  { printf -- "$CURSOR_FRONTMATTER"; cat "$AGENTS_SRC"; } > "$tmp"
  install_file "$tmp" "$dest" "config Cursor" "$backup"
  rm -f "$tmp"
}

install_skills_to_root() {
  local dest_root="$1" tool="$2"
  shopt -s nullglob
  local installed_any=0
  for skill_dir in "$SKILLS_DIR"/*/; do
    local name; name="$(basename "$skill_dir")"
    [[ -f "$skill_dir$SKILL_FILE" ]] || continue   # a skill dir must have SKILL.md
    # Install every file under the skill dir (SKILL.md plus bundled resources such
    # as xreview/rulesets/), preserving relative paths.
    while IFS= read -r -d '' src; do
      local rel="${src#"$skill_dir"}"
      # Skip bytecode and editor junk; skills only need source + docs.
      case "$rel" in
        *__pycache__/*|*.pyc|*.pyo|.DS_Store) continue ;;
      esac
      install_file "$src" "$dest_root/$name/$rel" "skill  $tool/$name/$rel"
    done < <(find "$skill_dir" -type f -print0)
    installed_any=1
  done
  shopt -u nullglob
  [[ $installed_any -eq 0 ]] && echo "  ! no skills found under $SKILLS_DIR"
  return 0
}

# Install the Claude SessionStart hook and wire it into settings.json.
# Global-only (settings.json hooks have no project scope). Idempotent; backs up
# settings.json before merging. Requires jq for the merge — degrades gracefully.
install_claude_hook() {
  [[ -f "$HOOK_SRC" ]] || { echo "  ! hook   source missing: $HOOK_SRC"; return 0; }
  install_file "$HOOK_SRC" "$HOOK_DEST" "hook   Claude SessionStart"
  chmod +x "$HOOK_DEST"

  local hook_cmd="bash $HOOK_DEST"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ! hook   jq not found — add a SessionStart hook to $CLAUDE_SETTINGS manually:"
    echo "           matcher \"startup|resume|clear\" → command: $hook_cmd"
    return 0
  fi

  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [[ -f "$CLAUDE_SETTINGS" ]] || echo '{}' > "$CLAUDE_SETTINGS"

  if jq -e --arg cmd "$hook_cmd" \
       '[.hooks.SessionStart[]?.hooks[]?.command] | index($cmd)' \
       "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
    echo "  = hook   Claude SessionStart already wired → $CLAUDE_SETTINGS"
    return 0
  fi

  local tmp; tmp="$(mktemp)"
  if jq --arg cmd "$hook_cmd" '
        .hooks //= {} |
        .hooks.SessionStart //= [] |
        .hooks.SessionStart += [{
          "matcher": "startup|resume|clear",
          "hooks": [ { "type": "command", "command": $cmd } ]
        }]' "$CLAUDE_SETTINGS" > "$tmp"; then
    backup_if_exists "$CLAUDE_SETTINGS"
    mv "$tmp" "$CLAUDE_SETTINGS"
    echo "  ✓ hook   Claude SessionStart wired → $CLAUDE_SETTINGS"
  else
    rm -f "$tmp"
    echo "  ! hook   failed to merge settings.json (left unchanged)"
  fi
}

# Derive the xsecurity scan engine from the installed claude-security plugin.
# Degrades to a hint when the plugin (or the script, in old checkouts) is absent.
install_xsecurity_engine() {
  [[ -f "$PORT_SRC" ]] || return 0
  bash "$PORT_SRC"
}

# Install config to each targeted tool's global home dir.
install_config_global() {
  if has claude "$@"; then
    install_file "$AGENTS_SRC" "$CLAUDE_CONFIG" "config Claude Code" backup
  fi
  if has cursor "$@"; then
    install_cursor_config "$CURSOR_CONFIG" backup
  fi
  if has copilot "$@"; then
    echo "  ! config Copilot    → project-level only; use --config <dir>"
  fi
}

# Install config into a specific project directory for each targeted tool.
install_config_project() {
  local dir="$1"; shift
  mkdir -p "$dir"
  if has claude "$@"; then
    install_file "$AGENTS_SRC" "$dir/CLAUDE.md"  "config Claude Code" backup
    install_file "$AGENTS_SRC" "$dir/AGENTS.md" "config AGENTS.md" backup
  fi
  if has cursor "$@"; then
    install_cursor_config "$dir/.cursor/rules/project.mdc" backup
  fi
  if has copilot "$@"; then
    install_file "$AGENTS_SRC" "$dir/.github/copilot-instructions.md" "config Copilot" backup
  fi
}

# --- parse args ---
do_cursor=0; do_claude=0; do_copilot=0; do_all=0
do_config=0; config_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cursor)  do_cursor=1 ;;
    --claude)  do_claude=1 ;;
    --copilot) do_copilot=1 ;;
    --all)     do_all=1 ;;
    -h|--help) print_usage; exit 0 ;;
    --config)
      do_config=1
      # An optional directory may follow; anything starting with - is the next flag.
      if [[ $# -gt 1 && "$2" != -* ]]; then
        config_dir="$2"
        shift
      fi
      ;;
    *)
      echo "Unknown flag: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

# --- resolve target tools (explicit > --all > detection) ---
tools=()
if [[ $do_all -eq 1 ]]; then
  tools=(cursor claude copilot)
elif [[ $(( do_cursor + do_claude + do_copilot )) -gt 0 ]]; then
  [[ $do_cursor  -eq 1 ]] && tools+=(cursor)
  [[ $do_claude  -eq 1 ]] && tools+=(claude)
  [[ $do_copilot -eq 1 ]] && tools+=(copilot)
else
  [[ -d "$HOME/.cursor" ]]         && tools+=(cursor)
  [[ -d "$HOME/.claude" ]]         && tools+=(claude)
  [[ -d "$HOME/.copilot" ]] && tools+=(copilot)
fi

if [[ ${#tools[@]} -eq 0 ]]; then
  echo "No supported tools detected — none of ~/.claude, ~/.cursor, ~/.copilot exists yet."
  echo "Name the tools explicitly with --cursor, --claude, --copilot, or --all:"
  echo "  ./install.sh --all --config"
  echo "  curl -fsSL https://raw.githubusercontent.com/mayurpise/xskills/main/install.sh | bash -s -- --all --config"
  exit 1
fi

# --- install skills (global-only; skipped entirely in project-config mode) ---
if [[ -n "$config_dir" ]]; then
  echo "Project-config mode: skipping global skill install (skills are global-only; run without <dir> to install them)."
else
  echo "Installing skills for: ${tools[*]}"
  for tool in "${tools[@]}"; do
    case "$tool" in
      cursor)  install_skills_to_root "$CURSOR_SKILLS_ROOT"  "Cursor" ;;
      claude)  install_skills_to_root "$CLAUDE_SKILLS_ROOT"  "Claude Code"; install_claude_hook; install_xsecurity_engine ;;
      copilot) install_skills_to_root "$COPILOT_SKILLS_ROOT" "GitHub Copilot" ;;
    esac
  done
fi

# --- install config ---
if [[ $do_config -eq 1 ]]; then
  if [[ -n "$config_dir" ]]; then
    echo "Installing config into $config_dir for: ${tools[*]}"
    install_config_project "$config_dir" "${tools[@]}"
  else
    echo "Installing global config for: ${tools[*]}"
    install_config_global "${tools[@]}"
  fi
fi
