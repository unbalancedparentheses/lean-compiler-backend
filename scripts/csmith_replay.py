#!/usr/bin/env python3
"""Replay a qualified Csmith report in another lowering mode using retained IR."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from cjson_benchmark import ROOT
from docker_sync import host_file


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-report',type=Path,required=True)
    ap.add_argument('--compiler',type=Path,default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--mode',choices=['baseline','allocated','optimized'],default='allocated')
    ap.add_argument('--work',type=Path,required=True)
    ap.add_argument('--report',type=Path,required=True)
    ap.add_argument('--docker-container',default='lcb-parity-linux')
    args=ap.parse_args()
    reference=json.loads(args.reference_report.read_text());assert reference['status']=='passed'
    target=reference['target'];isa=target.removesuffix('-linux')
    assert isa in ['aarch64','x86_64','riscv64']
    base=(ROOT/'.build/linux-arm64').resolve();origin=Path(reference['work']).resolve();work=args.work.resolve()
    assert origin.is_relative_to(base) and work.is_relative_to(base) and work!=origin and work!=base
    work.mkdir(parents=True,exist_ok=True)
    compiler=work/'lcb-snapshot';shutil.copy2(args.compiler,compiler)
    def run(command):
        return subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=120)
    def guest(command):
        return run(['docker','exec',args.docker_container,*[str(x).replace(str(base),'/work') for x in command]])
    identity=run([compiler,'--build-identity']);assert identity.returncode==0,identity.stderr
    report={'schema':1,'status':'running','target':target,'mode':args.mode,
        'compiler_identity':identity.stdout.strip(),'compiler_sha256':sha(compiler),'harness_sha256':sha(__file__),
        'reference_report_sha256':sha(args.reference_report),'reference_compiler_identity':reference['compiler_identity'],
        'reference_execution':'Reuses recorded GCC O0/O2 and unchanged QBE checksums; does not rerun those reference executables.',
        'execution_mode':reference['execution_mode'],'cases':[],
        'excluded_reference_attempts':len(reference['unqualified'])+len(reference.get('lcb_only_cases',[])),
        'notes':['Replay of existing seeds, not additional unique random programs.','Only common-reference qualified cases are replayed.','LCB executables use default link flags.']}
    cc='gcc' if isa=='aarch64' else isa+'-linux-gnu-gcc'
    runner=[] if isa=='aarch64' else ['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu']
    flags={'baseline':[],'allocated':['--allocate'],'optimized':['--optimize']}[args.mode]
    args.report.parent.mkdir(parents=True,exist_ok=True)
    for row in reference['cases']:
        seed=row['seed'];expected=row['outputs']['gcc-O0']
        assert row['outputs']['gcc-O2']==expected and row['outputs']['qbe']==expected
        case=work/str(seed);case.mkdir(exist_ok=True);old=origin/str(seed)
        assert sha(old/'input.c')==row['source_sha256'] and sha(old/'input.ssa')==row['ir_sha256']
        source=case/'input.ssa';shutil.copy2(old/'input.ssa',source);asm=case/'output.s';exe=case/'program'
        emitted=run([compiler,source,'--target',target,*flags,'-o',asm]);assert emitted.returncode==0,(seed,emitted.stderr)
        host_file(asm,base,args.docker_container)
        linked=guest([cc,asm,'-lm','-o',exe]);assert linked.returncode==0,(seed,linked.stderr)
        result=guest(['timeout','15',*runner,exe]);assert result.returncode==0 and result.stdout.strip()==expected,(seed,result.returncode,result.stdout,result.stderr,expected)
        report['cases'].append({'seed':seed,'ir_sha256':row['ir_sha256'],'assembly_sha256':sha(asm),'ir_lines':row['ir_lines'],'checksum':expected})
        if 'negative_control' not in report:
            text=asm.read_text();increment={'aarch64':'\tadd x0, x0, #1','x86_64':'\taddl $1, %eax','riscv64':'\taddi a0, a0, 1'}[isa]
            bad=case/'corrupted.s';bad.write_text(text.replace('\tret',increment+'\n\tret'));assert bad.read_text()!=text
            host_file(bad,base,args.docker_container);badexe=case/'corrupted'
            linked=guest([cc,bad,'-lm','-o',badexe]);assert linked.returncode==0,linked.stderr
            result=guest(['timeout','15',*runner,badexe]);assert result.returncode!=0 or result.stdout.strip()!=expected,'corrupted return escaped checksum oracle'
            report['negative_control']={'seed':seed,'status':'detected','exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
        args.report.write_text(json.dumps(report,indent=2)+'\n')
        print(f'{target} {args.mode} replay {seed}: {expected}',flush=True)
    report['status']='passed';report['cases_passed']=len(report['cases']);args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: {len(report["cases"])} existing seeds replayed in {args.mode}; corruption detected',flush=True)


if __name__=='__main__':main()
