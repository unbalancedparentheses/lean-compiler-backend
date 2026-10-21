#!/usr/bin/env python3
"""Seeded Csmith/cproc programs: GCC O0/O2 and identical IR through LCB/QBE.

Requires the ARM64 Linux test container with csmith 2.3.0 and libcsmith-dev.
Generated C, IR, assembly, compiler diagnostics and outputs remain in .build.
Pointers/packed structs/bitfields/volatile accesses are disabled in this profile:
cproc rejects some of Csmith's incompatible-pointer comparisons. Arrays, ordinary
structs/unions, scalar arithmetic, loops and calls remain enabled.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
from cjson_benchmark import ROOT, CPROC, command, fetch

OPTIONS = ['--no-pointers', '--no-packed-struct', '--no-bitfields', '--no-volatiles',
           '--no-volatile-pointers', '--max-funcs', '8', '--max-block-depth', '3',
           '--max-expr-complexity', '6']
DEFINES = ['-D__FLT_MAX__=3.40282346638528859811704183484516925e+38F',
           '-D__DBL_MAX__=1.79769313486231570814527423731704357e+308']


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--seed-start', type=int, default=20261021)
    ap.add_argument('--seeds', type=int, default=8)
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    assert 1 <= args.seeds <= 1000
    base = ROOT/'.build/linux-arm64'
    work = base/'csmith'
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
    cproc = base/'cjson-benchmark/cproc'
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    docker(['./configure'],cproc)
    docker(['make','-j4'],cproc)
    qbesrc = work/'qbe-host'
    if not qbesrc.exists():shutil.copytree(ROOT/'third_party/qbe',qbesrc)
    command(['make','clean'],cwd=qbesrc)
    command(['make','-j4',f'CC={os.environ.get("LCB_CC","cc")}','CFLAGS=-std=c99 -O2'],cwd=qbesrc)
    compiler = work/'lcb-snapshot'
    shutil.copy2(ROOT/'.lake/build/bin/lcb',compiler)
    report = {'schema':1,'program':'seeded Csmith via cproc','target':'aarch64-linux',
              'execution':docker(['uname','-a']).stdout.strip(),'csmith_version':version,
              'packages':docker(['dpkg-query','-W','csmith','libcsmith-dev','gcc','libc6-dev']).stdout.strip(),
              'runtime_header_hashes':docker(['find','/usr/include/csmith','-type','f','-exec','sha256sum','{}','+']).stdout.strip(),
              'cproc_commit':CPROC,'qbe_version':'1.3 (unchanged pinned source)',
              'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
              'generation_options':OPTIONS,'frontend_defines':DEFINES,'cases':[],'unqualified':[],
              'notes':['Generated programs and upstream sources are not patched.',
                       'GCC O0 and O2 compile the C directly; all three backends receive identical cproc IR.',
                       'Default profile excludes pointer, packed-struct, bitfield and volatile generation; arrays/ordinary aggregates remain enabled.',
                       'The two floating-limit defines supply constants expected by GCC float.h used by Csmith safe_math.h.',
                       'Qualified executables terminate within 15 seconds and print the same checksum; GCC O0 reference timeouts are retained as unqualified seeds.']}
    report_path = args.report or work/'report.json'
    report_path.parent.mkdir(parents=True,exist_ok=True)
    for seed in range(args.seed_start,args.seed_start+args.seeds):
        case=work/str(seed);case.mkdir(exist_ok=True)
        source,ir=case/'input.c',case/'input.ssa'
        docker(['csmith','--seed',str(seed),*OPTIONS,'--output',inside(source)])
        synchronize(source,False)
        frontend=docker([inside(cproc/'cproc'),'-I/usr/include/csmith',*DEFINES,'-emit-qbe',inside(source),'-o',inside(ir)],check=False)
        (case/'frontend.log').write_text(frontend.stdout+frontend.stderr)
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
                build=['gcc','-'+label.split('-')[1],'-I/usr/include/csmith',inside(source),'-lm','-o',inside(exe)]
            else:
                cmd=([qbesrc/'qbe','-t','arm64','-o',asm,ir] if label=='qbe' else
                     [compiler,ir,'--target','aarch64-linux',*(['--optimize'] if label=='optimized' else []),'-o',asm])
                emitted=command(cmd,check=False)
                (case/(label+'-compile.log')).write_text(emitted.stdout+emitted.stderr)
                assert emitted.returncode==0,(seed,label,emitted.stderr)
                synchronize(asm)
                build=['gcc',inside(asm),'-lm','-o',inside(exe)]
            linked=docker(build,check=False)
            (case/(label+'-link.log')).write_text(linked.stdout+linked.stderr)
            assert linked.returncode==0,(seed,label,linked.stderr)
            result=docker(['timeout','15',inside(exe)],check=False)
            (case/(label+'-run.log')).write_text(result.stdout+result.stderr)
            if label=='gcc-O0' and result.returncode==124:
                row['reason']='GCC O0 reference exceeded the 15-second execution budget; backend comparison unmeasured'
                report['unqualified'].append(row)
                qualified=False
                print(f'Csmith {seed}: reference timeout retained as unqualified, not a pass',flush=True)
                break
            assert result.returncode==0,(seed,label,result.returncode,result.stderr)
            assert re.fullmatch(r'checksum = [0-9A-Fa-f]+\n',result.stdout),result.stdout
            row['outputs'][label]=result.stdout.strip()
            assert row['outputs'][label]==row['outputs']['gcc-O0'],(seed,label,row['outputs'])
        if qualified:report['cases'].append(row)
        report_path.write_text(json.dumps(report,indent=2)+'\n')
        if qualified:print(f'Csmith {seed}: {row["ir_lines"]} IR lines; GCC O0/O2, baseline, optimized and original QBE agree: {row["outputs"]["gcc-O0"]}',flush=True)
    print(f'{len(report["cases"])} Csmith seeds passed; {len(report["unqualified"])} reference timeouts unqualified; report: {report_path}',flush=True)


if __name__=='__main__':main()
