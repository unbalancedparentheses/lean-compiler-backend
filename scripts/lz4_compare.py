#!/usr/bin/env python3
"""Pinned unmodified LZ4 library and upstream fuzzer/frame drivers via cproc.

Run upstream assertions and compare compressed bytes and round trips with GCC.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import traceback
from cjson_benchmark import ROOT, CPROC, command, fetch
from docker_sync import host_file

LZ4 = 'ebb370ca83af193212df4dcbadcc5d87bc0de2f0'  # 1.10.0
LIBRARY = ['lz4', 'lz4hc', 'lz4frame', 'xxhash']
DRIVERS = ['fuzzer', 'frametest']
DEFINES = ['-D__CHAR_BIT__=8', '-D__SCHAR_MAX__=127', '-D__SHRT_MAX__=32767',
           '-D__LONG_MAX__=9223372036854775807L']


def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', choices=['aarch64-linux', 'x86_64-linux', 'riscv64-linux'], default='aarch64-linux')
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--report', type=Path)
    ap.add_argument('--work', type=Path, help='Fresh Docker-mounted artifact directory')
    args = ap.parse_args()
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps({'status':'setup_running','target':args.target})+'\n')
    isa = args.target.removesuffix('-linux'); arm = isa == 'aarch64'
    qtarget = {'aarch64': 'arm64', 'x86_64': 'amd64_sysv', 'riscv64': 'rv64'}[isa]
    cc = 'gcc' if arm else isa+'-linux-gnu-gcc'
    prefix = [] if arm else ['qemu-'+isa, '-L', '/usr/'+isa+'-linux-gnu']
    base = ROOT/'.build/linux-arm64'; work = args.work.resolve() if args.work else base/('lz4-benchmark-'+isa)
    assert work.is_relative_to(base.resolve())
    assert not work.exists(), 'work directory must be fresh; choose --work for another run'
    work.mkdir(parents=True, exist_ok=True)
    harness = work/'harness.py'; harness.write_bytes(Path(__file__).read_bytes())
    report_path = args.report or work/'report.json'
    report_path.write_text(json.dumps({'status':'setup_running','target':args.target})+'\n')
    source, cproc = work/'source', work/'cproc'
    fetch(source, 'https://github.com/lz4/lz4.git', LZ4)
    fetch(cproc, 'https://github.com/michaelforney/cproc.git', CPROC)
    def inside(p): return '/work/'+str(Path(p).relative_to(base))
    def docker(cmd, cwd=None, check=True):
        return command(['docker', 'exec', *(['-w', inside(cwd)] if cwd else []), args.docker_container, *cmd], check=check, timeout=600)
    def sync(p): host_file(p, base, args.docker_container)
    def sync_guest(p):
        expected = docker(['sha256sum', inside(p)]).stdout.split()[0]
        for _ in range(100):
            if p.exists() and digest(p) == expected: return
            time.sleep(.05)
        raise AssertionError('guest artifact did not synchronize: '+str(p))
    assert docker(['uname', '-m']).stdout.strip() == 'aarch64'
    configure = ['./configure']
    if not arm:
        libdir = str(Path(docker([cc, '-print-file-name=crtbegin.o']).stdout.strip()).parent)
        configure += ['--target='+isa+'-linux-gnu', '--with-gcc-libdir='+libdir]
    docker(configure, cproc); docker(['make', '-j4'], cproc)
    compiler = work/'lcb-snapshot'; shutil.copy2(args.compiler, compiler)
    source_hashes = {str(p.relative_to(source)): digest(p) for p in source.rglob('*') if p.suffix in ['.c', '.h'] and '.git' not in p.parts}
    for name in source_hashes: sync(source/name)
    flags = [*DEFINES, '-I'+inside(source/'lib'), '-I'+inside(source/'programs')]
    oracles = {}
    qbe_sources = {str(p.relative_to(ROOT/'third_party/qbe')): digest(p) for p in (ROOT/'third_party/qbe').rglob('*') if p.suffix in ['.c', '.h'] and p.name != 'config.h'}
    patch_file = ROOT/('tests/upstream/qbe-1.3-amd64-extern-flags.json' if isa == 'x86_64' else 'tests/upstream/qbe-1.3-'+('arm64' if arm else 'rv64')+'-extern-offset.json')
    patch = json.loads(patch_file.read_text())
    for label in ['qbe', 'qbe-corrected']:
        dest = work/(label+'-host')
        if dest.exists(): shutil.rmtree(dest)
        shutil.copytree(ROOT/'third_party/qbe', dest)
        assert all(digest(dest/n) == h for n, h in qbe_sources.items())
        if label == 'qbe-corrected':
            p = dest/patch['source']; text = p.read_text(); assert text.count(patch['before']) == 1
            p.write_text(text.replace(patch['before'], patch['after']))
        command(['make', '-j4', 'CC='+os.environ.get('LCB_CC', 'cc'), 'CFLAGS=-std=c99 -O2'], cwd=dest)
        oracles[label] = dest/'qbe'
    report_path = args.report or work/'report.json'
    report = {'schema': 1, 'status': 'running', 'program': 'LZ4 1.10.0 library and upstream fuzzer/frame drivers',
        'target': args.target, 'execution_mode': 'native Linux ARM64 VM' if arm else 'QEMU user emulation',
        'source_commit': LZ4, 'cproc_commit': CPROC, 'source_hashes': source_hashes,
        'compiler_identity': command([compiler, '--build-identity']).stdout.strip(), 'compiler_sha256': digest(compiler),
        'harness_sha256': digest(harness), 'harness_snapshot': str(harness), 'frontend_defines': DEFINES, 'work': str(work),
        'qbe_source_sha256': qbe_sources, 'qbe_binary_sha256': {n: digest(p) for n, p in oracles.items()},
        'oracle_patch_sha256': digest(patch_file), 'translation_units': {}, 'backends': {},
        'notes': ['Original upstream C/header sources and frontend IR are unmodified.',
            'All four library and both driver units use identical target-specific cproc IR for LCB/QBE; GCC compiles original C.',
            'Original and separately corrected QBE results remain distinct; RV QBE links non-PIE only.',
            'Upstream drivers use two fixed-seed 100-cycle profiles each; frametest also runs basic unit tests each time.',
            'Fuzzer additionally runs unseeded built-in unit tests at compression levels 9/10 and one automatic-seed cycle, whose printed seed is recorded.',
            'Generated stream caller is GCC-built; libraries and upstream fuzzer/frame drivers use the selected compiler backend.',
            'This is a bounded test profile, not the full upstream test suite; stream bytes and cross-decompression compare to GCC O0/O2.',
            'No runtime speedup claim.']}
    def save(): report_path.parent.mkdir(parents=True, exist_ok=True); report_path.write_text(json.dumps(report, indent=2)+'\n')
    save()
    try:
        ir_dir = work/'ir'; ir_dir.mkdir(exist_ok=True)
        units = {n: source/('lib' if n in LIBRARY else 'tests')/(n+'.c') for n in LIBRARY+DRIVERS}
        for n, src in units.items():
            ir = ir_dir/(n+'.ssa')
            docker([inside(cproc/'cproc'), *flags, '-emit-qbe', inside(src), '-o', inside(ir)])
            sync_guest(ir); text = ir.read_text()
            report['translation_units'][n] = {'sha256': digest(ir), 'lines': len(text.splitlines()), 'functions': len(re.findall(r'^(?:export )?function\b', text, re.M))}
        save()
        for label in ['gcc-O0', 'gcc-O2', 'baseline', 'allocated', 'optimized', 'qbe', 'qbe-corrected']:
            dest = work/label
            if dest.exists(): shutil.rmtree(dest)
            dest.mkdir()
            entry = {'status': 'building', 'link_flags': ['-no-pie'] if isa == 'riscv64' and label.startswith('qbe') else [], 'compile_seconds': {}, 'objects': {}}
            report['backends'][label] = entry; save()
            for n, src in units.items():
                obj = dest/(n+'.o'); start = time.perf_counter()
                if label.startswith('gcc'):
                    docker([cc, '-'+label.split('-')[1], *flags, '-c', inside(src), '-o', inside(obj)])
                else:
                    asm = dest/(n+'.s'); ir = ir_dir/(n+'.ssa')
                    cmd = [oracles[label], '-t', qtarget, '-o', asm, ir] if label.startswith('qbe') else [compiler, ir, '--target', args.target, *({'baseline': [], 'allocated': ['--allocate'], 'optimized': ['--optimize']}[label]), '-o', asm]
                    emitted = command(cmd, check=False)
                    if emitted.returncode:
                        entry.update(status='compile_failed', failure={'unit': n, 'exit': emitted.returncode, 'stderr': emitted.stderr})
                        assert label == 'qbe', entry
                        break
                    entry.setdefault('assembly_sha256', {})[n] = digest(asm)
                    sync(asm)
                    assembled = docker([cc, '-c', inside(asm), '-o', inside(obj)], check=False)
                    if assembled.returncode:
                        entry.update(status='assemble_failed', failure={'unit': n, 'exit': assembled.returncode, 'stderr': assembled.stderr})
                        assert label == 'qbe', entry
                        break
                entry['compile_seconds'][n] = time.perf_counter()-start
                entry.setdefault('object_sha256', {})[n] = docker(['sha256sum',inside(obj)]).stdout.split()[0]
                entry['objects'][n] = docker(['size', inside(obj)]).stdout.strip()
            if entry['status'] in ['compile_failed', 'assemble_failed']: save(); continue
            for n in DRIVERS:
                linked = docker([cc, *entry['link_flags'], *[inside(dest/(u+'.o')) for u in LIBRARY], inside(dest/(n+'.o')), '-o', inside(dest/n)], check=False)
                if linked.returncode:
                    entry.update(status='link_failed', failure={'driver': n, 'exit': linked.returncode, 'stderr': linked.stderr})
                    assert label == 'qbe', entry
                    break
            if entry['status'] == 'building': entry['status'] = 'built'
            save(); print(args.target, label, entry['status'], flush=True)
        built = [n for n,e in report['backends'].items() if e['status'] == 'built']
        required = {'gcc-O0','gcc-O2','baseline','allocated','optimized','qbe-corrected'}
        assert required.issubset(built)
        caller = work/'stream.c'; caller.write_text(STREAM); sync(caller)
        report['stream_caller_sha256'] = digest(caller)
        for label in built:
            docker([cc,'-O2',*flags,inside(caller),*[inside(work/label/(n+'.o')) for n in LIBRARY],*report['backends'][label]['link_flags'],'-o',inside(work/label/'stream')])
        original = (work/'optimized/lz4.s').read_text()
        start = original.index('LZ4_versionNumber:')
        end = original.index('.size LZ4_versionNumber',start)
        body = original[start:end]
        increment = {'aarch64':'\tadd x0, x0, #1','x86_64':'\taddl $1, %eax','riscv64':'\taddi a0, a0, 1'}[isa]
        assert '\tret' in body
        damaged = work/'wrong-version.s';damaged.write_text(original[:start]+body.replace('\tret',increment+'\n\tret')+original[end:]);sync(damaged)
        docker([cc,'-O2',*flags,inside(caller),inside(damaged),*[inside(work/'optimized'/(n+'.o')) for n in LIBRARY if n!='lz4'],'-o',inside(work/'wrong-version')])
        negative = docker([*prefix,inside(work/'wrong-version'),'block'],check=False)
        assert negative.returncode == 99, 'compiled library version mutation escaped check'
        report['negative_control'] = {'status':'detected','exit':negative.returncode,'mutation':'Increment compiled LZ4_versionNumber return register','assembly_sha256':digest(damaged)}
        report['executables_sha256'] = {label:{name:docker(['sha256sum',inside(work/label/name)]).stdout.split()[0] for name in [*DRIVERS,'stream']} for label in built}
        probe = work/'probe.py'
        probe.write_text(PROBE.replace('WORK_LITERAL', repr(inside(work))).replace('PREFIX_LITERAL', repr(prefix)).replace('LABELS_LITERAL', repr(built)))
        sync(probe)
        (work/'execution.json').unlink(missing_ok=True)
        tested = docker(['python3',inside(probe)],check=False)
        (work/'probe.log').write_text(tested.stdout+tested.stderr)
        sync_guest(work/'execution.json')
        report['execution'] = json.loads((work/'execution.json').read_text())
        assert tested.returncode == 0, tested.stderr
        for n,e in report['execution']['backends'].items(): report['backends'][n]['execution_status'] = e['status']
        assert all(report['backends'][n]['execution_status'] == 'passed' for n in required)
        assert source_hashes == {n:digest(source/n) for n in source_hashes}
        assert digest(compiler)==report['compiler_sha256']
        for name, entry in report['translation_units'].items(): assert digest(ir_dir/(name+'.ssa'))==entry['sha256']
        for label, oracle in oracles.items(): assert digest(oracle)==report['qbe_binary_sha256'][label]
        for label, manifests in report['executables_sha256'].items():
            for name, expected in manifests.items(): assert docker(['sha256sum',inside(work/label/name)]).stdout.split()[0]==expected
        report['status'] = 'passed' if report['backends']['qbe'].get('execution_status') == 'passed' else 'lcb_passed_with_original_qbe_failure'
    except BaseException:
        report['status'] = 'failed'; report['diagnostic'] = traceback.format_exc(); raise
    finally: save()
    print(args.target, report['status'], report_path, flush=True)


STREAM = r'''#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lz4.h"
#include "lz4hc.h"
#include "lz4frame.h"
int main(int argc,char **argv) {
 unsigned char input[131072],output[131072];
 size_t n=fread(input,1,sizeof input,stdin),count=0;
 if(LZ4_versionNumber()!=LZ4_VERSION_NUMBER)return 99;
 if(argc!=2 || ferror(stdin) || !feof(stdin))return 2;
 if(!strcmp(argv[1],"block")) { int r=LZ4_compress_default((char*)input,(char*)output,(int)n,sizeof output); if(r<=0)return 3;count=r; }
 else if(!strcmp(argv[1],"hc")) { int r=LZ4_compress_HC((char*)input,(char*)output,(int)n,sizeof output,9);if(r<=0)return 4;count=r; }
 else if(!strcmp(argv[1],"frame")) { count=LZ4F_compressFrame(output,sizeof output,input,n,NULL);if(LZ4F_isError(count))return 5; }
 else if(!strcmp(argv[1],"unblock")) { int r=LZ4_decompress_safe((char*)input,(char*)output,(int)n,sizeof output);if(r<0)return 6;count=r; }
 else if(!strcmp(argv[1],"unframe")) {
  LZ4F_dctx *ctx=NULL;size_t used=0,left=1;
  if(LZ4F_isError(LZ4F_createDecompressionContext(&ctx,LZ4F_VERSION)))return 7;
  while(left) {size_t src=n-used,dst=sizeof output-count;left=LZ4F_decompress(ctx,output+count,&dst,input+used,&src,NULL);if(LZ4F_isError(left)||(!src&&!dst))return 8;used+=src;count+=dst;}
  LZ4F_freeDecompressionContext(ctx);if(used!=n)return 9;
 } else return 10;
 return fwrite(output,1,count,stdout)!=count;
}
'''

PROBE = r'''from pathlib import Path
import hashlib,json,subprocess,random
root=Path(WORK_LITERAL);prefix=PREFIX_LITERAL
result={'backends':{}}
reference={}
rng=random.Random(20261022)
payloads=[b'',b'a',b'a'*65536,bytes(range(256))*256,bytes(rng.randrange(256) for _ in range(65536))]
def save(): (root/'execution.json').write_text(json.dumps(result,indent=2)+'\n')
for label in LABELS_LITERAL:
 entry={'status':'running','checks':{}};result['backends'][label]=entry;save()
 try:
  unit=subprocess.run([*prefix,str(root/label/'fuzzer'),'-i1'],capture_output=True,timeout=240)
  entry['unit_tests']={'exit':unit.returncode,'stdout':unit.stdout.decode(errors='replace'),'stderr':unit.stderr.decode(errors='replace')};save()
  assert unit.returncode==0 and all(('All unit tests completed successfully compressionLevel='+str(level)).encode() in unit.stdout for level in [9,10]),(label,'unit tests',unit.stderr[-3000:])
  for driver in ['fuzzer','frametest']:
   for seed in [1,20261022]:
    cmd=[*prefix,str(root/label/driver),'-i100','-s'+str(seed)]
    p=subprocess.run(cmd,capture_output=True,timeout=240)
    entry['checks'][driver+'-'+str(seed)]={'exit':p.returncode,'stdout':p.stdout.decode(errors='replace'),'stderr':p.stderr.decode(errors='replace'),'stdout_sha256':hashlib.sha256(p.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr).hexdigest()};save()
    marker=b'all tests completed successfully' if driver=='fuzzer' else b'All tests completed'
    assert p.returncode==0 and marker in p.stdout+p.stderr,(label,driver,seed,p.stderr[-3000:])
    if driver=='frametest':assert b'Basic tests completed' in p.stdout+p.stderr
  entry['streams'] = []
  for mode in ['block','hc','frame']:
   for index,data in enumerate(payloads):
    def run(which,operation,payload):
     p=subprocess.run([*prefix,str(root/which/'stream'),operation],input=payload,capture_output=True,timeout=60)
     assert p.returncode==0,(which,operation,p.returncode,p.stderr)
     return p.stdout
    packed=run(label,mode,data)
    key=(mode,index)
    if label=='gcc-O0':reference[key]=packed
    assert packed==reference[key],(label,mode,index,'compressed bytes mismatch')
    inverse='unframe' if mode=='frame' else 'unblock'
    assert run(label,inverse,packed)==data
    assert run('gcc-O0',inverse,packed)==data
    assert run(label,inverse,reference[key])==data
    entry['streams'].append({'mode':mode,'payload':index,'input_bytes':len(data),'compressed_bytes':len(packed),'input_sha256':hashlib.sha256(data).hexdigest(),'compressed_sha256':hashlib.sha256(packed).hexdigest()})
  entry['status']='passed'
 except BaseException as e:
  entry.update(status='failed',diagnostic=repr(e));save()
  if label!='qbe':raise
 save()
'''

if __name__ == '__main__': main()
