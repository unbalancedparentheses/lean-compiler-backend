#!/usr/bin/env python3
"""Compile the pinned cproc frontend through identical LCB/QBE IR and test it.

Uses the ARM64 Linux container and pinned sources of cjson_benchmark.py, with
QEMU user execution for the x86-64 and RV64 targets. The
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
from cjson_benchmark import ROOT, CPROC, CJSON, DEFINES, command as base_command, fetch

SOURCES = 'attr decl eval expr init main map pp scan scope stmt targ token tree type utf util qbe'.split()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--target', choices=['aarch64-linux','x86_64-linux','riscv64-linux'], default='aarch64-linux')
    ap.add_argument('--report', type=Path)
    ap.add_argument('--work', type=Path, help='Fresh empty directory beneath .build/linux-arm64; isolates all source/config/build files')
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    args = ap.parse_args()
    commands = []
    def command(argv, **kwargs):
        result = base_command(argv, **kwargs)
        commands.append({'command': list(map(str, argv)), 'cwd': str(kwargs.get('cwd', '')), 'exit': result.returncode,
                         'stdout': result.stdout, 'stderr': result.stderr})
        return result
    def digest(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    bound = {}
    def bind(path):
        path = Path(path).resolve()
        value = digest(path)
        assert str(path) not in bound or bound[str(path)] == value, ('bound file changed', path)
        bound[str(path)] = value
    bind(Path(__file__))
    bind(ROOT/'scripts/cjson_benchmark.py')
    bind(args.compiler)
    base = (ROOT / '.build/linux-arm64').resolve()
    arm = args.target == 'aarch64-linux'
    isa, frontend_target, qbe_target = {
        'aarch64-linux': ('aarch64','aarch64','arm64'),
        'x86_64-linux': ('x86_64','x86_64-sysv','amd64_sysv'),
        'riscv64-linux': ('riscv64','riscv64','rv64')}[args.target]
    cc = 'gcc' if arm else isa+'-linux-gnu-gcc'
    execution_prefix = [] if arm else ['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu']
    labels = ['baseline','optimized','qbe',*(['qbe-corrected'] if isa != 'x86_64' else [])]
    work = args.work.resolve() if args.work else base / ('cproc-bootstrap' if arm else 'cproc-bootstrap-'+isa)
    if args.work:
        assert work != base and work.is_relative_to(base), '--work must be beneath the mounted .build/linux-arm64 directory'
        assert not work.exists() or not any(work.iterdir()), '--work must be fresh and empty; preserve existing evidence'
    work.mkdir(parents=True, exist_ok=True)
    cproc = work/'cproc-source' if args.work or not arm else base/'cjson-benchmark/cproc'
    cjson = work/'cJSON-source' if args.work else base/'cjson-benchmark/cJSON'
    fetch(cproc, 'https://github.com/michaelforney/cproc.git', CPROC)
    fetch(cjson, 'https://github.com/DaveGamble/cJSON.git', CJSON)

    source_bindings = {}
    for source_root in [cproc, cjson]:
        names = command(['git', '-C', source_root, 'ls-files', '-z']).stdout.split('\0')
        for name in filter(None, names):
            path = source_root/name
            if path.is_file(): bind(path)
        source_bindings[str(source_root)] = command(['git','-C',source_root,'rev-parse','HEAD']).stdout.strip()

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

    configure = ['./configure']
    if not arm:
        libdir = str(Path(docker([cc,'-print-file-name=crtbegin.o']).stdout.strip()).parent)
        configure += ['--target='+isa+'-linux-gnu','--with-gcc-libdir='+libdir]
    docker(configure, cproc)
    docker(['make', '-j4'], cproc)
    for name in ['config.h','config.mk','cproc','cproc-qbe']:
        path = cproc/name
        if path.exists(): synchronize(path, False); bind(path)
    qbesrc = work/'qbe-host'
    if not qbesrc.exists(): shutil.copytree(ROOT/'third_party/qbe', qbesrc)
    command(['make', 'clean'], cwd=qbesrc)
    command(['make', '-j4', f'CC={os.environ.get("LCB_CC", "cc")}', 'CFLAGS=-std=c99 -O2'], cwd=qbesrc)
    corrected = work/'qbe-corrected'
    patch_path = None
    if isa != 'x86_64':
        if not corrected.exists(): shutil.copytree(ROOT/'third_party/qbe', corrected)
        patch_path = ROOT/('tests/upstream/qbe-1.3-'+('rv64' if isa == 'riscv64' else 'arm64')+'-extern-offset.json')
        patch = json.loads(patch_path.read_text())
        source_path = ROOT/'third_party/qbe'/patch['source']
        lock = json.loads((ROOT/'upstream-lock.json').read_text())
        assert hashlib.sha256(source_path.read_bytes()).hexdigest() == lock['vendored_files'][str(source_path.relative_to(ROOT))]
        original = source_path.read_text()
        assert original.count(patch['before']) == 1
        (corrected/patch['source']).write_text(original.replace(patch['before'], patch['after']))
        command(['make', 'clean'], cwd=corrected)
        command(['make', '-j4', f'CC={os.environ.get("LCB_CC", "cc")}', 'CFLAGS=-std=c99 -O2'], cwd=corrected)
    for source_root in [qbesrc, *([corrected] if isa != 'x86_64' else [])]:
        for path in source_root.rglob('*'):
            if path.is_file() and (path.suffix in ['.c','.h'] or path.name in ['Makefile','qbe']): bind(path)
    if patch_path: bind(patch_path)
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler, compiler)
    bind(compiler)
    report = {'schema': 1, 'program': 'cproc frontend self-compilation', 'cproc_commit': CPROC,
              'cjson_commit': CJSON, 'compiler_identity': command([compiler, '--build-identity']).stdout.strip(),
              'qbe_version': '1.3 (repository pinned source)', 'qbe_build_flags': '-std=c99 -O2',
              'target': args.target, 'execution_mode': 'native ARM64 Linux VM' if arm else 'QEMU user emulation',
              'frontend_defines': DEFINES, 'compile_host': platform.platform(),
              'execution': docker(['uname', '-a']).stdout.strip(), 'translation_units': {}, 'backends': {},
              'oracle_patch_sha256': hashlib.sha256(patch_path.read_bytes()).hexdigest() if isa != 'x86_64' else None,
              'notes': ['Unmodified pinned program sources and identical stage-one IR for all backends.',
                        *(['Original QBE results are retained separately from the test-only external-GOT-offset correction.'] if isa != 'x86_64' else []),
                        'Stage-one frontend uses GCC; GCC links stage-two frontend objects with system libc.',
                        'Backend compile seconds exclude preprocessing/assembly/linking and are diagnostic only under shared load; no performance comparison.',
                        'Successful stage-two frontends reproduce all frontend source units and cJSON byte-for-byte.',
                        'Original cproc tests compare IR, preprocessing and diagnostic outputs.']}
    regression_ir, regression_c = work/'extern-offset.ssa', work/'extern-offset.c'
    for dest, suffix in [(regression_ir, '.ssa'), (regression_c, '.c')]:
        shutil.copy2(ROOT/('tests/regressions/qbe-arm64-extern-offset'+suffix), dest)
        synchronize(dest)
        bind(dest)
    report['extern_offset_regression'] = {}
    for label in labels:
        asm, exe = work/f'extern-offset-{label}.s', work/f'extern-offset-{label}'
        backend = corrected if label == 'qbe-corrected' else qbesrc
        cmd = ([backend/'qbe', '-t', qbe_target, '-o', asm, regression_ir] if label.startswith('qbe') else
               [compiler, regression_ir, '--target', args.target, *(['--optimize'] if label == 'optimized' else []), '-o', asm])
        command(cmd)
        synchronize(asm)
        linked = docker([cc, inside(regression_c), inside(asm), '-o', inside(exe)], check=False)
        if isa == 'riscv64' and label == 'qbe':
            assert linked.returncode and "addend isn't allowed for R_RISCV_GOT_HI20" in linked.stderr, linked.stderr
            report['extern_offset_regression'][label] = {'link_exit': linked.returncode, 'link_stderr': linked.stderr, 'matches_c_pointer': False}
            continue
        assert linked.returncode == 0, linked.stderr
        result = docker([*execution_prefix, inside(exe)], check=False)
        assert result.returncode == (1 if arm and label == 'qbe' else 0), (label, result.returncode, 're-audit upstream discrepancy')
        report['extern_offset_regression'][label] = {'exit': result.returncode, 'matches_c_pointer': result.returncode == 0}
    print('external GOT offset: '+('Lean baseline/optimized and corrected oracle pass; original QBE returns the wrong pointer' if arm else ('original QBE GOT addend fails to link; Lean and corrected oracle pass' if isa == 'riscv64' else 'all backends match the C pointer')), flush=True)
    inputs = []
    for name in [*SOURCES, 'cJSON']:
        source = cjson/'cJSON.c' if name == 'cJSON' else cproc/f'{name}.c'
        preprocessed, ir = work/f'{name}.i', work/f'{name}.ssa'
        docker([inside(cproc/'cproc'), *DEFINES, '-E', inside(source), '-o', inside(preprocessed)])
        docker([inside(cproc/'cproc-qbe'), '-t', frontend_target, '-o', inside(ir), inside(preprocessed)])
        synchronize(ir, False)
        synchronize(preprocessed, False)
        bind(preprocessed); bind(ir)
        inputs.append((name, preprocessed, ir))
        if name != 'cJSON':
            text = ir.read_text()
            report['translation_units'][name] = {'sha256': hashlib.sha256(ir.read_bytes()).hexdigest(),
                'bytes': len(ir.read_bytes()), 'lines': len(text.splitlines()),
                'functions': len(re.findall(r'^(?:export )?function\b', text, re.M))}
    control_c, control_i, control_ir = work/'control.c', work/'control.i', work/'control.ssa'
    control_c.write_text('long control(void) { return 37; }\n')
    synchronize(control_c); bind(control_c)
    docker([inside(cproc/'cproc'), '-E', inside(control_c), '-o', inside(control_i)])
    docker([inside(cproc/'cproc-qbe'), '-t', frontend_target, '-o', inside(control_ir), inside(control_i)])
    synchronize(control_i, False); synchronize(control_ir, False); bind(control_i); bind(control_ir)
    assert 'ret 37' in control_ir.read_text(), 'sentinel lowering changed; re-audit mutation'
    def assert_reproduced(expected, actual):
        assert actual.read_bytes() == expected.read_bytes(), (str(expected), str(actual), 'stage-two IR mismatch')
    report['negative_controls'] = {}
    for label in labels:
        objects, timings = [], {}
        for name, _, ir in inputs[:-1]:
            asm, obj = work/f'{name}-{label}.s', work/f'{name}-{label}.o'
            backend = corrected if label == 'qbe-corrected' else qbesrc
            cmd = ([backend/'qbe', '-t', qbe_target, '-o', asm, ir] if label.startswith('qbe') else
                   [compiler, ir, '--target', args.target, *(['--optimize'] if label == 'optimized' else []), '-o', asm])
            start = time.perf_counter()
            command(cmd)
            timings[name] = time.perf_counter() - start
            synchronize(asm); bind(asm)
            docker([cc, '-c', inside(asm), '-o', inside(obj)])
            synchronize(obj, False); bind(obj)
            objects.append(obj)
        exe = work/f'cproc-{label}'
        linked = docker([cc, *(['-no-pie'] if isa == 'riscv64' and label.startswith('qbe') else []), *map(inside, objects), '-o', inside(exe)], check=False)
        if linked.returncode:
            assert isa == 'riscv64' and label == 'qbe' and "addend isn't allowed for R_RISCV_GOT_HI20" in linked.stderr, linked.stderr
            (work/'qbe-original-link-failure.log').write_text(linked.stderr)
            report['backends'][label] = {'compile_seconds': timings, 'total_compile_seconds': sum(timings.values()),
                'failure': {'phase': 'link', 'exit': linked.returncode, 'stderr': linked.stderr},
                'upstream_tests_passed': None, 'upstream_tests_total': None}
            print('cproc qbe: original RV64 external-GOT-addend link failure retained', flush=True)
            continue
        synchronize(exe, False); bind(exe)
        reproduced = {}
        failure = None
        for name, preprocessed, ir in inputs:
            output = work/f'{name}-stage2-{label}.ssa'
            result = docker([*execution_prefix, inside(exe), '-t', frontend_target, '-o', inside(output), inside(preprocessed)], check=False)
            if result.returncode:
                assert arm and label == 'qbe', (label, name, result.returncode, result.stderr)
                failure = {'input': name, 'exit': result.returncode, 'stderr': result.stderr}
                break
            synchronize(output, False)
            assert_reproduced(ir, output)
            bind(output)
            reproduced[name] = hashlib.sha256(output.read_bytes()).hexdigest()
        if failure:
            report['backends'][label] = {'compile_seconds': timings, 'total_compile_seconds': sum(timings.values()),
                'executable_bytes': exe.stat().st_size, 'reproduced_ir': reproduced, 'failure': failure,
                'upstream_tests_passed': None, 'upstream_tests_total': None}
            print(f'cproc {label}: original compiler fails on {failure["input"]} with exit {failure["exit"]}; retained as a failure', flush=True)
            continue
        control_out = work/f'control-stage2-{label}.ssa'
        docker([*execution_prefix, inside(exe), '-t', frontend_target, '-o', inside(control_out), inside(control_i)])
        synchronize(control_out, False); assert_reproduced(control_ir, control_out); bind(control_out)
        corrupt = work/f'control-corrupt-{label}.ssa'
        text = control_out.read_text(); assert text.count('ret 37') == 1
        corrupt.write_text(text.replace('ret 37','ret 38')); bind(corrupt)
        try: assert_reproduced(control_ir, corrupt)
        except AssertionError: detected = True
        else: raise AssertionError('stage-two IR corruption escaped reproduction oracle')
        report['negative_controls'][label] = {'detected': detected, 'mutation': 'valid scalar return ret37->ret38',
            'expected_sha256': digest(control_ir), 'stage2_sha256': digest(control_out), 'corrupt_sha256': digest(corrupt)}
        result = docker(['env', 'CCQBE='+' '.join([*execution_prefix,inside(exe)]), './runtests'], cproc)
        (work/f'tests-{label}.log').write_text(result.stdout+result.stderr)
        matched = re.search(r'(\d+)/(\d+) tests passed', result.stdout)
        assert matched and matched[1] == matched[2], result.stdout
        report['backends'][label] = {'compile_seconds': timings, 'total_compile_seconds': sum(timings.values()),
            'executable_bytes': exe.stat().st_size, 'size': docker([('size' if arm else isa+'-linux-gnu-size'), inside(exe)]).stdout.strip(),
            'reproduced_ir': reproduced, 'upstream_tests_passed': int(matched[1]), 'upstream_tests_total': int(matched[2])}
        print(f'cproc {label}: 18 source units compiled; 19 stage-two IR files identical; {matched[1]}/{matched[2]} original tests passed', flush=True)
    # Pre-bound inputs/binaries must remain unchanged throughout every backend.
    for path, expected in bound.items(): assert digest(path) == expected, ('post-binding mismatch', path)
    for source_root in [cproc,cjson]:
        assert not command(['git','-C',source_root,'diff','--name-only','HEAD']).stdout.strip()
    guest_files = [Path(p) for p in bound if Path(p).is_relative_to(work) and
                   not Path(p).is_relative_to(qbesrc) and not Path(p).is_relative_to(corrected)]
    # Bind guest-created outputs and host-authored negative controls before the final barrier.
    for path in work.iterdir():
        if path.is_file() and path.suffix in ['.ssa','.i','.s','.o','.c','.log']:
            synchronize(path, True); bind(path)
    guest_files = list(dict.fromkeys(guest_files + [p for p in work.iterdir() if p.is_file() and p.suffix in ['.ssa','.i','.s','.o','.c','.log']]))
    for start in range(0,len(guest_files),100):
        chunk=guest_files[start:start+100]
        result=docker(['python3','-c','import hashlib,json,sys;print(json.dumps({p:hashlib.sha256(open(p,"rb").read()).hexdigest() for p in sys.argv[1:]}))',*map(inside,chunk)])
        actual=json.loads(result.stdout)
        for path in chunk: assert actual[inside(path)] == digest(path), ('guest-host digest mismatch',path)
    report['provenance'] = {'pre_post_validation': 'passed', 'files': bound, 'source_commits': source_bindings,
        'guest_host_files': len(guest_files), 'guest_host_validation': 'passed', 'helper_sha256': digest(Path(__file__)),
        'compiler_sha256': digest(compiler), 'oracle_binaries': {str(p): digest(p) for p in [qbesrc/'qbe', *([corrected/'qbe'] if isa != 'x86_64' else [])]}}
    report['commands'] = commands
    path = args.report or work/'report.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2)+'\n')
    print(f'report: {path}', flush=True)


if __name__ == '__main__': main()
