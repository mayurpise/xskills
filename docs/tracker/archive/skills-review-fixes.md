# Skills review fixes — apply the 2026-08-20 deep-review findings

> Verify-first: 1) re-read row + source doc · 2) `git log` + grep the symbol on main ·
> 3) confirm still required · 4) flip shipped/obsolete rows with evidence. Then code.

Source: `docs/audit/skills-deep-review-2026-08-20.md`. C1's scope changed by user request
2026-08-20: complete local copy of claude-security as xsecurity (port script deriving the
engine from the user's installed plugin — its license permits internal-use modification,
not redistribution, so no plugin content enters this repo).

- [x] SRF-1 · C2: scrub clean-tree precondition · 1d51e6f
- [x] SRF-2 · C1: complete xsecurity engine — port script + dispatch edits + install wiring + README · 8b8d41b, 06a1b39
- [x] SRF-3 · I4: scripts/test-skill-refs.py + CI job · a5ad4f4
- [x] SRF-4 · I1: scrub Phase 1 glob-not-read + docs/index.md correction · 1d51e6f
- [x] SRF-5 · I2: minimalist standards de-Python-scoped · e478422
- [x] SRF-6 · I3: xsecurity git grant enumerated read-only + role.md wording · 8b8d41b
- [x] SRF-7 · I5: install.sh skips Claude-only skills for cursor/copilot + test · a1bbd6c
- [x] SRF-8 · S1: scrub read-only agents note · 1d51e6f
- [x] SRF-9 · S2: scrub resolve per-language gate commands in Phase 1 · 1d51e6f
- [x] SRF-10 · S3: scrub Tier 1 dead-code restricted to module-private symbols · 1d51e6f
- [x] SRF-11 · S4: model-tier line in scrub + xreview dispatch · 1d51e6f, cb6fd26
- [x] SRF-12 · S5: first-party rulesets/shell.md + xreview wiring · cb6fd26
- [x] SRF-13 · S6: xreview audit-mode default unit budget · cb6fd26
- [x] SRF-14 · S7: xreview cross-dimension de-dup rule · cb6fd26
- [x] SRF-15 · S8: xreview draft-PR skip yields to explicit ask · cb6fd26
- [x] SRF-16 · S9: work-tracker hook tracker-present flag + goals routing row · f0c46b5
- [x] SRF-17 · S10: okr baseline≠target guard · f0c46b5
- [x] SRF-18 · S11: lean-python-docs Usage-line KEEP bullet · f0c46b5
