#!/usr/bin/env python3
"""Qualify non-ARM Linux targets natively or via QEMU in the development container.

The optional ARM64 Docker container uses /work for .build/linux-arm64 and contains
pinned QBE plus cross-GCC and qemu-user. Emulated runs are labelled separately.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
from fuzz import ROOT, LCB
from upstream_suite import extract


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', choices=['x86_64-linux','riscv64-linux'], default='x86_64-linux')
    ap.add_argument('--docker-container')
    ap.add_argument('--require-execution', action='store_true')
    args=ap.parse_args()
    isa, qtarget = ('x86_64','amd64_sysv') if args.target=='x86_64-linux' else ('riscv64','rv64')
    docker_root=ROOT/'.build/linux-arm64'; work=docker_root/isa; work.mkdir(parents=True,exist_ok=True)
    native=platform.system()=='Linux' and platform.machine() in ([isa,'amd64'] if isa=='x86_64' else [isa])
    execute=native or bool(args.docker_container)
    if args.require_execution:assert execute, 'target execution unavailable'
    def run(command,inside=False,executable=False):
        command=[str(x) for x in command]
        if inside and args.docker_container:
            if executable or command[0].startswith(str(work)+"/"):command=[f'qemu-{isa}','-L',f'/usr/{isa}-linux-gnu']+command
            command=['docker','exec',args.docker_container]+[x.replace(str(docker_root),'/work') for x in command]
        return subprocess.run(command,text=True,capture_output=True,timeout=120)
    compiler=work/'lcb-snapshot';shutil.copy2(LCB,compiler)
    identity=run([compiler,'--build-identity']).stdout.strip()
    cc=os.environ.get('LCB_CROSS_CC',f'{isa}-linux-gnu-gcc') if args.docker_container else os.environ.get('LCB_CC','cc')
    qbe='/tmp/qbe/qbe'
    if native and not args.docker_container:
        oracle=work/'oracle'
        if not oracle.exists():shutil.copytree(ROOT/'third_party/qbe',oracle)
        result=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert result.returncode==0,result.stderr
        qbe=oracle/'qbe'
    rows=[];failures=[]
    for fixture in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
        case=work/fixture.stem;case.mkdir(exist_ok=True)
        source,assembly=case/'input.ssa',case/'lean.s';shutil.copy2(fixture,source)
        result=run([compiler,source,'--target',args.target,'-o',assembly])
        row={'fixture':fixture.name,'emitted':result.returncode==0,'diagnostic':result.stderr.strip(),'execution':'unmeasured'};rows.append(row)
        if result.returncode:
            if 'not yet implemented' not in result.stderr and fixture.name!='dark.ssa':failures.append((fixture.name,'unexpected rejection',result.stderr))
            continue
        if not execute:continue
        text=source.read_text();driver,expected=extract(text,'driver'),extract(text,'output')
        cfile=case/'driver.c';cfile.write_text(driver)
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,source],True)
        if result.returncode:failures.append((fixture.name,'QBE emission',result.stderr));continue
        statuses=[]
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;private=fixture.name.startswith('_')
            command=[cc,'-Wno-error=implicit-function-declaration','-Wno-error=implicit-int']
            if isa=='riscv64' and label=='qbe':command+=['-no-pie']
            command+=['-c',asm,'-o',exe] if private else ([cfile,asm,'-o',exe] if driver else [asm,'-o',exe])
            result=run(command,True)
            if result.returncode:
                failures.append((fixture.name,label+' assembly/link',result.stderr));statuses.append('failed');continue
            if private:statuses.append('assembled');continue
            result=run([exe,'a','b','c'],True,True)
            passed=(result.returncode>=0 and result.stdout.replace('\r','')==expected) if expected else result.returncode==0
            statuses.append('passed' if passed else 'failed')
            if not passed:failures.append((fixture.name,label+' execution',result.returncode,result.stdout,result.stderr,expected))
        row['execution']=statuses[0] if len(statuses)==2 and len(set(statuses))==1 else 'failed'
    if execute:
        from target_scalar import exercise
        exercise(compiler,work,run,cc,qbe,args.target,qtarget,24 if isa=='x86_64' else 8)
        from target_aggregate import exercise as aggregate_tests
        aggregate_tests(compiler,work,run,cc,qbe,args.target,qtarget)
        if isa=='riscv64':
            from riscv_abi import exercise as riscv_tests
            riscv_tests(compiler,work,run,cc)
        from target_tls import exercise as tls_tests
        tls_tests(compiler,work,run,cc,args.target)
    baseline=ROOT/f'tests/upstream-{isa}-coverage.json'
    if baseline.exists():
        missing=set(json.loads(baseline.read_text())['emitted'])-{x['fixture'] for x in rows if x['emitted']}
        failures.extend((x,'emission regression') for x in sorted(missing))
    mode='emulated' if args.docker_container else ('native' if native else 'not measured')
    report={'target':args.target,'compiler_identity':identity,'execution_mode':mode,'fixtures':rows,'failures':failures}
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{args.target}: {sum(x["emitted"] for x in rows)}/76 emitted; {sum(x["execution"]=="passed" for x in rows)} executable drivers and {sum(x["execution"]=="assembled" for x in rows)} assembly-only passes per Lean/QBE backend; execution={mode}',flush=True)
    for failure in failures:print(str(failure)[:3000],flush=True)
    assert not failures, f'{len(failures)} target failures'


if __name__=='__main__':main()
