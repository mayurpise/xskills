---
name: lean-python-docs
description: "Documentation discipline for Python — apply WHILE writing or editing any Python function, class, or module, before producing docstrings or comments. Keeps the documentation a reader actually needs (public-API summary lines, the WHY behind non-obvious code, invariants, gotchas) and cuts the noise AI tends to over-produce (docstrings restating the signature, comments narrating the next line, boilerplate Args/Returns/Raises on trivial helpers, section-header comments in short functions). Use whenever generating or modifying Python, or when the user says 'too many comments', 'over-documented', 'reduce docs', 'trim docstrings', 'the AI adds too much documentation', or runs '/lean-python-docs'."
---

# Lean Python Documentation

Applies while writing or editing **any** Python. Governing rule:

> **Comment the WHY, never the WHAT.** The code already shows *what* it does and
> *how*. Documentation earns its place only by carrying information the code
> cannot — intent, constraints, rationale, external references. If a line of
> docs restates the code, delete it.

This is a pre-write filter, not a cleanup pass: apply it *as* you type each
docstring or comment. The test for every doc line is one question —
**"Would a competent reader who can read the code already know this?"** If yes,
it is noise. Cut it.

## KEEP — documentation that earns its place

- **A one-line summary docstring on public surfaces** (public module, public
  class, public function/method). One sentence, imperative or descriptive.
  Stop there unless a caller genuinely needs more.
- **The WHY behind non-obvious code:** workarounds, why an edge case is handled
  this way, why the obvious approach was rejected, ordering/timing constraints.
- **Invariants and preconditions** a caller can't infer from the signature
  (e.g. "must hold `self._lock`", "prices are mid = (bid+ask)/2", "fills are
  INSERT-only").
- **External references:** ticket/issue IDs, spec sections, API quirks, links.
- **Non-obvious units, ranges, or side effects** the type can't express
  ("returns basis points", "mutates `positions` in place").
- **`TODO`/`FIXME` with enough context to act on** (who/what/why, not just "fix").
- **A `Usage:` line in an executable script's module docstring** (invocation,
  expected exit codes). A script's interface is not restatement of its code.

## CUT — AI over-production (delete, or never write)

- **Docstrings that restate the signature.** `add(a, b)` → *"Returns the sum of
  a and b."* Adds nothing. Delete or reduce to nothing.
- **Comments that narrate the next line.** `# increment the counter` above
  `counter += 1`. `# loop over items` above `for item in items:`.
- **Boilerplate `Args:`/`Returns:`/`Raises:` blocks** where names + type hints
  already say it — especially on private helpers (`_name`). Type annotations are
  the contract; don't duplicate them in prose.
- **`__init__` docstrings that say "Initializes the class"** or list every field
  already visible in the signature.
- **Section-header comments inside short functions** (`# --- validation ---`,
  `# setup`). If a function needs signposting, it wants splitting, not comments.
- **Multi-paragraph essays on internal/private modules.** A one-liner is plenty.
- **Restating a well-named variable/function in a comment.**
  `total_capital  # the total capital`.
- **Commented-out code and "changelog" comments** ("# changed on ...", "# was:").
  Version control holds that.

## Docstring sizing

- Default to **one line**. Add a body only when a caller would otherwise get it
  wrong.
- Prefer a **clearer name over a comment.** Rename `d` → `elapsed_seconds`
  instead of writing `# d is elapsed seconds`.
- Trivial private helper with clear name + type hints → **no docstring**.
- Don't document parameters whose meaning is obvious from name + type. Document
  only the ones with a non-obvious contract (allowed range, unit, ownership).

## Before / after

```python
# OVER-DOCUMENTED (AI default)
def calculate_mid(bid: float, ask: float) -> float:
    """Calculate the mid price.

    Args:
        bid: The bid price.
        ask: The ask price.
    Returns:
        The mid price as a float.
    """
    # add bid and ask and divide by two
    return (bid + ask) / 2

# LEAN
def calculate_mid(bid: float, ask: float) -> float:
    """Mid price. System-wide pricing invariant: never use last/close."""
    return (bid + ask) / 2
```

The kept line survives because *"never use last/close"* is a constraint the
signature can't express. Everything else was restatement.

## Respect project overrides (do not strip mandated docs)

Some projects require docstrings on certain surfaces (e.g. a project `CLAUDE.md`
stating *"Public methods MUST have documentation"*; Black-Scholes math notes are
intentional). When a project or style guide mandates docs on a surface:

- **Keep a minimal one-line docstring — never remove it.** Trim it to lean, do
  not delete it.
- Preserve domain notes the project marks as intentional (math notation,
  invariant references).

When in doubt about a public API, keep the one-liner. The discipline cuts
*redundancy*, never *required* documentation.

## Quick decision

```
About to write a doc line?
  Public surface with a one-line summary?      → keep it, one line
  Does it explain WHY / a constraint / a ref?  → keep it
  Would a code-literate reader already know it? → delete it
  Restates the signature or the next line?      → delete it
  Could a better name replace it?               → rename instead
```
