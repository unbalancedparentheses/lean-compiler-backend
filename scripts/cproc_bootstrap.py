#!/usr/bin/env python3
"""Compile the pinned cproc frontend through identical LCB/QBE IR and test it.

Uses the ARM64 Linux container and pinned sources of cjson_benchmark.py. The
stage-one frontend is GCC-built. All 18 frontend translation units are compiled
by each backend, then linked with GCC/libc. Stage-two frontends must reproduce
stage-one IR byte-for-byte and pass cproc's original tests. No source/IR patches.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import time
from cjson_benchmark import ROOT, CPROC, CJSON, DEFINES, command, fetch

SOURCES = 'attr decl eval expr init main map pp scan scope stmt targ token tree type utf util qbe'.split()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--report', type=Path)
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    args = ap.parse_args()
    base = ROOT / '.build/linux-arm64'
    work = base / 'cproc-bootstrap'
    work.mkdir(parents=True, exist_ok=True)
    cproc, cjson = base/'cjson-benchmark/cproc', base/'cjson-benchmark/cJSON'
    fetch(cproc, 'https://github.com/michaelforney/cproc.git', CPROC)
    fetch(cjson, 'https://github.com/DaveGamble/cJSON.git', CJSON)

    def inside(path): return '/work/' + str(Path(path).relative_to(base))
    def docker(cmd, cwd=None, check=True):
        return command(['docker', 'exec', *(['-w', inside(cwd)] if cwd else []), args.docker_container, *cmd], timeout=600, check=check)
    assert docker(['uname', '-m']).stdout.strip() == 'aarch64'

    def synchronize(path, to_guest=True):
        expected = hashlib.sha256(path.read_bytes()).hexdigest() if to_guest else docker(['sha256sum', inside(path)]).stdout.split()[0]
        if to_guest:
            with path.open('rb') as stream: os.fsync(stream.fileno())
        for _ in range(100):
            actual = docker(['sha256sum', inside(path)]).stdout.split()[0] if to_guest else hashlib.sha256(path.read_bytes()).hexdigest()
            if actual == expected: return
            time.sleep(0.05)
        raise AssertionError(f'shared-file digest did not synchronize: {path}')

    docker(['./configure'], cproc)
    docker(['make', '-j4'], cproc)
    qbesrc = work/'qbe-host'
    if not qbesrc.exists(): shutil.copytree(ROOT/'third_party/qbe', qbesrc)
    command(['make', 'clean'], cwd=qbesrc)
    command(['make', '-j4', f'CC={os.environ.get("LCB_CC", "cc")}', 'CFLAGS=-std=c99 -O2'], cwd=qbesrc)
    corrected = work/'qbe-corrected'
    if not corrected.exists(): shutil.copytree(ROOT/'third_party/qbe', corrected)
    patch_path = ROOT/'tests/upstream/qbe-1.3-arm64-extern-offset.json'
    patch = json.loads(patch_path.read_text())
    source_path = ROOT/'third_party/qbe'/patch['source']
    lock = json.loads((ROOT/'upstream-lock.json').read_text())
    assert hashlib.sha256(source_path.read_bytes()).hexdigest() == lock['vendored_files'][str(source_path.relative_to(ROOT))]
    original = source_path.read_text()
    assert original.count(patch['before']) == 1
    (corrected/patch['source']).write_text(original.replace(patch['before'], patch['after']))
    command(['make', 'clean'], cwd=corrected)
    command(['make', '-j4', f'CC={os.environ.get("LCB_CC", "cc")}', 'CFLAGS=-std=c99 -O2'], cwd=corrected)
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler, compiler)
    report = {'schema': 1, 'program': 'cproc frontend self-compilation', 'cproc_commit': CPROC,
              'cjson_commit': CJSON, 'compiler_identity': command([compiler, '--build-identity']).stdout.strip(),
              'qbe_version': '1.3 (repository pinned source)', 'qbe_build_flags': '-std=c99 -O2',
              'target': 'aarch64-linux', 'compile_host': platform.platform(),
              'execution': docker(['uname', '-a']).stdout.strip(), 'translation_units': {}, 'backends': {},
              'oracle_patch_sha256': hashlib.sha256(patch_path.read_bytes()).hexdigest(),
              'notes': ['Unmodified pinned program sources and identical stage-one IR for all backends.',
                        'Original QBE results are retained separately from the test-only external-GOT-offset correction.',
                        'Stage-one frontend uses GCC; GCC links stage-two frontend objects with system libc.',
                        'Backend compile times exclude preprocessing, assembler and linker.',
                        'Successful stage-two frontends reproduce all frontend source units and cJSON byte-for-byte.',
                        'Original cproc tests compare IR, preprocessing and diagnostic outputs.']}
    regression_ir, regression_c = work/'extern-offset.ssa', work/'extern-offset.c'
    for dest, suffix in [(regression_ir, '.ssa'), (regression_c, '.c')]:
        shutil.copy2(ROOT/('tests/regressions/qbe-arm64-extern-offset'+suffix), dest)
        synchronize(dest)
    report['extern_offset_regression'] = {}
    for label in ['baseline', 'optimized', 'qbe', 'qbe-corrected']:
        asm, exe = work/f'extern-offset-{label}.s', work/f'extern-offset-{label}'
        backend = corrected if label == 'qbe-corrected' else qbesrc
        cmd = ([backend/'qbe', '-t', 'arm64', '-o', asm, regression_ir] if label.startswith('qbe') else
               [compiler, regression_ir, '--target', 'aarch64-linux', *(['--optimize'] if label == 'optimized' else []), '-o', asm])
        command(cmd)
        synchronize(asm)
        docker(['gcc', inside(regression_c), inside(asm), '-o', inside(exe)])
        result = docker([inside(exe)], check=False)
        assert result.returncode == (1 if label == 'qbe' else 0), (label, result.returncode, 're-audit upstream discrepancy')
        report['extern_offset_regression'][label] = {'exit': result.returncode, 'matches_c_pointer': result.returncode == 0}
    print('external GOT offset: Lean baseline/optimized and corrected oracle pass; original QBE returns the wrong pointer', flush=True)
    inputs = []
    for name in [*SOURCES, 'cJSON']:
        source = cjson/'cJSON.c' if name == 'cJSON' else cproc/f'{name}.c'
        preprocessed, ir = work/f'{name}.i', work/f'{name}.ssa'
        docker([inside(cproc/'cproc'), *DEFINES, '-E', inside(source), '-o', inside(preprocessed)])
        docker([inside(cproc/'cproc-qbe'), '-t', 'aarch64', '-o', inside(ir), inside(preprocessed)])
        synchronize(ir, False)
        inputs.append((name, preprocessed, ir))
        if name != 'cJSON':
            text = ir.read_text()
            report['translation_units'][name] = {'sha256': hashlib.sha256(ir.read_bytes()).hexdigest(),
                'bytes': len(ir.read_bytes()), 'lines': len(text.splitlines()),
                'functions': len(re.findall(r'^(?:export )?function\b', text, re.M))}
    for label in ['baseline', 'optimized', 'qbe', 'qbe-corrected']:
        objects, timings = [], {}
        for name, _, ir in inputs[:-1]:
            asm, obj = work/f'{name}-{label}.s', work/f'{name}-{label}.o'
            backend = corrected if label == 'qbe-corrected' else qbesrc
            cmd = ([backend/'qbe', '-t', 'arm64', '-o', asm, ir] if label.startswith('qbe') else
                   [compiler, ir, '--target', 'aarch64-linux', *(['--optimize'] if label == 'optimized' else []), '-o', asm])
            start = time.perf_counter()
            command(cmd)
            timings[name] = time.perf_counter() - start
            synchronize(asm)
            docker(['gcc', '-c', inside(asm), '-o', inside(obj)])
            objects.append(obj)
        exe = work/f'cproc-{label}'
        docker(['gcc', *map(inside, objects), '-o', inside(exe)])
        reproduced = {}
        failure = None
        for name, preprocessed, ir in inputs:
            output = work/f'{name}-stage2-{label}.ssa'
            result = docker([inside(exe), '-t', 'aarch64', '-o', inside(output), inside(preprocessed)], check=False)
            if result.returncode:
                assert label == 'qbe', (label, name, result.returncode, result.stderr)
                failure = {'input': name, 'exit': result.returncode, 'stderr': result.stderr}
                break
            synchronize(output, False)
            assert output.read_bytes() == ir.read_bytes(), (label, name, 'stage-two IR mismatch')
            reproduced[name] = hashlib.sha256(output.read_bytes()).hexdigest()
        if failure:
            report['backends'][label] = {'compile_seconds': timings, 'total_compile_seconds': sum(timings.values()),
                'executable_bytes': exe.stat().st_size, 'reproduced_ir': reproduced, 'failure': failure,
                'upstream_tests_passed': None, 'upstream_tests_total': None}
            print(f'cproc {label}: original compiler fails on {failure["input"]} with exit {failure["exit"]}; retained as a failure', flush=True)
            continue
        result = docker(['env', 'CCQBE='+inside(exe), './runtests'], cproc)
        (work/f'tests-{label}.log').write_text(result.stdout+result.stderr)
        matched = re.search(r'(\d+)/(\d+) tests passed', result.stdout)
        assert matched and matched[1] == matched[2], result.stdout
        report['backends'][label] = {'compile_seconds': timings, 'total_compile_seconds': sum(timings.values()),
            'executable_bytes': exe.stat().st_size, 'size': docker(['size', inside(exe)]).stdout.strip(),
            'reproduced_ir': reproduced, 'upstream_tests_passed': int(matched[1]), 'upstream_tests_total': int(matched[2])}
        print(f'cproc {label}: 18 source units compiled; 19 stage-two IR files identical; {matched[1]}/{matched[2]} original tests passed', flush=True)
    path = args.report or work/'report.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2)+'\n')
    print(f'report: {path}', flush=True)


if __name__ == '__main__': main()
