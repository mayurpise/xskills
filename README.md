# xskills

[![GitHub stars](https://img.shields.io/github/stars/mayurpise/xskills?style=flat-square&color=gold)](https://github.com/mayurpise/xskills/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/mayurpise/xskills?style=flat-square)](https://github.com/mayurpise/xskills/network/members)
[![GitHub last commit](https://img.shields.io/github/last-commit/mayurpise/xskills?style=flat-square)](https://github.com/mayurpise/xskills/commits/main)

AI coding tool configs that reduce wasted tokens and prevent scope creep. Works with Claude Code, Grok, Cursor, and GitHub Copilot.

## What's included

| File | Purpose |
|------|---------|
| `AGENTS.md` | Project-level agent operating instructions — single source of truth (`CLAUDE.md` is a symlink to it) |
| `skills/scrub/SKILL.md` | `/scrub` skill — tiered code review that applies fixes within a behavior-preserving safety envelope; skips changes it can't lock with a test |
| `skills/xreview/SKILL.md` | `/xreview` skill — high-signal review of a PR, local diff, or existing code (audit mode — inferred, no flag; risk-ranked unit by unit for brownfield codebases) across eleven dimensions (bugs, security, performance, contract/compatibility, concurrency/resources, CLAUDE.md compliance, silent failures, test coverage and test integrity, comment accuracy, type design, simplification); validates every candidate before reporting so false positives are filtered out; with `--xsecurity` (opt-in) also runs xsecurity scan-changes on the resolved change set |
| `skills/xsecurity/SKILL.md` | `/xsecurity` skill — a team of agents run as security researchers: scan the codebase, scan changes (working tree, branch, PR diff, or one commit), or turn confirmed findings into targeted `.patch` files; every finding survives a three-voter adversarial panel and every patch a verifier plus a fresh red-team pass before it is written — nothing is applied, committed, or pushed. **Engine note:** the scan workflow and its seven agents are derived on your machine from your installed claude-security plugin (see the row below); they are never committed here |
| `scripts/port-claude-security.sh` | Derives the xsecurity scan engine into `~/.claude/agents/` and `~/.claude/workflows/` from your locally installed claude-security plugin, rebranded to the xsecurity namespace (run automatically by `install.sh` for Claude Code). The plugin's license permits internal-use modification but not redistribution, so the engine never enters this repo — install the claude-security plugin once, then install/port |
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

That's it. One command installs every skill under `skills/` and copies the agent instructions (`AGENTS.md`) to the global config dir of every tool it detects (`~/.claude/`, `~/.cursor/`, `~/.copilot/`). Grok skills go to `~/.grok/skills/`; `--config` without a dir skips Grok (it reads the repo `AGENTS.md`); `--config <dir>` writes that project's `AGENTS.md`.

**Other options:**

```bash
# Skills only, auto-detect tools
./install.sh

# Target a specific tool (skill only)
./install.sh --claude     # Claude Code
./install.sh --grok       # Grok
./install.sh --cursor     # Cursor
./install.sh --copilot    # GitHub Copilot
./install.sh --all        # all four

# Skills + config for all tools (same as --config alone)
./install.sh --all --config

# Install config into a specific project directory
./install.sh --config <dir>
```

**Install straight from GitHub (no clone):**

```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/xskills/main/install.sh | bash -s -- --config
```

The script notices it has no repo beside it, fetches the tarball into a temp dir, installs from
there, and deletes it. Every flag above works the same way — put it after `--`. Pin a revision
with `XSKILLS_TARBALL=https://github.com/mayurpise/xskills/archive/<sha>.tar.gz`. A clone is
still needed for `scripts/sync-upstream.sh` and the `pre-push` hook.

Tools are detected by their config dir (`~/.claude`, `~/.grok`, `~/.cursor`, `~/.copilot`), which each tool
creates on its first run. On a machine where none has been launched yet there is nothing to
detect — name the tools instead:

```bash
curl -fsSL https://raw.githubusercontent.com/mayurpise/xskills/main/install.sh | bash -s -- --all --config
```

## Upstream review rulesets

`skills/xreview/rulesets/` holds verbatim, Apache-2.0 rulesets mirrored from
[alibaba/open-code-review](https://github.com/alibaba/open-code-review), **bundled with the
`xreview` skill** so they install alongside it. Do not edit them — `scripts/sync-upstream.sh`
manages them, pinned to the commit recorded in `rulesets/UPSTREAM.lock`.

The pin is the default, so a routine run (including the `pre-push` hook) only verifies the
mirror still matches it; it never pulls unreviewed upstream code into the repo. Moving the pin
is a deliberate act — pass `REF` explicitly, then commit the result.

```bash
git config core.hooksPath hooks     # enable the hook (one-time, per clone)
scripts/sync-upstream.sh            # verify against the pin; edit the RULES list to change coverage
REF=main scripts/sync-upstream.sh   # move the pin to upstream main, for review
```

## Docs

Full write-up at [mayurpise.github.io/xskills](https://mayurpise.github.io/xskills/) or in [`docs/`](docs/).
