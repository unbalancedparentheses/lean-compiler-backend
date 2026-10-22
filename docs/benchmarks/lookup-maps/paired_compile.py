#!/usr/bin/env python3
"""Interleaved unchanged-IR emission timings; byte equality, not runtime proof."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import time


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    for name in ['before','after','qbe','input','work']:
        ap.add_argument('--'+name,type=Path,required=True)
    ap.add_argument('--rounds',type=int,default=3)
    args=ap.parse_args();assert args.rounds>=1
    args.work.mkdir(parents=True,exist_ok=True)
    source=args.work/'input.ssa';shutil.copy2(args.input,source)
    report={'schema':1,'method':'Alternating before/after order per round; warmed process startup; same unchanged IR and target; wall time includes all compiler checks and emission; no concurrent jobs from this worker during timed campaign.',
            'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'host':platform.platform(),'machine':platform.machine(),'target':'aarch64-linux',
            'input_sha256':sha(source),'input_bytes':source.stat().st_size,'harness_sha256':sha(__file__),
            'compilers':{},'samples':[],'notes':['Executable correctness is separately qualified by the retained large-structure comparison.','Original QBE is unchanged pinned source; no corrected oracle.','These are local measurements, not general speed or parity claims.']}
    compilers={}
    for name in ['before','after','qbe']:
        original=getattr(args,name);binary=args.work/(name+'-snapshot');shutil.copy2(original,binary);compilers[name]=binary
        metadata={'sha256':sha(binary)}
        if name!='qbe':metadata['identity']=subprocess.check_output([binary,'--build-identity'],text=True).strip()
        else:subprocess.run([binary,'-h'],capture_output=True,check=True)
        report['compilers'][name]=metadata
    hashes={}
    for round_index in range(args.rounds):
        for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
            for name in (['before','after'] if round_index%2==0 else ['after','before']):
                out=args.work/f'{name}-{mode}.s'
                start=time.perf_counter()
                subprocess.run([compilers[name],source,'--target','aarch64-linux',*flags,'-o',out],capture_output=True,check=True,timeout=180)
                elapsed=time.perf_counter()-start;digest=sha(out)
                key=(name,mode);assert key not in hashes or hashes[key]==digest,'nondeterministic assembly'
                hashes[key]=digest
                row={'round':round_index,'compiler':name,'mode':mode,'seconds':elapsed,'assembly_sha256':digest,'assembly_bytes':out.stat().st_size}
                report['samples'].append(row);print(row,flush=True)
            assert hashes['before',mode]==hashes['after',mode],f'{mode}: output changed'
        out=args.work/'qbe.s';start=time.perf_counter()
        subprocess.run([compilers['qbe'],'-t','arm64','-o',out,source],capture_output=True,check=True,timeout=180)
        report['samples'].append({'round':round_index,'compiler':'qbe','mode':'qbe','seconds':time.perf_counter()-start,'assembly_sha256':sha(out),'assembly_bytes':out.stat().st_size})
    report['medians']={name:{mode:statistics.median(x['seconds'] for x in report['samples'] if x['compiler']==name and x['mode']==mode)
                     for mode in (['qbe'] if name=='qbe' else ['baseline','allocated','optimized'])} for name in compilers}
    report['all_before_after_assemblies_identical']=True
    (args.work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['medians']),flush=True)


if __name__=='__main__':main()
