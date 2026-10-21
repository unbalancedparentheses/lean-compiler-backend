#!/usr/bin/env python3
"""Qualify macOS AMD64 natively or through explicitly labelled Rosetta execution."""
import argparse
import json
import os
import shlex
from pathlib import Path
import platform
import shutil
import subprocess
from fuzz import ROOT, LCB
from upstream_suite import extract


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-execution', action='store_true')
    ap.add_argument('--optimize', action='store_true')
    ap.add_argument('--compiler', type=Path, default=LCB)
    args = ap.parse_args()
    work = ROOT/'.build/macos-x86'
    if args.optimize:
        work = work/'optimized'
    work.mkdir(parents=True, exist_ok=True)
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler, compiler)
    def run(command, inside=False):
        command = list(map(str, command))
        if args.optimize and command[0] == str(compiler) and len(command) > 1 and not command[1].startswith('--'):
            command += ['--optimize']
        return subprocess.run(command, text=True, capture_output=True, timeout=120)
    darwin = platform.system() == 'Darwin'
    native = darwin and platform.machine() == 'x86_64'
    execute = native or (darwin and run(['/usr/bin/arch', '-x86_64', '/usr/bin/true']).returncode == 0)
    if args.require_execution:
        assert execute, 'macOS x86-64 execution unavailable'
    host_cc = os.environ.get('LCB_CC', 'cc')
    cc = work/'cc'
    cc.write_text(f'#!/bin/sh\nexec {shlex.quote(host_cc)} -arch x86_64 "$@"\n')
    cc.chmod(0o755)
    qbe = work/'oracle/qbe'
    if execute:
        if not qbe.parent.exists():
            shutil.copytree(ROOT/'third_party/qbe', qbe.parent)
        result = run(['make', '-C', qbe.parent, '-j2', f'CC={host_cc}'])
        assert result.returncode == 0, result.stderr
    rows, failures = [], []
    for fixture in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
        case = work/fixture.stem
        case.mkdir(exist_ok=True)
        assembly = case/'lean.s'
        result = run([compiler, fixture, '--target', 'x86_64-macos', '-o', assembly])
        row = {'fixture': fixture.name, 'emitted': result.returncode == 0, 'diagnostic': result.stderr.strip(), 'execution': 'unmeasured'}
        rows.append(row)
        if result.returncode:
            if fixture.name != 'dark.ssa':
                failures.append((fixture.name, 'unexpected rejection', result.stderr))
            continue
        if not execute:
            continue
        qasm = case/'qbe.s'
        result = run([qbe, '-t', 'amd64_apple', '-o', qasm, fixture])
        assert result.returncode == 0, result.stderr
        driver, expected = extract(fixture.read_text(), 'driver'), extract(fixture.read_text(), 'output')
        caller = case/'driver.c'
        caller.write_text(driver)
        statuses = []
        for label, asm in [('lean', assembly), ('qbe', qasm)]:
            exe = case/label
            private = fixture.name.startswith('_')
            command = [cc, '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int']
            command += ['-c', asm, '-o', exe] if private else ([caller, asm, '-o', exe] if driver else [asm, '-o', exe])
            result = run(command)
            if result.returncode:
                failures.append((fixture.name, label+' assembly/link', result.stderr))
                statuses.append('failed')
                continue
            if private:
                statuses.append('assembled')
                continue
            result = run([exe, 'a', 'b', 'c'])
            passed = (result.returncode >= 0 and result.stdout.replace('\r', '') == expected) if expected else result.returncode == 0
            statuses.append('passed' if passed else 'failed')
            if not passed:
                failures.append((fixture.name, label+' execution', result.returncode, result.stdout, result.stderr))
        row['execution'] = statuses[0] if len(set(statuses)) == 1 else 'failed'
    # Always retain/report original fixture failures before extended qualification.
    mode = 'native' if native else ('rosetta' if execute else 'not measured')
    report = {'target': 'x86_64-macos', 'optimized': args.optimize, 'compiler_identity': run([compiler, '--build-identity']).stdout.strip(), 'execution_mode': mode, 'fixtures': rows, 'failures': failures}
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'macOS AMD64: {sum(x["emitted"] for x in rows)}/76 emitted; {sum(x["execution"] == "passed" for x in rows)} executable and {sum(x["execution"] == "assembled" for x in rows)} assembly-only passes; execution={mode}', flush=True)
    for failure in failures:
        print(str(failure)[:3000], flush=True)
    assert not failures, f'{len(failures)} target failures'
    if execute:
        from target_scalar import exercise as scalar
        from target_aggregate import exercise as aggregate
        from target_tls import exercise as tls
        scalar(compiler, work, run, cc, qbe, 'x86_64-macos', 'amd64_apple', 24)
        aggregate(compiler, work, run, cc, qbe, 'x86_64-macos', 'amd64_apple')
        tls(compiler, work, run, cc, 'x86_64-macos')
        from macho_objects import exercise as objects
        objects(compiler, work, run, cc, qbe, 'x86_64-macos', 'amd64_apple')
    from quoted_names import exercise as quoted
    from zero_alloc import exercise as zero
    from memory_promotion import exercise as memory_tests
    memory_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from allocation import exercise as allocation_tests
    allocation_tests(compiler, work, run, cc, 'x86_64-macos', execute)
    from control_flow import exercise as cfg
    from module_scale import exercise as modules
    quoted(compiler, work, run, cc, qbe, 'x86_64-macos', 'amd64_apple', execute)
    zero(compiler, work, run, cc, qbe, 'x86_64-macos', 'amd64_apple', execute)
    cfg(compiler, work, run, cc, 'x86_64-macos', execute, optimized_only=args.optimize)
    modules(compiler, work, run, cc, 'x86_64-macos', execute)
    if not args.optimize:
        from constant_fold import exercise as fold
        fold(compiler, work, run, cc, 'x86_64-macos', execute)


if __name__ == '__main__':
    main()
