# dotai

[![GitHub stars](https://img.shields.io/github/stars/mayurpise/dotai?style=flat-square&color=gold)](https://github.com/mayurpise/dotai/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/mayurpise/dotai?style=flat-square)](https://github.com/mayurpise/dotai/network/members)
[![GitHub last commit](https://img.shields.io/github/last-commit/mayurpise/dotai?style=flat-square)](https://github.com/mayurpise/dotai/commits/main)

AI coding tool configs that reduce wasted tokens and prevent scope creep. Works with Claude Code, Cursor, and GitHub Copilot.

## What's included

| File | Purpose |
|------|---------|
| `AGENTS.md` | Project-level agent operating instructions — single source of truth (`CLAUDE.md` is a symlink to it) |
| `skills/scrub/SKILL.md` | `/scrub` skill — tiered code review that applies fixes within a behavior-preserving safety envelope; skips changes it can't lock with a test |
| `skills/xreview/SKILL.md` | `/xreview` skill — high-signal review of a PR, local diff, or existing code (audit mode — inferred, no flag; risk-ranked unit by unit for brownfield codebases) across nine dimensions (bugs, security, performance, CLAUDE.md compliance, silent failures, test coverage, comment accuracy, type design, simplification); validates every candidate before reporting so false positives are filtered out |
| `skills/work-tracker/SKILL.md` | `/work-tracker` skill — route long-form docs and maintain a sharded tracker (`docs/tracker/INDEX.md` + one file per major work) with a verify-first protocol and read-one-file token discipline |
| `skills/okr/SKILL.md` | `/okr` skill — track objectives and key results (OKRs) one altitude above the work tracker: a north-star objective plus measurable KRs, each linking down to the `docs/tracker/<slug>.md` work that moves it (outcomes here, outputs in the tracker) |
| `skills/minimalist/SKILL.md` | `/minimalist` skill — classify the task (NEW/CHANGE/REFACTOR/MIXED), freeze a manifest, lock the definition of done (tests for new behavior, characterization tests for refactors), execute surgically, then delete everything not traceable to a passing test |
| `skills/lean-python-docs/SKILL.md` | `/lean-python-docs` skill — documentation discipline for Python: keep public-API summaries, the WHY behind non-obvious code, invariants, and refs; cut docstrings that restate the signature and comments that narrate the next line |
| `hooks/work-tracker-sessionstart.sh` | SessionStart hook that auto-activates the work-tracker skill each session (wired into `~/.claude/settings.json` by `install.sh`; Claude Code only) |
| `install.sh` | Copies files to the right location for each tool |

## Install

```bash
# Skills + config for all detected tools (recommended)
./install.sh --config
```

That's it. One command installs every skill under `skills/` and copies the agent instructions (`AGENTS.md`) to the global config dir of every tool it detects (`~/.claude/`, `~/.cursor/`, `~/.copilot/`).

**Other options:**

```bash
# Skills only, auto-detect tools
./install.sh

# Target a specific tool (skill only)
./install.sh --claude     # Claude Code
./install.sh --cursor     # Cursor
./install.sh --copilot    # GitHub Copilot
./install.sh --all        # all three

# Skills + config for all tools (same as --config alone)
./install.sh --all --config

# Install config into a specific project directory
./install.sh --config <dir>
```

## Upstream review rulesets

`skills/xreview/rulesets/` holds verbatim, Apache-2.0 rulesets mirrored from
[alibaba/open-code-review](https://github.com/alibaba/open-code-review), **bundled with the
`xreview` skill** so they install alongside it. Do not edit them — `scripts/sync-upstream.sh`
refreshes them at a pinned commit, and a `pre-push` hook runs it when you push `main`, blocking
the push if they drifted so you commit the update first.

```bash
git config core.hooksPath hooks   # enable the hook (one-time, per clone)
scripts/sync-upstream.sh          # manual refresh; edit the RULES list to change coverage
```

## Docs

Full write-up at [mayurpise.github.io/dotai](https://mayurpise.github.io/dotai/) or in [`docs/`](docs/).
