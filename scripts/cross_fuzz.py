#!/usr/bin/env python3
"""Snapshot-based Linux differential fuzzing with independent Python expectations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import traceback
import fuzz
from docker_sync import host_file, sources


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def profile_source(raw, profile):
    """Mask shift counts in generated IR without changing the Python oracle."""
    if profile == 'raw':
        return raw, 0
    assert profile == 'explicit-shift-mask'
    names = set(re.findall(r'%([A-Za-z0-9_.$]+)', raw))
    prefix = 'lcb.shift.mask.'
    while any(name.startswith(prefix) for name in names):
        prefix += 'x.'
    shift = re.compile(r'^(\s*)(%[^ ]+) =([wl]) (shl|shr|sar) ([^,]+), (.+)$')
    lines, count = [], 0
    for line in raw.splitlines():
        match = shift.fullmatch(line)
        if match:
            indent, destination, width, operation, left, right = match.groups()
            name = prefix + str(count)
            count += 1
            # QBE shift RHS has word class. Low 5/6 bits are unchanged by
            # narrowing a long operand, including negative/wide constants.
            lines.append(f'{indent}%{name} =w and {right}, {31 if width == "w" else 63}')
            line = f'{indent}{destination} ={width} {operation} {left}, %{name}'
        lines.append(line)
    return '\n'.join(lines) + ('\n' if raw.endswith('\n') else ''), count


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', required=True, choices=['aarch64-linux','x86_64-linux','riscv64-linux'])
    ap.add_argument('--compiler', required=True, type=Path)
    ap.add_argument('--profile', choices=['raw','explicit-shift-mask'], default='raw',
                    help='raw preserves generated IR; explicit-shift-mask inserts width-1 ANDs before shifts')
    ap.add_argument('--seed-start', type=int, default=20263000)
    ap.add_argument('--seeds', type=int, default=2)
    ap.add_argument('--samples', type=int, default=8, help='random pairs in addition to five fixed edge pairs')
    ap.add_argument('--functions', type=int, default=8)
    ap.add_argument('--steps', type=int, default=32)
    ap.add_argument('--report', required=True, type=Path)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    args = ap.parse_args()
    assert 1 <= args.seeds <= 100000 and 1 <= args.functions <= 64
    assert 0 <= args.samples <= 10000 and 1 <= args.steps <= 480
    mount = fuzz.ROOT/'.build/linux-arm64'
    mount.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='cross-fuzz-'+args.target+'-'+args.profile+'-', dir=mount))
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler.resolve(), compiler)
    report = {'schema':1, 'profile':args.profile, 'target':args.target, 'work':str(work), 'status':'running',
              'host':platform.platform(), 'compiler_sha256':digest(compiler),
              'seed_start':args.seed_start, 'seeds_requested':args.seeds,
              'functions_per_seed':args.functions, 'random_samples':args.samples,
              'fixed_samples':5, 'steps':args.steps, 'control_flow':True,
              'generator_sha256':digest(Path(fuzz.__file__)),
              'harness_sha256':digest(__file__),
              'upstream_lock_sha256':digest(fuzz.ROOT/'upstream-lock.json'),
              'flake_lock_sha256':digest(fuzz.ROOT/'flake.lock'), 'cases':[],
              'negative_control':'not run', 'reference_failures':[],
              'notes':['LCB and interpreter qualification is separate from unchanged original-QBE qualification.',
                       'Original QBE RV64 uses explicit -no-pie linking; all LCB modes retain default linking.',
                       'Reference failures retain assembly and diagnostics and cause a nonzero campaign exit.',
                       'QEMU execution is not native target-hardware qualification.',
                       'The selected profile sends identical IR to the interpreter, all LCB modes and unchanged original QBE.',
                       'Python expected values use the original untransformed generator semantics.',
                       'Raw and explicit-shift-mask qualification counts are separate profiles; masked results do not erase raw reference failures.']}
    args.report = args.report.resolve()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    def save():
        args.report.write_text(json.dumps(report, indent=2)+'\n')
    def command(cmd, guest=False, check=True):
        cmd = list(map(str, cmd))
        if guest:
            sources(cmd, mount, args.docker_container)
            output = cmd[cmd.index('-o')+1] if '-o' in cmd else None
            for value in cmd[1:]:
                if value != output and Path(value).suffix == '.s' and Path(value).is_file():
                    host_file(value, mount, args.docker_container)
            cmd = ['docker','exec',args.docker_container]+[v.replace(str(mount),'/work') for v in cmd]
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=120)
        if check and result.returncode:
            raise AssertionError(f'command failed ({result.returncode}): {cmd}\n{result.stdout}\n{result.stderr}')
        return result
    try:
        report['compiler_identity'] = command([compiler,'--build-identity']).stdout.strip()
        report['compiler_version'] = command([compiler,'--version']).stdout.strip()
        isa = args.target.removesuffix('-linux')
        guest_arch = command(['uname','-m'], True).stdout.strip()
        assert guest_arch == 'aarch64', 'this Docker runner expects the ARM64 qualification container'
        prefix = [] if isa == 'aarch64' else ['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu']
        cc = 'gcc' if isa == 'aarch64' else isa+'-linux-gnu-gcc'
        report['execution_mode'] = 'Linux ARM64 container' if not prefix else 'QEMU user '+isa+' on Linux ARM64'
        report['guest_uname'] = command(['uname','-a'], True).stdout.strip()
        report['cc_version'] = command([cc,'--version'], True).stdout
        if prefix:
            report['qemu_version'] = command([prefix[0],'--version'], True).stdout
        # Build an isolated copy of the pinned host source. Never use or modify
        # the potentially patched /tmp/qbe tree in the qualification container.
        pinned, oracle = fuzz.ROOT/'third_party/qbe', work/'oracle'
        manifest = {str(p.relative_to(pinned)):digest(p) for p in pinned.rglob('*')
                    if p.suffix in ('.c','.h') and p.name != 'config.h'}
        shutil.copytree(pinned, oracle, ignore=shutil.ignore_patterns('*.o','qbe','config.h','.git'))
        assert all(digest(oracle/name) == sha for name,sha in manifest.items())
        report['qbe_source_sha256'] = manifest
        host_cc = os.environ.get('LCB_CC', shutil.which('clang') or 'cc')
        report['qbe_host_cc_version'] = command([host_cc,'--version']).stdout
        built = command(['make','-C',oracle,'-j2','CC='+host_cc])
        (work/'qbe-build.log').write_text(built.stdout+built.stderr)
        assert all(digest(oracle/name) == sha for name,sha in manifest.items())
        qbe = oracle/'qbe'
        report['qbe_binary_sha256'] = digest(qbe)
        qtarget = {'aarch64':'arm64','x86_64':'amd64_sysv','riscv64':'rv64'}[isa]
        save()
        for seed in range(args.seed_start, args.seed_start+args.seeds):
            case = work/str(seed);case.mkdir()
            functions = fuzz.generate(seed,args.functions,args.steps,True)
            arguments = fuzz.inputs(seed,args.samples)
            expected = [f.evaluate(a,b) for f in functions for a,b in arguments]
            source, caller, obj = case/'input.ssa', case/'caller.c', case/'caller.o'
            raw = '\n'.join(f.source() for f in functions)+'\n'
            transformed, masks = profile_source(raw,args.profile)
            raw_source = case/'raw-input.ssa';raw_source.write_text(raw)
            source.write_text(transformed)
            caller.write_text(fuzz.driver(functions,arguments))
            row = {'seed':seed,'input_cases':len(expected),'status':'running',
                   'source_sha256':digest(source),'raw_source_sha256':digest(raw_source),
                   'transformed_source_sha256':digest(source),'inserted_masks':masks,
                   'caller_sha256':digest(caller),
                   'arguments':arguments,'expected':expected,'modes':{}}
            report['cases'].append(row);save()
            command([compiler,'--check',source])
            actual = [int(command([compiler,'--eval',source,f.name,a,b]).stdout)
                      for f in functions for a,b in arguments]
            (case/'interpreter-output.json').write_text(json.dumps(actual)+'\n')
            assert actual == expected, f'interpreter mismatch seed {seed}'
            row['interpreter'] = 'passed'
            command([cc,'-std=c11','-O2','-c',caller,'-o',obj],True)
            for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',[])]:
                asm,exe = case/(mode+'.s'),case/mode
                emit = [qbe,'-t',qtarget,'-o',asm,source] if mode == 'qbe' else [compiler,source,'--target',args.target,*flags,'-o',asm]
                # Reference failures remain distinct from LCB mismatches. Finish
                # the remaining seeds and corruption control without patching QBE.
                try:
                    command(emit)
                    # Original QBE RV64 absolute relocations require non-PIE.
                    link = [cc,*(['-no-pie'] if mode == 'qbe' and isa == 'riscv64' else []),obj,asm,'-o',exe]
                    command(link,True)
                    actual = [int(line) for line in command([*prefix,exe],True).stdout.splitlines()]
                    (case/(mode+'-output.json')).write_text(json.dumps(actual)+'\n')
                    row['modes'][mode] = {'emit_command':list(map(str,emit)),
                                          'link_command':list(map(str,link)),
                                          'assembly_sha256':digest(asm),'status':'passed' if actual == expected else 'failed'}
                    assert actual == expected, f'{args.target} {mode} mismatch seed {seed}'
                except Exception:
                    if mode != 'qbe':
                        raise
                    diagnostic = traceback.format_exc()
                    (case/'qbe-failure.txt').write_text(diagnostic)
                    row['modes'][mode] = {'status':'reference_failed','diagnostic':diagnostic,
                                          'emit_command':list(map(str,emit))}
                    if asm.exists():
                        row['modes'][mode]['assembly_sha256'] = digest(asm)
                    report['reference_failures'].append(seed)
            if seed == args.seed_start:
                original = (case/'optimized.s').read_text()
                increment = {'aarch64':'\tadd x0, x0, #1','x86_64':'\taddq $1, %rax','riscv64':'\taddi a0, a0, 1'}[isa]
                damaged = original.replace('\tret',increment+'\n\tret')
                assert damaged != original, 'missing return for corruption control'
                asm,exe = case/'corrupt.s',case/'corrupt'
                asm.write_text(damaged)
                command([cc,obj,asm,'-o',exe],True)
                actual = [int(line) for line in command([*prefix,exe],True).stdout.splitlines()]
                (case/'corrupt-output.json').write_text(json.dumps(actual)+'\n')
                assert actual != expected, 'return corruption escaped independent oracle'
                report['negative_control'] = 'corrupted optimized return detected'
                report['negative_control_assembly_sha256'] = digest(asm)
            row['status'] = 'reference_failed' if seed in report['reference_failures'] else 'passed';save()
            print(f'{args.target}: seed {seed}: {row["status"]} ({len(expected)} cases; LCB/interpreter passed, QBE {row["modes"]["qbe"]["status"]})',flush=True)
        report['status'] = 'reference_failed' if report['reference_failures'] else 'passed'
        report['inserted_masks_total'] = sum(r['inserted_masks'] for r in report['cases'])
        report['generated_functions'] = args.seeds*args.functions
        report['input_cases_per_path'] = sum(r['input_cases'] for r in report['cases'])
        qualified = [r for r in report['cases'] if r.get('interpreter') == 'passed' and
                     all(r['modes'].get(m,{}).get('status') == 'passed'
                         for m in ['baseline','allocated','optimized'])]
        common = [r for r in qualified if r['modes']['qbe']['status'] == 'passed']
        report['lcb_qualified'] = {'seeds':len(qualified), 'functions':len(qualified)*args.functions,
                                   'input_cases_per_path':sum(r['input_cases'] for r in qualified)}
        report['original_qbe_common_qualified'] = {'seeds':len(common), 'functions':len(common)*args.functions,
                                                  'input_cases_per_path':sum(r['input_cases'] for r in common)}
        print(f"{args.target}: {args.seeds} seeds: {report['status']}; "
              f"LCB-qualified={len(qualified)}, original-QBE-common-qualified={len(common)}; "
              f"negative control detected; report {args.report}",flush=True)
    except BaseException:
        report['status'] = 'failed'
        report['failure'] = traceback.format_exc()
        (work/'failure.txt').write_text(report['failure'])
        raise
    finally:
        save()
    if report['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
