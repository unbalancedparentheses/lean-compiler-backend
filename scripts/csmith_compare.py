#!/usr/bin/env python3
"""Seeded Csmith/cproc programs: GCC O0/O2 and identical IR through LCB/QBE.

Requires the ARM64 Linux test container with csmith 2.3.0 and libcsmith-dev.
Generated C, IR, assembly, compiler diagnostics and outputs remain in .build.
Pointers/packed structs/bitfields/volatile accesses are disabled in this profile:
cproc rejects some of Csmith's incompatible-pointer comparisons. Arrays, ordinary
structs/unions, scalar arithmetic, loops and calls remain enabled. An optional
pointer profile admits one-level pointers without const qualifiers and retains frontend
incompatible-pointer diagnostics as unqualified, never as backend passes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
import traceback
from cjson_benchmark import ROOT, CPROC, command, fetch

OPTIONS = ['--no-pointers', '--no-packed-struct', '--no-bitfields', '--no-volatiles',
           '--no-volatile-pointers', '--max-funcs', '8', '--max-block-depth', '3',
           '--max-expr-complexity', '6']
DEFINES = ['-D__FLT_MAX__=3.40282346638528859811704183484516925e+38F',
           '-D__DBL_MAX__=1.79769313486231570814527423731704357e+308']


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--target', choices=['aarch64-linux','x86_64-linux','riscv64-linux'], default='aarch64-linux')
    ap.add_argument('--seed-start', type=int, default=20261021)
    ap.add_argument('--seeds', type=int, default=8)
    ap.add_argument('--report', type=Path)
    ap.add_argument('--work', type=Path, help='isolated working directory under .build/linux-arm64')
    ap.add_argument('--qbe-no-pie', action='store_true', help='explicit original-QBE-only RV64 link profile; LCB retains default linking')
    ap.add_argument('--profile', choices=['scalar','pointers'], default='scalar')
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    args = ap.parse_args()
    assert 1 <= args.seeds <= 1000
    assert not args.qbe_no_pie or args.target == 'riscv64-linux'
    qbe_link_flags = ['-no-pie'] if args.qbe_no_pie else []
    base = (ROOT/'.build/linux-arm64').resolve()
    isa,qtarget = {'aarch64-linux':('aarch64','arm64'), 'x86_64-linux':('x86_64','amd64_sysv'),
                   'riscv64-linux':('riscv64','rv64')}[args.target]
    arm = isa == 'aarch64'
    cc = 'gcc' if arm else isa+'-linux-gnu-gcc'
    execute = [] if arm else ['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu']
    options = list(OPTIONS)
    if args.profile == 'pointers':
        options.remove('--no-pointers')
        options += ['--no-consts','--no-const-pointers','--max-pointer-depth','1']
    work = base/(('csmith' if args.profile == 'scalar' else 'csmith-pointers') + ('' if arm else '-'+isa) + ('-qbe-no-pie' if args.qbe_no_pie else ''))
    work = (args.work or work).resolve()
    if not work.is_relative_to(base) or work == base:
        ap.error('--work must resolve to a directory below '+str(base))
    work.mkdir(parents=True, exist_ok=True)
    def inside(path): return '/work/'+str(Path(path).relative_to(base))
    def docker(cmd, cwd=None, check=True):
        return command(['docker','exec',*(['-w',inside(cwd)] if cwd else []),args.docker_container,*cmd],check=check)
    assert docker(['uname','-m']).stdout.strip() == 'aarch64'
    version = docker(['csmith','--version']).stdout.strip()
    assert '2.3.0' in version, 're-audit the generation profile for a different Csmith version'
    def synchronize(path, to_guest=True):
        expected = hashlib.sha256(path.read_bytes()).hexdigest() if to_guest else docker(['sha256sum',inside(path)]).stdout.split()[0]
        if to_guest:
            with path.open('rb') as stream: os.fsync(stream.fileno())
        for _ in range(100):
            actual = docker(['sha256sum',inside(path)]).stdout.split()[0] if to_guest else hashlib.sha256(path.read_bytes()).hexdigest()
            if actual == expected:return
            time.sleep(0.05)
        raise AssertionError(f'host/guest input did not synchronize: {path}')
    cproc = base/'cjson-benchmark/cproc' if arm else work/'cproc-source'
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    configure = ['./configure']
    if not arm:
        libdir = str(Path(docker([cc,'-print-file-name=crtbegin.o']).stdout.strip()).parent)
        configure += ['--target='+isa+'-linux-gnu','--with-gcc-libdir='+libdir]
    docker(configure,cproc)
    docker(['make','-j4'],cproc)
    qbesrc = work/'qbe-host'
    if not qbesrc.exists():shutil.copytree(ROOT/'third_party/qbe',qbesrc)
    manifest = {str(p.relative_to(ROOT/'third_party/qbe')):hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (ROOT/'third_party/qbe').rglob('*') if p.suffix in ('.c','.h') and p.name!='config.h'}
    assert all(hashlib.sha256((qbesrc/name).read_bytes()).hexdigest()==sha for name,sha in manifest.items())
    command(['make','clean'],cwd=qbesrc)
    command(['make','-j4',f'CC={os.environ.get("LCB_CC","cc")}','CFLAGS=-std=c99 -O2'],cwd=qbesrc)
    assert all(hashlib.sha256((qbesrc/name).read_bytes()).hexdigest()==sha for name,sha in manifest.items())
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler,compiler)
    report = {'schema':1,'program':'seeded Csmith via cproc','target':args.target,'work':str(work),
              'execution_mode':'native Linux ARM64 VM' if arm else 'QEMU user emulation',
              'execution':docker(['uname','-a']).stdout.strip(),'csmith_version':version,
              'packages':docker(['dpkg-query','-W','csmith','libcsmith-dev','gcc','libc6-dev']).stdout.strip(),
              'runtime_header_hashes':docker(['find','/usr/include/csmith','-type','f','-exec','sha256sum','{}','+']).stdout.strip(),
              'cproc_commit':CPROC,'qbe_version':'1.3 (unchanged pinned source)',
              'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
              'qbe_source_sha256':manifest,'qbe_binary_sha256':hashlib.sha256((qbesrc/'qbe').read_bytes()).hexdigest(),
              'qbe_link_flags':qbe_link_flags,'lcb_link_flags':[],
              'seed_start':args.seed_start,'seeds_requested':args.seeds,
              'profile':args.profile,'generation_options':options,'frontend_defines':DEFINES,'cases':[],'lcb_only_cases':[],'unqualified':[],
              'c_compiler':docker([cc,'--version']).stdout.strip(),
              'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),
              'harness_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'notes':['Generated programs and upstream sources are not patched.',
                       'GCC O0 and O2 compile the C directly; all three backends receive identical cproc IR.',
                       'Default profile excludes pointer, packed-struct, bitfield and volatile generation; arrays/ordinary aggregates remain enabled.',
                       'The two floating-limit defines supply constants expected by GCC float.h used by Csmith safe_math.h.',
                       'Qualified executables terminate within 15 seconds and print the same checksum; GCC O0 reference timeouts are retained as unqualified seeds.',
                       'Original QBE compile/link/runtime discrepancies retain diagnostics in lcb_only_cases, separately from common qualified cases, and cause a nonzero campaign exit.',
                       'Cross-target runs use QEMU, not native target hardware; LCB uses default link flags and original QBE link flags are recorded explicitly.']}
    if args.profile == 'pointers':
        report['notes'].append('Pointer profile enables one-level pointers without const qualifiers; packed structs, bitfields and volatile accesses remain disabled. Known cproc incompatible-pointer comparison/assignment diagnostics are retained as frontend rejections, with GCC syntax diagnostics, not backend failures or passes.')
    report_path = args.report or work/'report.json'
    report_path.parent.mkdir(parents=True,exist_ok=True)
    report['status'] = 'running'
    report['failures'] = []
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    current_seed, row = None, None
    try:
        for seed in range(args.seed_start,args.seed_start+args.seeds):
            current_seed = seed
            row = {'seed':seed}
            case=work/str(seed);case.mkdir(exist_ok=True)
            source,ir=case/'input.c',case/'input.ssa'
            docker(['csmith','--seed',str(seed),*options,'--output',inside(source)])
            synchronize(source,False)
            frontend=docker([inside(cproc/'cproc'),'-I/usr/include/csmith',*DEFINES,'-emit-qbe',inside(source),'-o',inside(ir)],check=False)
            (case/'frontend.log').write_text(frontend.stdout+frontend.stderr)
            if frontend.returncode and args.profile == 'pointers':
                errors = [line.split('error: ',1)[1] for line in frontend.stderr.splitlines() if 'error: ' in line]
                known = {'base types of pointer assignment must be compatible or void',
                         "pointer operands to '==' operator are to incompatible types",
                         "pointer operands to '!=' operator are to incompatible types"}
                assert frontend.returncode == 1 and errors and all(error in known for error in errors),(seed,'unexpected frontend failure',frontend.stderr)
                syntax = docker([cc,'-fsyntax-only','-I/usr/include/csmith',inside(source)],check=False)
                (case/'gcc-syntax.log').write_text(syntax.stdout+syntax.stderr)
                assert syntax.returncode == 0,(seed,'GCC syntax rejection',syntax.stderr)
                report['unqualified'].append({'seed':seed,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                    'source_lines':len(source.read_text().splitlines()),'reason_kind':'frontend-rejection',
                    'reason':'Known incompatible-pointer diagnostic before backend IR; no backend comparison measured',
                    'frontend_exit':frontend.returncode,'frontend_diagnostic':frontend.stderr,
                    'gcc_syntax_exit':syntax.returncode,'gcc_syntax_diagnostic':syntax.stderr})
                report_path.write_text(json.dumps(report,indent=2)+'\n')
                print(f'Csmith {seed}: known frontend pointer rejection retained as unqualified',flush=True)
                continue
            assert frontend.returncode==0,(seed,'frontend rejection',frontend.stderr)
            synchronize(ir,False)
            text=ir.read_text()
            row={'seed':seed,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                 'source_lines':len(source.read_text().splitlines()),'ir_sha256':hashlib.sha256(ir.read_bytes()).hexdigest(),
                 'ir_lines':len(text.splitlines()),'functions':len(re.findall(r'^(?:export )?function\b',text,re.M)), 'outputs':{}}
            qualified=True
            for label in ['gcc-O0','gcc-O2','baseline','optimized','qbe']:
                exe,asm=case/label,case/(label+'.s')
                if label.startswith('gcc'):
                    build=[cc,'-'+label.split('-')[1],'-I/usr/include/csmith',inside(source),'-lm','-o',inside(exe)]
                else:
                    cmd=([qbesrc/'qbe','-t',qtarget,'-o',asm,ir] if label=='qbe' else
                         [compiler,ir,'--target',args.target,*(['--optimize'] if label=='optimized' else []),'-o',asm])
                    emitted=command(cmd,check=False)
                    (case/(label+'-compile.log')).write_text(emitted.stdout+emitted.stderr)
                    if label=='qbe' and emitted.returncode:
                        row['reference_failure']={'phase':'compile','exit':emitted.returncode,'diagnostic':emitted.stdout+emitted.stderr}
                        continue
                    assert emitted.returncode==0,(seed,label,emitted.stderr)
                    synchronize(asm)
                    build=[cc,*(qbe_link_flags if label=='qbe' else []),inside(asm),'-lm','-o',inside(exe)]
                linked=docker(build,check=False)
                (case/(label+'-link.log')).write_text(linked.stdout+linked.stderr)
                if label=='qbe' and linked.returncode:
                    row['reference_failure']={'phase':'link','exit':linked.returncode,'diagnostic':linked.stdout+linked.stderr}
                    continue
                assert linked.returncode==0,(seed,label,linked.stderr)
                result=docker(['timeout','15',*execute,inside(exe)],check=False)
                (case/(label+'-run.log')).write_text(result.stdout+result.stderr)
                if label=='gcc-O0' and result.returncode==124:
                    row['reason_kind']='reference-timeout'
                    row['reason']='GCC O0 reference exceeded the 15-second execution budget; backend comparison unmeasured'
                    report['unqualified'].append(row)
                    qualified=False
                    print(f'Csmith {seed}: reference timeout retained as unqualified, not a pass',flush=True)
                    break
                if label=='qbe' and (result.returncode or result.stdout.strip()!=row['outputs']['gcc-O0']):
                    row['reference_failure']={'phase':'execute','exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
                    continue
                assert result.returncode==0,(seed,label,result.returncode,result.stderr)
                assert re.fullmatch(r'checksum = [0-9A-Fa-f]+\n',result.stdout),result.stdout
                row['outputs'][label]=result.stdout.strip()
                assert row['outputs'][label]==row['outputs']['gcc-O0'],(seed,label,row['outputs'])
            if qualified:
                report['lcb_only_cases' if 'reference_failure' in row else 'cases'].append(row)
                if 'negative_control' not in report:
                    original = (case/'optimized.s').read_text()
                    increment = {'aarch64':'\tadd x0, x0, #1', 'x86_64':'\taddl $1, %eax', 'riscv64':'\taddi a0, a0, 1'}[isa]
                    damaged = original.replace('\tret',increment+'\n\tret')
                    assert damaged != original
                    bad,badexe = case/'corrupted.s',case/'corrupted'
                    bad.write_text(damaged);synchronize(bad)
                    linked = docker([cc,inside(bad),'-lm','-o',inside(badexe)],check=False)
                    assert linked.returncode == 0,linked.stderr
                    result = docker(['timeout','15',*execute,inside(badexe)],check=False)
                    assert result.returncode != 0 or result.stdout.strip()!=row['outputs']['gcc-O0'],'corrupted emitted returns escaped checksum/exit oracle'
                    report['negative_control']={'seed':seed,'status':'detected','mutation':'Increment integer return register before every ret.',
                        'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr,
                        'assembly_sha256':hashlib.sha256(bad.read_bytes()).hexdigest()}
            report_path.write_text(json.dumps(report,indent=2)+'\n')
            if qualified:print(f'Csmith {args.target} {seed}: {row["ir_lines"]} IR lines; GCC O0/O2 and LCB agree: {row["outputs"]["gcc-O0"]}; original QBE '+('unqualified' if 'reference_failure' in row else 'agrees'),flush=True)
    except BaseException:
        report['status'] = 'failed'
        failure = dict(row) if row is not None else {'seed':current_seed}
        failure['status'] = 'failed'
        failure['diagnostic'] = traceback.format_exc()
        report['failures'].append(failure)
        # Keep the original traceback/exit behavior, with the failing attempt
        # retained separately from qualified and expected-reference outcomes.
        raise
    finally:
        report['common_qualified_seeds'] = len(report['cases'])
        report['lcb_qualified_seeds'] = len(report['cases'])+len(report['lcb_only_cases'])
        report['qualified_ir_lines'] = sum(row['ir_lines'] for row in report['cases'])
        report['lcb_qualified_ir_lines'] = sum(row['ir_lines'] for row in report['cases']+report['lcb_only_cases'])
        if report['status'] != 'failed':
            report['status'] = ('no_qualified' if report['lcb_qualified_seeds'] == 0 else
                                'reference_failed' if report['lcb_only_cases'] else 'passed')
        if 'negative_control' not in report:
            report['negative_control'] = {'status':'not_run',
                'reason':'No executable case completed qualification.' if report['lcb_qualified_seeds'] == 0 else
                         'Campaign failed before the corruption control completed.'}
        report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'{len(report["cases"])} common Csmith seeds passed; {len(report["lcb_only_cases"])} LCB-only qualified; {len(report["unqualified"])} attempts unqualified; report: {report_path}',flush=True)
    if report['status'] != 'passed':raise SystemExit(1)


if __name__=='__main__':main()
