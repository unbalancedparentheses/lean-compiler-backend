#!/usr/bin/env python3
"""Run admitted original QBE fixtures with the retained upstream shell harness.

The only shell-harness change is its fixed temporary prefix, isolated per
fixture/backend. Original driver/output blocks and fixture sources are untouched.
Both compiler adapters implement QBE's -t? query; compilation uses Apple ARM64.
Six accepted underscore fixtures lack an original driver and exported main, so
they receive object-only checks and are explicitly not executed.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess


def sha(data):
    return hashlib.sha256(data).hexdigest()


def run(command, *, cwd, env, timeout=120):
    try:
        result = subprocess.run(list(map(str, command)), cwd=cwd, env=env,
                                capture_output=True, text=True, timeout=timeout)
        return {"command": list(map(str, command)), "exit": result.returncode,
                "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode(errors="replace") if isinstance(value, bytes) else value or ""
        return {"command": list(map(str, command)), "exit": None, "timeout": timeout,
                "stdout": decode(error.stdout), "stderr": decode(error.stderr)}


def executable(path, contents):
    path.write_text(contents)
    path.chmod(0o755)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/private/tmp/lcb-integer-blits"))
    parser.add_argument("--admission-report", type=Path, default=Path("/private/tmp/lcb-upstream-fixture-audit.json"))
    parser.add_argument("--work", type=Path)
    args = parser.parse_args()
    assert platform.system() == "Darwin" and platform.machine() == "arm64", "native Apple ARM64 required"
    root = args.root.resolve()
    binary = root / ".lake/build/bin/lcb"
    cc = os.environ.get("LCB_CC")
    assert cc and cc.startswith("/nix/store/"), "run inside the pinned Nix shell with LCB_CC"
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    work = args.work or Path("/private/tmp") / ("lcb-upstream-native-" + timestamp)
    work.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    toolbin = work / "toolbin"
    toolbin.mkdir()
    executable(toolbin / "cc", "#!/bin/sh\nexec " + shlex.quote(cc) + ' "$@"\n')
    env["PATH"] = str(toolbin) + os.pathsep + env["PATH"]
    oracle = work / "qbe-original"
    shutil.copytree(root / "third_party/qbe", oracle)
    baseline_build = run(["make", "-j2", "CC=" + cc], cwd=oracle, env=env)
    (work / "qbe-build.json").write_text(json.dumps(baseline_build, indent=2) + "\n")
    assert baseline_build["exit"] == 0, f"original QBE build failed: {work / 'qbe-build.json'}"
    adapters = {}
    for name, compiler in [("qbe", oracle / "qbe"), ("lcb", binary)]:
        adapter = work / (name + "-adapter")
        arguments = ' -t arm64_apple' if name == "qbe" else ''
        reorder = '' if name == "qbe" else ('if [ "$#" = 3 ] && [ "$1" = "-o" ]; then\n'
                    '  exec ' + shlex.quote(str(compiler)) + ' "$3" -o "$2"\nfi\n')
        adapters[name] = executable(adapter, '#!/bin/sh\nif [ "$#" = 1 ] && [ "$1" = "-t?" ]; then\n  echo arm64_apple\n  exit 0\nfi\n' + reorder + 'exec ' + shlex.quote(str(compiler)) + arguments + ' "$@"\n')
    source_harness = (root / "third_party/qbe/tools/test.sh").read_text()
    assert source_harness.count("tmp=/tmp/qbe.zzzz") == 1
    admission = json.loads(args.admission_report.read_text())
    accepted = [record for record in admission["fixtures"] if record["check_exit"] == 0]
    records = []
    for row in accepted:
        fixture = root / row["path"]
        source = fixture.read_text()
        has_driver = bool(re.search(r"^# >>> driver\s*$", source, re.M))
        has_main = bool(re.search(r"\bexport\s+function(?:\s+[wl])?\s+\$main\s*\(", source))
        record = {"path": row["path"], "fixture_sha256": sha(fixture.read_bytes()),
                  "has_original_driver": has_driver, "has_exported_main": has_main,
                  "native_eligible": has_driver or has_main, "backends": {}}
        records.append(record)
    # Establish all original QBE results before running any LCB native harness.
    for backend in ["qbe", "lcb"]:
        for record in records:
            fixture = root / record["path"]
            directory = work / backend / fixture.stem
            directory.mkdir(parents=True)
            if record["native_eligible"]:
                harness = directory / "upstream-test-isolated.sh"
                harness.write_text(source_harness.replace("tmp=/tmp/qbe.zzzz", "tmp=" + shlex.quote(str(directory / "qbe"))))
                harness_env = env.copy()
                harness_env.update(bin=str(adapters[backend]), binref=str(directory / "no-reference"))
                result = run(["sh", harness, fixture], cwd=directory, env=harness_env, timeout=60)
                result["qualification"] = "original upstream driver/output contract"
                expected = directory / "qbe.out"
                result["expected_output"] = expected.read_text() if expected.exists() else None
                exe = directory / "qbe.exe"
                if exe.exists() and result["exit"] == 0:
                    execution = run([exe, "a", "b", "c"], cwd=directory, env=env, timeout=30)
                    result["captured_execution"] = execution
                    if result["expected_output"]:
                        result["captured_output_matches"] = execution["stdout"].replace("\r", "") == result["expected_output"]
                        result["pass_criterion"] = "normalized stdout exactly matches original expected output; upstream harness ignores program exit for output fixtures"
                    else:
                        result["captured_exit_matches"] = execution["exit"] == 0
                        result["pass_criterion"] = "program exits zero"
                print(f"{backend:3} {fixture.name:18} native harness exit={result['exit']}", flush=True)
            else:
                assembly = directory / "fixture.s"
                result = run([adapters[backend], "-o", assembly, fixture], cwd=directory, env=env)
                result["qualification"] = "object only; original fixture has no driver or exported main"
                if result["exit"] == 0:
                    result["object_compile"] = run([cc, "-c", assembly, "-o", directory / "fixture.o"], cwd=directory, env=env)
                print(f"{backend:3} {fixture.name:18} object only", flush=True)
            record["backends"][backend] = result
            (directory / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    versions = {"clang": run([cc, "--version"], cwd=work, env=env),
                "qbe": run([oracle / "qbe", "-h"], cwd=work, env=env),
                "lcb": run([binary, "--version"], cwd=work, env=env),
                "shell": run(["sh", "--version"], cwd=work, env=env)}
    summary = {}
    for backend in ["qbe", "lcb"]:
        eligible = [row for row in records if row["native_eligible"]]
        successful = [row for row in eligible if row["backends"][backend]["exit"] == 0]
        summary[backend] = {
            "native_eligible": len(eligible), "upstream_harness_passed": len(successful),
            "harness_failures": [row["path"] for row in eligible if row["backends"][backend]["exit"] != 0],
            "no_original_executable_harness": [row["path"] for row in records if not row["native_eligible"]],
            "object_only_compiled": sum(not row["native_eligible"] and row["backends"][backend].get("object_compile", {}).get("exit") == 0 for row in records),
        }
    report = {"work": str(work), "platform": platform.platform(), "machine": platform.machine(),
              "binary_sha256": sha(binary.read_bytes()), "compiler": cc,
              "original_harness_sha256": sha(source_harness.encode()), "harness_modification": "only per-run temporary prefix",
              "versions": versions, "summary": summary, "fixtures": records}
    (work / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    Path("/private/tmp/lcb-upstream-native-latest.txt").write_text(str(work / "report.json") + "\n")
    print(json.dumps(summary, indent=2))
    print("REPORT", work / "report.json")


if __name__ == "__main__":
    main()
