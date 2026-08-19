#!/usr/bin/env python3
"""Guards the xsecurity helper scripts' destructive and lossy paths.

Three of their functions call shutil.rmtree on a path derived from an argument,
fenced only by name checks; a regression there deletes a user's directory. The
rest of this file locks the two report products whose loss is silent: a render
refused over one field, and a JSONL record split across lines.

Usage: scripts/test-xsecurity-scripts.py   (exit 0 = pass)
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
SCRIPTS = REPO / "skills" / "xsecurity" / "scripts"
sys.path.insert(0, str(SCRIPTS))

import patch_artifacts as pa  # noqa: E402
import render_report as rr  # noqa: E402

# The separators json.dumps(ensure_ascii=False) leaves raw but str.splitlines() breaks on.
SEPARATORS = "before\u2028and\u2029after\u0085end"

failures: list[str] = []


def check(condition: object, message: str) -> None:
    if not condition:
        failures.append(message)


def test_deletion_fences() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        report = root / "XSECURITY-20260101-000000"
        # The one shape remove_workspace accepts.
        leaf = report / ".xsecurity-run" / "patch-20260101-000000" / "scratch-F1"
        (leaf / ".git").mkdir(parents=True)

        # Every deviation from the fenced layout must be refused, not deleted.
        refusals = {
            "wrong leaf name": leaf.parent / "scratch-nope",
            "no patch-<ts> parent": root / "loose" / "scratch-F1",
            "not under .xsecurity-run": report / "elsewhere" / "patch-1" / "scratch-F1",
        }
        for label, path in refusals.items():
            (path / ".git").mkdir(parents=True)
            check(pa.refuse_reason(str(path)) is not None, f"refuse_reason accepted {label}")
            try:
                pa.remove_workspace(str(path))
            except pa.PatchError:
                pass
            else:
                failures.append(f"remove_workspace deleted {label}")
            check(path.is_dir(), f"remove_workspace removed {label} despite refusing")

        # A scratch without its own .git is someone else's directory.
        bare = leaf.parent / "scratch-F2"
        bare.mkdir()
        check(pa.refuse_reason(str(bare)) is not None, "refuse_reason accepted a scratch with no .git")

        # The one accepted shape is deleted, and nothing above it is touched.
        check(pa.refuse_reason(str(leaf)) is None, "refuse_reason rejected the fenced layout")
        pa.remove_workspace(str(leaf))
        check(not leaf.exists(), "remove_workspace left the fenced scratch behind")
        check(leaf.parent.is_dir(), "remove_workspace removed the patch run dir too")

        # remove_patch_run only takes patch-<ts> inside .xsecurity-run.
        _, warnings = pa.remove_patch_run(str(root / "loose"))
        check(warnings and (root / "loose").is_dir(), "remove_patch_run deleted a non patch-<ts> dir")
        removed, _ = pa.remove_patch_run(str(leaf.parent))
        check(removed and not leaf.parent.exists(), "remove_patch_run left the fenced run dir behind")

        # remove_run_dir only takes a dir named .xsecurity-run.
        other = root / "not-a-run-dir"
        other.mkdir()
        rr.remove_run_dir(str(other), str(root))
        check(other.is_dir(), "remove_run_dir deleted a directory that is not .xsecurity-run")


def render(tmp: str, findings: list[dict[str, object]]) -> subprocess.CompletedProcess[str]:
    run = pathlib.Path(tmp) / ".xsecurity-run"
    run.mkdir()
    meta = {
        "scan_root": tmp,
        "mode": "scan",
        "scope": [],
        "effort": "medium",
        "revision": {"versioned": True, "commit": "a" * 40, "dirty": False},
    }
    (run / "scan-meta.json").write_text(json.dumps(meta))
    (run / "findings.json").write_text(json.dumps(findings))
    (run / "votes.json").write_text(
        json.dumps({
            "candidates": len(findings),
            "candidates_deduped": len(findings),
            "panel_votes": 3 * len(findings),
            "unreviewed_candidate_sites": 0,
            "rounds": {
                str(f["id"]): {"panel": {"true": 3, "false": 0, "voters": 3}} for f in findings
            },
        })
    )
    (run / "XSECURITY-RESULTS.md").write_text("# report\n")
    return subprocess.run(
        [sys.executable, str(SCRIPTS / "render_report.py"), str(run), "--products-dir", tmp],
        capture_output=True,
        text=True,
        check=False,
    )


def test_null_line_still_renders() -> None:
    """A finding with no line number must not cost the whole run its artifacts."""
    finding: dict[str, object] = {
        "id": "F1",
        "title": "t",
        "file": "a.py",
        "line": None,
        "description": "d",
        "exploit_scenario": "e",
        "severity": "HIGH",
        "confidence": "high",
    }
    with tempfile.TemporaryDirectory() as tmp:
        done = render(tmp, [finding])
        check(done.returncode == 0, f'"line": null refused the render: {done.stderr.strip()}')
        out = pathlib.Path(tmp) / "XSECURITY-RESULTS.jsonl"
        check(out.is_file(), '"line": null wrote no XSECURITY-RESULTS.jsonl')
        if out.is_file():
            check(json.loads(out.read_text())["line"] == 0, '"line": null did not render as 0')


def test_jsonl_records_stay_on_one_line() -> None:
    """Both products are line-delimited; the exotic separators must not split a record."""
    one = rr.jsonl_line({"id": "F1", "description": SEPARATORS})
    check(len(one.splitlines()) == 1, "render_report split a record across lines")

    unit = pa.build_unit(
        {"id": "F1", "status": "declined", "title": "t", "decline_reason": SEPARATORS}, 0
    )
    rows = pa.jsonl([unit], "a" * 40, {"F1": None}, {})
    check(len(rows.splitlines()) == 1, "patch_artifacts split a record across lines")
    check(json.loads(rows)["decline_reason"] == SEPARATORS, "patch_artifacts lost the record's text")


for test in (
    test_deletion_fences,
    test_null_line_still_renders,
    test_jsonl_records_stay_on_one_line,
):
    test()
    if not failures:
        print(f"PASS: {test.__name__}")

if failures:
    for failure in failures:
        sys.stderr.write(f"FAIL: {failure}\n")
    sys.exit(1)
