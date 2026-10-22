#!/usr/bin/env python3
"""Compile unchanged QBE 1.3 through cproc and LCB, then exercise that compiler.

Requires the ARM64 Linux qualification container; x86-64/RV64 compiler
executables use QEMU user emulation. Source/IR hashes,
original upstream rejections and execution tests remain separate in the report.
This tests QBE as a program; it does not add QBE's target support to LCB.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import time
from cjson_benchmark import ROOT, CPROC, command, fetch

DEFINES = ['-D__CHAR_BIT__=8', '-D__SCHAR_MAX__=127', '-D__SHRT_MAX__=32767',
           '-D__LONG_MAX__=9223372036854775807L']
TARGETS = ['arm64', 'arm64_apple', 'amd64_sysv', 'amd64_apple', 'amd64_win', 'rv64']


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--report', type=Path)
    ap.add_argument('--target', choices=['aarch64-linux','x86_64-linux','riscv64-linux'], default='aarch64-linux')
    ap.add_argument('--repetitions', type=int, default=5)
    args = ap.parse_args()
    assert 1 <= args.repetitions <= 20
    base = ROOT/'.build/linux-arm64'
    isa,qtarget = {'aarch64-linux':('aarch64','arm64'),
                   'x86_64-linux':('x86_64','amd64_sysv'),
                   'riscv64-linux':('riscv64','rv64')}[args.target]
    arm = isa == 'aarch64'
    cc = 'gcc' if arm else isa+'-linux-gnu-gcc'
    execution_prefix = [] if arm else ['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu']
    labels = ['baseline','optimized','qbe','qbe-corrected']
    work = base/('qbe-bootstrap' if arm else 'qbe-bootstrap-'+isa);work.mkdir(parents=True,exist_ok=True)
    source = work/'source'
    if source.exists():shutil.rmtree(source)
    shutil.copytree(ROOT/'third_party/qbe',source)
    cproc = base/'cjson-benchmark/cproc' if arm else work/'cproc-source'
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    def inside(path):return '/work/'+str(Path(path).relative_to(base))
    def docker(cmd,cwd=None,check=True,timeout=600):
        return command(['docker','exec',*(['-w',inside(cwd)] if cwd else []),args.docker_container,*cmd],check=check,timeout=timeout)
    assert docker(['uname','-m']).stdout.strip()=='aarch64'
    def synchronize(path,to_guest=True):
        expected = digest(path) if to_guest else docker(['sha256sum',inside(path)]).stdout.split()[0]
        if to_guest:
            with path.open('rb') as stream:os.fsync(stream.fileno())
        for _ in range(100):
            actual = docker(['sha256sum',inside(path)],check=False).stdout.split() if to_guest else [digest(path)] if path.exists() else []
            if actual and actual[0]==expected:return
            time.sleep(0.05)
        raise AssertionError(f'shared-file digest did not synchronize: {path}')
    for path in source.rglob('*'):
        if path.is_file():synchronize(path)
    configure = ['./configure']
    if not arm:
        libdir = str(Path(docker([cc,'-print-file-name=crtbegin.o']).stdout.strip()).parent)
        configure += ['--target='+isa+'-linux-gnu','--with-gcc-libdir='+libdir]
    docker(configure,cproc);docker(['make','-j4'],cproc)
    docker(['make','-j4','CC=gcc','CFLAGS=-std=c99 -O2'],source)
    backends={}
    patch_path=ROOT/('tests/upstream/qbe-1.3-amd64-extern-flags.json' if isa=='x86_64' else 'tests/upstream/qbe-1.3-'+('rv64' if isa=='riscv64' else 'arm64')+'-extern-offset.json')
    patch=json.loads(patch_path.read_text())
    lock=json.loads((ROOT/'upstream-lock.json').read_text())
    for label in [x for x in labels if x.startswith('qbe')]:
        oracle=work/(label+'-host')
        if oracle.exists():shutil.rmtree(oracle)
        shutil.copytree(ROOT/'third_party/qbe',oracle)
        if label=='qbe-corrected':
            original=ROOT/'third_party/qbe'/patch['source']
            assert digest(original)==lock['vendored_files'][str(original.relative_to(ROOT))]
            text=original.read_text();assert text.count(patch['before'])==1
            (oracle/patch['source']).write_text(text.replace(patch['before'],patch['after']))
        command(['make','-j4',f'CC={os.environ.get("LCB_CC","cc")}','CFLAGS=-std=c99 -O2'],cwd=oracle)
        backends[label]=oracle/'qbe'
    compiler=work/'lcb-snapshot';shutil.copy2(args.compiler,compiler)
    names=docker(['make','-s','src'],source).stdout.split()
    report={'schema':1,'program':'QBE 1.3 self-compilation','target':args.target,
            'execution_mode':'native ARM64 Linux VM' if arm else 'QEMU user emulation',
            'execution':docker(['uname','-a']).stdout.strip(),'compile_host':platform.platform(),
            'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
            'cproc_commit':CPROC,'frontend_defines':DEFINES,'reference_build_flags':'-std=c99 -O2',
            'source_hashes':{str(p.relative_to(ROOT/'third_party/qbe')):digest(p)
                for p in (ROOT/'third_party/qbe').rglob('*') if p.is_file()},
            'translation_units':{},'backends':{},'rejections':[],'oracle_patch_sha256':digest(patch_path),
            'notes':['QBE source and frontend IR are unmodified. GCC-header constant defines describe the selected LP64 target.',
                     'The original GCC-built QBE executable is the assembly comparison reference.',
                     'Original QBE backend self-compilation failures are retained separately from the exact test-only target-specific external-address correction.',
                     'Reproducing Windows assembly with compiled QBE does not implement a Windows target in LCB.',
                     'Original runner tests execute native ARM64 output. Other target outputs are byte comparisons only.',
                     'Input-object text totals are separate from linked executable text; the linker can add layout-dependent erratum workarounds and padding.',
                     'Workload runtime includes process startup and assembly output to /dev/null; local samples are not universal performance claims.',
                     'For emulated compiler executables, the native GCC reference timing is not a like-for-like performance comparison.']}
    if isa=='x86_64':
        regression=work/'extern-flags';regression.mkdir(exist_ok=True)
        report['oracle_regression']={'offsets':[],'original_exit':1,'corrected_exit':0}
        for offset in [1,140,-8,4096,2147483647,-2147483648]:
            ir,caller=regression/'input.ssa',regression/'caller.c'
            ir.write_text((ROOT/'tests/regressions/qbe-amd64-extern-flags.ssa').read_text().replace(', 140',f', {offset}'))
            caller.write_text((ROOT/'tests/regressions/qbe-amd64-extern-flags.c').read_text().replace('(uintptr_t)(external + 140)',f'((uintptr_t)external + UINT64_C({offset % (1<<64)}))'))
            synchronize(ir);synchronize(caller)
            for label in ['qbe','qbe-corrected']:
                asm,exe=regression/(label+'.s'),regression/label
                command([backends[label],'-t',qtarget,'-o',asm,ir]);synchronize(asm)
                docker([cc,inside(caller),inside(asm),'-o',inside(exe)])
                result=docker([*execution_prefix,inside(exe)],check=False)
                assert result.returncode==(1 if label=='qbe' else 0),(label,offset,result.returncode,result.stderr)
            report['oracle_regression']['offsets'].append(offset)
    (work/'ir').mkdir(exist_ok=True)
    inputs=[]
    for name in names:
        ir=work/'ir'/name.replace('/','-').replace('.c','.ssa')
        docker([inside(cproc/'cproc'),*DEFINES,'-I'+inside(source),'-emit-qbe',inside(source/name),'-o',inside(ir)])
        synchronize(ir,False);inputs.append(ir)
        text=ir.read_text()
        report['translation_units'][name]={'ir_sha256':digest(ir),'bytes':ir.stat().st_size,
            'lines':len(text.splitlines()),'functions':len(re.findall(r'^(?:export )?function\b',text,re.M))}
    unavailable = set()
    for label in labels:
        flags = ['--optimize'] if label=='optimized' else []
        objects=[];timings={}
        for ir in inputs:
            asm,obj=work/f'{ir.stem}-{label}.s',work/f'{ir.stem}-{label}.o'
            cmd=([backends[label],'-t',qtarget,'-o',asm,ir] if label.startswith('qbe') else
                 [compiler,ir,'--target',args.target,*flags,'-o',asm])
            start=time.perf_counter();command(cmd);timings[ir.stem]=time.perf_counter()-start
            synchronize(asm);docker([cc,'-c',inside(asm),'-o',inside(obj)]);objects.append(obj)
        link_flags = ['-no-pie'] if isa=='riscv64' and label.startswith('qbe') else []
        exe=work/f'qbe-{label}'
        linked=docker([cc,*link_flags,*map(inside,objects),'-o',inside(exe)],check=False)
        if linked.returncode:
            assert label=='qbe',(label,linked.stderr)
            report['backends'][label]={'compile_seconds':timings,'total_compile_seconds':sum(timings.values()),
                'link_flags':link_flags,'failure':{'phase':'link','exit':linked.returncode,'stderr':linked.stderr},
                'fixture_assembly_matches':{},'self_ir_assembly_matches':0,'original_runner_passes':None}
            unavailable.add(label)
            continue
        size_rows=docker(['size',*map(inside,objects)]).stdout.splitlines()[1:]
        hash_rows=docker(['sha256sum',*map(inside,objects)]).stdout.splitlines()
        assert len(size_rows)==len(objects)==len(hash_rows)
        object_sizes={}
        for ir,row,hash_row in zip(inputs,size_rows,hash_rows):
            fields=row.split()
            object_sizes[ir.stem]={'text':int(fields[0]),'data':int(fields[1]),'bss':int(fields[2]),
                                  'sha256':hash_row.split()[0]}
        report['backends'][label]={'compile_seconds':timings,'total_compile_seconds':sum(timings.values()),
            'link_flags':link_flags,'size':docker(['size',inside(exe)]).stdout.strip(),
            'object_sizes':object_sizes,'object_text_bytes':sum(row['text'] for row in object_sizes.values()),
            'executable_sha256':docker(['sha256sum',inside(exe)]).stdout.split()[0],
            'fixture_assembly_matches':{},'self_ir_assembly_matches':0}
    runners = {'reference':inside(source/'qbe')}
    for label in labels:
        if label in unavailable:continue
        runner=work/('run-'+label)
        runner.write_text('#!/bin/sh\nexec '+' '.join([*execution_prefix,inside(work/('qbe-'+label))])+' "$@"\n')
        runner.chmod(0o755);synchronize(runner)
        runners[label]=inside(runner)
    # Execute the comparison loop inside the VM, avoiding Docker startup in timings.
    probe=work/'probe.py'
    probe.write_text('''from pathlib import Path
import hashlib,json,subprocess,time
root=Path(WORKPATH);out=root/'outputs';out.mkdir(exist_ok=True)
backends=RUNNERS
result={'matches':{},'self_ir_matches':{},'rejections':[],'samples':{},'failures':{}}
def compare(target,p,kind):
    reference=None
    for label,exe in backends.items():
        if label in result['failures']:continue
        asm=out/f'{kind}-{target}-{p.stem}-{label}.s'
        r=subprocess.run([str(exe),'-t',target,'-o',str(asm),str(p)],capture_output=True,text=True)
        if label=='reference':
            reference=(r.returncode,asm.read_bytes() if asm.exists() else b'')
            if r.returncode:result['rejections'].append({'target':target,'input':p.name,'exit':r.returncode,'stderr':r.stderr})
        else:
            if label=='qbe' and (r.returncode!=reference[0] or (r.returncode==0 and asm.read_bytes()!=reference[1])):
                result['failures'][label]={'target':target,'input':p.name,'exit':r.returncode,'reference_exit':reference[0],'stderr':r.stderr,'phase':'assembly reproduction','assembly_sha256':hashlib.sha256(asm.read_bytes()).hexdigest() if r.returncode==0 else None,'reference_assembly_sha256':hashlib.sha256(reference[1]).hexdigest() if reference[0]==0 else None}
                continue
            assert r.returncode==reference[0],(target,p.name,label,r.returncode,reference[0],r.stderr)
            if r.returncode==0:
                assert asm.read_bytes()==reference[1],(target,p.name,label,'assembly differs')
                table=result['matches'].setdefault(target,{}) if kind=='fixture' else result['self_ir_matches']
                table[label]=table.get(label,0)+1
for target in TARGETS:
    for p in sorted((root/'source/test').glob('*.ssa')):compare(target,p,'fixture')
for p in sorted((root/'ir').glob('*.ssa')):compare('arm64',p,'self')
for label,exe in backends.items():
    if label in result['failures']:continue
    samples=[]
    for _ in range(REPETITIONS):
        start=time.monotonic()
        for p in sorted((root/'ir').glob('*.ssa')):
            subprocess.run([str(exe),'-t','arm64','-o','/dev/null',str(p)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        samples.append(time.monotonic()-start)
    result['samples'][label]=samples
(root/'probe.json').write_text(json.dumps(result,indent=2)+'\\n')
'''.replace('TARGETS',repr(TARGETS)).replace('REPETITIONS',str(args.repetitions)).replace('WORKPATH',repr(inside(work))).replace('RUNNERS',repr(runners)))
    synchronize(probe);docker(['python3',inside(probe)],timeout=900)
    measured=work/'probe.json';synchronize(measured,False);comparison=json.loads(measured.read_text())
    report['rejections']=comparison['rejections']
    report['runtime']={label:{'seconds':samples,'median_seconds':statistics.median(samples)} for label,samples in comparison['samples'].items()}
    # The original runner uses fixed temporary filenames: run modes sequentially.
    for label in labels:
        entry=report['backends'][label]
        if label in unavailable:
            print(f'QBE {label}: original link failure retained separately',flush=True)
            continue
        if label in comparison['failures']:
            entry['failure']=comparison['failures'][label]
            entry['original_runner_passes']=None
            print(f'QBE {label}: original self-compilation failure retained: {entry["failure"]}',flush=True)
            continue
        entry['fixture_assembly_matches']={target:values[label] for target,values in comparison['matches'].items()}
        entry['self_ir_assembly_matches']=comparison['self_ir_matches'][label]
        result=docker(['env','bin='+runners[label],'binref='+inside(source/'qbe'),'TARGET=arm64','sh','tools/test.sh','all'],source)
        log=work/f'tests-{label}.log';log.write_text(result.stdout+result.stderr)
        assert 'All is fine!' in result.stdout,result.stdout
        entry['original_runner_passes']=result.stdout.count('[ok]')
        entry['original_runner_log_sha256']=digest(log)
        print(f'QBE {label}: {sum(entry["fixture_assembly_matches"].values())} exact fixture assemblies, {entry["self_ir_assembly_matches"]} self-IR assemblies; {entry["original_runner_passes"]} original ARM64 runtime tests',flush=True)
    destination=args.report or work/'report.json';destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(report,indent=2)+'\n')
    print(f'report: {destination}',flush=True)


if __name__=='__main__':main()
