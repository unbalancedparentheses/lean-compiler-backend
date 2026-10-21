#!/usr/bin/env python3
"""Inventory all pinned SSA fixtures and qualify every accepted runnable test.

Underscore-prefixed upstream development fixtures are assemble-only, matching the
upstream runner's exclusion from its executable suite. Unsupported inputs stay
explicitly reported; they never count as passes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host

BASELINE = ROOT/'tests/upstream-coverage.json'


def extract(text, section):
    lines, active = [], False
    for line in text.splitlines():
        if line.startswith(f'# >>> {section}'):
            active = True
        elif line.startswith('# <<<'):
            active = False
        elif active:
            assert line.startswith('#'), 'malformed upstream fixture section'
            content = line[2:] if line.startswith('# ') else line[1:]
            # Match tools/test.sh: a final # protects significant trailing spaces.
            lines.append(content[:-1] if content.endswith('#') else content)
    return '\n'.join(lines) + ('\n' if lines else '')


def command(args, cwd=ROOT, timeout=120):
    return subprocess.run([str(a) for a in args], cwd=cwd, text=True,
                          capture_output=True, timeout=timeout)


def main():
    assert extract('# >>> output\n#  *  #\n# <<<\n', 'output') == ' *  \n'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=0)
    parser.add_argument('--write-baseline', action='store_true')
    parser.add_argument('--report', type=Path, default=ROOT/'.build/upstream-suite.json')
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    rows, failures = [], []
    with tempfile.TemporaryDirectory(prefix='lcb-upstream-') as directory:
        work = Path(directory)
        compiler = work/'lcb-snapshot'
        shutil.copy2(LCB, compiler)
        cc = os.environ.get('LCB_CC', 'clang')
        qbe = None
        if native_host():
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qbe = oracle/'qbe'
        for source in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
            text = source.read_text()
            case = work/source.stem
            case.mkdir()
            asm = case/'lean.s'
            result = command([compiler, source, '-o', asm])
            row = {'fixture': source.name, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'emitted': result.returncode == 0, 'diagnostic': result.stderr.strip(),
                   'native': 'unsupported' if result.returncode else 'not measured'}
            rows.append(row)
            if result.returncode or not qbe:
                continue
            if 'skip' in text.splitlines()[0] and 'arm64_apple' in text.splitlines()[0]:
                row['native'] = 'upstream target skip'
                continue
            qasm = case/'qbe.s'
            result = command([qbe, '-t', 'arm64_apple', '-o', qasm, source])
            if result.returncode:
                row['native'] = 'QBE rejected'
                failures.append((source.name, result.stderr))
                continue
            driver = extract(text, 'driver')
            expected = extract(text, 'output')
            cfile = case/'driver.c'
            cfile.write_text(driver)
            row['backends'] = {}
            for backend, assembly in [('lean', asm), ('qbe', qasm)]:
                executable = case/backend
                private = source.name.startswith('_')
                args = [cc, '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int']
                args += ['-c', assembly, '-o', executable] if private else (
                    [cfile, assembly, '-o', executable] if driver else [assembly, '-o', executable])
                result = command(args)
                if result.returncode:
                    status = 'assembler/linker failure'
                    failures.append((source.name, backend + ': ' + result.stderr))
                elif private:
                    status = 'assembled only'
                else:
                    try:
                        result = command([executable, 'a', 'b', 'c'], timeout=30)
                        # Upstream output fixtures check stdout, including void-main tests.
                        passed = (result.returncode >= 0 and result.stdout.replace('\r', '') == expected) if expected else result.returncode == 0
                        status = 'passed' if passed else 'execution mismatch'
                        if not passed:
                            failures.append((source.name, f'{backend}: exit {result.returncode}; stdout={result.stdout!r}; expected={expected!r}; stderr={result.stderr}'))
                    except subprocess.TimeoutExpired:
                        status = 'timeout'
                        failures.append((source.name, backend + ': exceeded 30 seconds'))
                row['backends'][backend] = status
            row['native'] = 'passed' if all(v == 'passed' for v in row['backends'].values()) else (
                'assembled only' if all(v == 'assembled only' for v in row['backends'].values()) else 'failed')
            if row['native'] == 'failed':
                retained = ROOT/'.build/upstream-failures'/source.stem
                retained.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, retained/source.name)
                for artifact in [asm, qasm, cfile]:
                    shutil.copy2(artifact, retained/artifact.name)
        emitted = sorted(row['fixture'] for row in rows if row['emitted'])
        if BASELINE.exists():
            baseline = json.loads(BASELINE.read_text())['emitted']
            for missing in sorted(set(baseline) - set(emitted)):
                failures.append((missing, 'regressed from emitted baseline'))
        if options.write_baseline and not failures:
            BASELINE.write_text(json.dumps({'target': 'aarch64-macos', 'emitted': emitted}, indent=2)+'\n')
        report = {'target': 'aarch64-macos', 'compiler_identity': run([compiler, '--build-identity']).strip(),
                  'native_measured': native_host(), 'fixtures': rows, 'failures': failures}
        options.report.parent.mkdir(parents=True, exist_ok=True)
        options.report.write_text(json.dumps(report, indent=2)+'\n')
    native = sum(row['native'] == 'passed' for row in rows)
    assembled = sum(row['native'] == 'assembled only' for row in rows)
    print(f'upstream suite: {len(emitted)}/{len(rows)} emitted; {len(rows)-len(emitted)} unsupported; '
          f'{native} native passes per Lean/QBE backend, {assembled} development fixtures assembled only')
    for name, failure in failures:
        print(f'FAIL {name}: {failure}')
    assert not failures, f'{len(failures)} upstream failures; report: {options.report}'


if __name__ == '__main__':
    main()
