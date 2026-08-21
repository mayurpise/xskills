#!/usr/bin/env python3
"""Locks skill prose to the tree: frontmatter, referenced paths, cross-skill names.

Three reviews in a row (2026-08-08, 2026-08-19, 2026-08-20) each hand-caught the
same defect class — a skill referencing a file, layout, or name that does not
exist. For every skills/*/SKILL.md this asserts:
  (a) frontmatter exists, its name: matches the directory, description: non-empty;
  (b) every skill-relative path its markdown references resolves (against the
      skill dir, else the repo root);
  (c) every backticked cross-skill mention names a real skill directory or an
      allowlisted external;
  (d) xreview's dimension count is the same number in its table, its description,
      the README, and the site page.

Usage: scripts/test-skill-refs.py   (exit 0 = pass)
"""

from __future__ import annotations

import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SKILLS = REPO / "skills"

# Names a skill may reference without a skills/<name>/ directory existing here.
EXTERNAL_SKILLS: set[str] = set()

# A path reference carries a known dir prefix and a file extension. The lookbehind
# rejects matches inside a longer path (…/other-skill/jobs/x.md), which this
# repo does not ship and must not be asserted against.
PATH_REF = re.compile(
    r"(?<![/\w-])((?:rulesets|jobs|specs|scripts)/[A-Za-z0-9_.-]+\.(?:md|py|sh|js|lock))"
)
SKILL_DIR_REF = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/([A-Za-z0-9_./-]+)")
BRAND_CLAUDE = re.compile(r"claude", re.I)
SCRIPTS_REF = re.compile(r"\bSCRIPTS/([A-Za-z0-9_.-]+\.py)\b")
CROSS_SKILL = re.compile(r"`([a-z][a-z0-9-]+)` skill")

# xreview states its dimension count in four places; a8c389c exists only because
# one of them went stale when the table grew. Lock the number to the table.
DIMENSION_ROW = re.compile(r"^\|\s\*\*[^|]+\*\*\s\|.*\|\s`[a-z-]+`\s\|$", re.M)
DIMENSION_CLAIM = re.compile(r"\b(eight|nine|ten|eleven|twelve|thirteen)\s+dimensions\b")
NUMBER_WORDS = {8: "eight", 9: "nine", 10: "ten", 11: "eleven", 12: "twelve", 13: "thirteen"}

failures: list[str] = []


def check(condition: object, message: str) -> None:
    if not condition:
        failures.append(message)


def frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    body = text[4:].split("\n---", 1)[0]
    fields = {}
    for line in body.splitlines():
        m = re.match(r"^([A-Za-z-]+):\s*(.*)$", line)
        if m:
            fields[m.group(1)] = m.group(2).strip().strip("\"'")
    return fields


def check_dimension_count() -> None:
    """xreview's prose must quote the number of rows its dimension table actually has."""
    skill = SKILLS / "xreview" / "SKILL.md"
    if not skill.is_file():
        return
    rows = len(DIMENSION_ROW.findall(skill.read_text(encoding="utf-8")))
    expected = NUMBER_WORDS.get(rows)
    check(expected, f"xreview: dimension table has {rows} rows, outside the range this test words")
    if not expected:
        return
    for rel in ("skills/xreview/SKILL.md", "README.md", "docs/index.md"):
        path = REPO / rel
        if not path.is_file():  # docs/ is optional; the skill and README are not
            check(rel == "docs/index.md", f"{rel}: missing, cannot check the dimension count")
            continue
        claims = set(DIMENSION_CLAIM.findall(path.read_text(encoding="utf-8")))
        check(claims, f"{rel}: states no dimension count; the table has {rows}")
        check(
            claims <= {expected},
            f"{rel}: says {sorted(claims - {expected})} dimensions, table has {rows} ({expected})",
        )


def main() -> int:
    skill_dirs = sorted(d for d in SKILLS.iterdir() if (d / "SKILL.md").is_file())
    check(skill_dirs, f"no skills found under {SKILLS}")
    skill_names = {d.name for d in skill_dirs}

    for skill in skill_dirs:
        fm = frontmatter((skill / "SKILL.md").read_text(encoding="utf-8"))
        check(fm, f"{skill.name}: SKILL.md has no frontmatter")
        if fm:
            check(
                fm.get("name") == skill.name,
                f"{skill.name}: frontmatter name {fm.get('name')!r} != directory name",
            )
            check(fm.get("description"), f"{skill.name}: frontmatter description missing/empty")

        for md in sorted(skill.rglob("*.md")):
            text = md.read_text(encoding="utf-8")
            rel = md.relative_to(REPO)

            refs = set(PATH_REF.findall(text)) | set(SKILL_DIR_REF.findall(text))
            refs |= {f"scripts/{name}" for name in SCRIPTS_REF.findall(text)}
            for ref in sorted(refs):
                # A reference may name this skill's file, a repo-root file, or —
                # when one skill describes another's recipe — any skill's file.
                # Extensionless refs (a linked directory) resolve as dirs.
                candidates = [skill / ref, REPO / ref, *(d / ref for d in skill_dirs)]
                check(
                    any(c.is_file() or c.is_dir() for c in candidates),
                    f"{rel}: references {ref!r}, which resolves against neither "
                    f"{skill.relative_to(REPO)}/, the repo root, nor any skill dir",
                )

            for name in sorted(set(CROSS_SKILL.findall(text))):
                check(
                    name in skill_names or name in EXTERNAL_SKILLS,
                    f"{rel}: mentions `{name}` skill, but skills/{name}/ does not exist",
                )

        if skill.name == "xsecurity":
            for path in sorted(
                p
                for p in skill.rglob("*")
                if p.is_file() and p.suffix in {".md", ".py", ".sh", ".js", ".json"}
            ):
                body = path.read_text(encoding="utf-8")
                check(
                    not BRAND_CLAUDE.search(body),
                    f"{path.relative_to(REPO)}: xsecurity must not contain the 'claude' brand",
                )

    check_dimension_count()

    if failures:
        print(f"FAIL ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"PASS: {len(skill_dirs)} skills — frontmatter, path refs, cross-skill names, dimension count")
    return 0


if __name__ == "__main__":
    sys.exit(main())
