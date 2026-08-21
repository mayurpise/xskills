#!/usr/bin/env bash
# SessionStart hook: injects the work-tracker operating directive into model context.
# Fires on session startup/resume/clear (wired into ~/.claude/settings.json by install.sh).
# The tracker-present flag saves the model a discovery read in repos with no tracker.
if [[ -f "${CLAUDE_PROJECT_DIR:-.}/docs/tracker/INDEX.md" ]]; then present="yes"; else present="no"; fi
cat <<JSON
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[work-tracker] Operating mode: for work of ~5+ items or spanning sessions, use the work-tracker skill — read docs/tracker/INDEX.md, open only the one docs/tracker/<slug>.md you act on, apply verify-first (re-confirm the gap against main before coding), and Edit single rows rather than rewriting files; route long-form reports/plans/audits to docs/ per the skill. Smaller work uses the in-session task list, no tracker file. (tracker present: $present)"}}
JSON
