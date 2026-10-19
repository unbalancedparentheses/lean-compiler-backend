#!/usr/bin/env python3
"""Audit whole pinned QBE SSA fixtures without rewriting or executing them.

Usage:
  python3 /private/tmp/lcb-upstream-fixture-audit.py \
    --root /private/tmp/lcb-integer-blits \
    --output /private/tmp/lcb-upstream-fixture-audit.json

Successful --check and assembly emission do not establish behavioral parity.
Rejection groups describe the first encountered blocker, not all features used.
"""

import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blocker(message):
    if "duplicate SSA definition" in message:
        return "SSA construction / repeated definitions"
    if "unsupported name" in message:
        return "QBE dot / numeric names"
    if "unsupported operand" in message:
        return "global symbol operand"
    match = re.search(r"near '([^']+)'", message)
    token = match.group(1) if match else "unknown"
    if "expected 'function'" in message:
        return "top-level " + token
    if "stack allocation outside" in message:
        return "nonentry stack allocation"
    if "unsupported type" in message:
        if token in {"s", "d"}:
            return "floating-point type"
        if token == "...":
            return "variadic signature / call"
        if token == "env":
            return "environment argument"
        return "unsupported type " + token
    return "other: " + message


def invoke(command, timeout):
    try:
        result = subprocess.run(command, text=True, capture_output=True, timeout=timeout)
        return {
            "exit": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired as error:
        return {
            "exit": None,
            "timeout": timeout,
            "stdout": (error.stdout or b"").decode() if isinstance(error.stdout, bytes) else error.stdout or "",
            "stderr": (error.stderr or b"").decode() if isinstance(error.stderr, bytes) else error.stderr or "",
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/private/tmp/lcb-integer-blits"))
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--output", type=Path, default=Path("/private/tmp/lcb-upstream-fixture-audit.json"))
    parser.add_argument("--timeout", type=float, default=20)
    args = parser.parse_args()
    root = args.root.resolve()
    binary = (args.binary or root / ".lake/build/bin/lcb").resolve()
    files = sorted((root / "third_party/qbe/test").glob("*.ssa"))
    if not files:
        parser.error("no pinned third_party/qbe/test/*.ssa fixtures found")
    records = []
    for file in files:
        check = invoke([str(binary), "--check", str(file)], args.timeout)
        record = {
            "path": str(file.relative_to(root)),
            "sha256": digest(file.read_bytes()),
            "check_exit": check["exit"],
            "check_stdout": check["stdout"].strip(),
            "check_stderr": check["stderr"].strip(),
            "native_execution": "not run",
        }
        if "timeout" in check:
            record["check_timeout"] = check["timeout"]
        if check["exit"] == 0:
            emit = invoke([str(binary), str(file)], args.timeout)
            record.update(
                emit_exit=emit["exit"],
                emit_stderr=emit["stderr"].strip(),
                emitted_lines=len(emit["stdout"].splitlines()),
                emitted_sha256=digest(emit["stdout"].encode()),
            )
            if "timeout" in emit:
                record["emit_timeout"] = emit["timeout"]
        else:
            record["first_blocker"] = blocker(record["check_stderr"])
            # The current CLI labels validation failures with function $NAME.
            record["rejection_stage"] = (
                "admission" if re.search(r"function \$[A-Za-z_][A-Za-z0-9_]*:", record["check_stderr"])
                else "parsing" if "line " in record["check_stderr"]
                else "unclassified"
            )
        records.append(record)
    groups = collections.defaultdict(list)
    for record in records:
        if "first_blocker" in record:
            groups[record["first_blocker"]].append(record["path"])
    report = {
        "binary": str(binary),
        "binary_sha256": digest(binary.read_bytes()),
        "mode": "whole-fixture parsing/admission and assembly emission only; no assembly, linkage or execution",
        "scope_note": "First blocker categories can hide additional unsupported features in the same fixture.",
        "ssa_fixtures": len(records),
        "check_accepted": sum(record["check_exit"] == 0 for record in records),
        "emit_accepted": sum(record.get("emit_exit") == 0 for record in records),
        "rejection_stage_counts": dict(collections.Counter(record.get("rejection_stage") for record in records if record["check_exit"] != 0)),
        "first_blockers": dict(sorted(groups.items())),
        "fixtures": records,
    }
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{len(records)} pinned SSA fixtures: {report['check_accepted']} accepted by --check; {report['emit_accepted']} emitted assembly")
    print("No assembly, linkage or native execution performed.")
    for category, paths in sorted(groups.items(), key=lambda item: (-len(item[1]), item[0])):
        print(f"{len(paths):2} first blocked by {category}: " + ", ".join(Path(path).name for path in paths))
    print(f"Report: {args.output}")


if __name__ == "__main__":
    main()
