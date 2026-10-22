#!/usr/bin/env python3
"""Compare exact assembly/refusals from two immutable compiler snapshots."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import re
import sys
sys.path.insert(0, str(Path.cwd()/"scripts"))
from fuzz import ROOT

TARGETS=['aarch64-macos','aarch64-linux','x86_64-macos','x86_64-linux','riscv64-linux']
MODES={'baseline':[],'allocated':['--allocate'],'optimized':['--optimize']}


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--before',type=Path,required=True)
    ap.add_argument('--after',type=Path,required=True)
    ap.add_argument('--report',type=Path,required=True)
    args=ap.parse_args()
    work=Path(tempfile.mkdtemp(prefix='emission-equivalence-',dir=ROOT/'.build'))
    compilers={}
    report={'schema':1,'status':'running','work':str(work),'harness_sha256':sha(__file__),'compilers':{},'cases':[]}
    for label,path in [('before',args.before),('after',args.after)]:
        compiler=work/label;shutil.copy2(path,compiler);compilers[label]=compiler
        identity=subprocess.run([compiler,'--build-identity'],capture_output=True,text=True,check=True).stdout.strip()
        report['compilers'][label]={'identity':identity,'sha256':sha(compiler)}
    inputs=sorted({*ROOT.glob('examples/*.ssa'),*ROOT.glob('tests/regressions/*.ssa'),*ROOT.glob('third_party/qbe/test/*.ssa')})
    jobs=[(i,path,target,mode) for i,path in enumerate(inputs) for target in TARGETS for mode in MODES]
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    def compare(job):
        i,path,target,mode=job
        row={'input':str(path.relative_to(ROOT)),'source_sha256':sha(path),'target':target,'mode':mode,'status':'running'}
        results={}
        try:
            for label,compiler in compilers.items():
                out=work/f'{i}-{target}-{mode}-{label}.s'
                result=subprocess.run([compiler,path,'--target',target,*MODES[mode],'-o',out],capture_output=True,timeout=120)
                results[label]=(result,out)
                row[label]={'exit':result.returncode,'stdout':result.stdout.decode(errors='replace'),'stderr':result.stderr.decode(errors='replace')}
                if result.returncode==0:row[label]['assembly_sha256']=sha(out)
            old,new=results['before'][0],results['after'][0]
            assert old.returncode==new.returncode,'exit status differs'
            if old.returncode==0:
                expected=results['before'][1].read_bytes()
                row['removed_normalization_pairs']=0
                if target=='riscv64-linux':
                    expected,count=re.subn(rb'(\t(?:lbu|lhu|lwu) t0, -?\d+\(t0\))\n\tslli t0, t0, 32\n\tsrli t0, t0, 32',rb'\1',expected)
                    row['removed_normalization_pairs']=count
                assert expected==results['after'][1].read_bytes(),'assembly differs from precisely expected unsigned-load mask removal'
                row['status']='expected_assembly'
            else:
                assert old.stdout==new.stdout and old.stderr==new.stderr,'refusal diagnostics differ'
                row['status']='identical_refusal'
        except Exception as error:
            row['status']='failed';row['failure']=repr(error)
        return row
    with ThreadPoolExecutor(max_workers=4) as pool:
        for row in pool.map(compare,jobs):
            report['cases'].append(row)
    report['input_files']=len(inputs)
    report['attempts']=len(jobs)
    report['expected_assemblies']=sum(r['status']=='expected_assembly' for r in report['cases'])
    report['identical_refusals']=sum(r['status']=='identical_refusal' for r in report['cases'])
    report['failures']=sum(r['status']=='failed' for r in report['cases'])
    report['status']='failed' if report['failures'] else 'passed'
    report['notes']=['RV output differs only by removed unsigned-load mask pairs; other targets remain byte-identical. This corpus comparison is not a preservation proof.',
                     'Refusals are counted separately from successfully emitted assemblies; no target execution is measured here.']
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(f"{report['expected_assemblies']} expected assemblies; {report['identical_refusals']} identical refusals; {report['failures']} failures; {args.report}",flush=True)
    if report['failures']:raise SystemExit(1)


if __name__=='__main__':main()
