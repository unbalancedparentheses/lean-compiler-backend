#!/usr/bin/env python3
"""RV64 immediate selection checked against independent unsigned C arithmetic."""
import json
from pathlib import Path

CONSTANTS=[-(1<<63),-(1<<32)-1,-(1<<32),-4096,-2049,-2048,-2047,-65,-64,-33,-32,-1,0,1,7,31,32,33,63,64,65,255,1023,2047,2048,2049,4095,4096,(1<<31)-1,1<<31,(1<<32)-1,1<<32,(1<<32)+1,(1<<63)-1,1<<63,(1<<64)-1]
OPS=['add','sub','and','or','xor','shl','shr','sar']
SEEDS=sorted(set([0,1,(1<<64)-1]+[v for bit in range(64) for v in [(1<<bit)-1,1<<bit,((1<<bit)+1)&((1<<64)-1)]]))


def fixture(qbe_profile=False):
    ir=[];c=['#include <stdint.h>\n']
    checks=[]
    for width in [32,64]:
        for op in OPS:
            for n in CONSTANTS:
                if qbe_profile and op in ['shl','shr','sar'] and not 0<=n<width:continue
                name=f'case_{len(checks)}';kind='w' if width==32 else 'l'
                ir.append(f'export function l ${name}(l %x) {{\n@s\n %v ={kind} {op} %x,{n}\n'+(' %r =l extuw %v\n ret %r\n}\n' if width==32 else ' ret %v\n}\n'))
                c.append(f'extern uint64_t {name}(uint64_t);\n')
                checks.append(f'if({name}(x)!=reference(x,UINT64_C({n&((1<<64)-1)}),{width},{OPS.index(op)}))return 1;\n')
    c.append('''static uint64_t reference(uint64_t x,uint64_t y,unsigned width,unsigned op){
 uint64_t mask=width==32?UINT64_C(0xffffffff):UINT64_MAX;
 uint64_t a=x&mask,b=y&mask,r=0;unsigned shift=(unsigned)(y&(width-1));
 switch(op){case 0:r=a+b;break;case 1:r=a-b;break;case 2:r=a&b;break;
 case 3:r=a|b;break;case 4:r=a^b;break;case 5:r=a<<shift;break;
 case 6:r=a>>shift;break;case 7:r=a>>shift;
 if(shift && (a&(UINT64_C(1)<<(width-1))))r|=mask^(mask>>shift);break;}
 return r&mask;}
''')
    c.append('static const uint64_t seeds[]={'+','.join(f'UINT64_C({v})' for v in SEEDS)+'};\nint main(void){for(unsigned i=0;i<sizeof(seeds)/sizeof(*seeds);i++){uint64_t x=seeds[i];\n'+''.join(checks)+'}return 0;}\n')
    return ''.join(ir),''.join(c)


def exercise(compiler,work,run,cc,target='riscv64-linux',execute=True,qbe=None,qtarget='rv64'):
    assert target=='riscv64-linux'
    case=Path(work)/'rv-immediates';case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c=fixture();source.write_text(ir);caller.write_text(c)
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-O2','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
        if mode=='qbe' and not(execute and qbe):continue
        asm,exe=case/(mode+'.s'),case/mode
        mode_source,mode_obj=source,obj
        if mode=='qbe':
            # Pinned RV QBE emits invalid immediates for oversized constant shifts.
            # Keep all boundary cases mandatory for LCB; compare only legal counts.
            mode_source,qcaller=case/'qbe-profile.ssa',case/'qbe-profile.c'
            qi,qc=fixture(True);mode_source.write_text(qi);qcaller.write_text(qc)
            mode_obj=case/'qbe-profile.o'
            r=run([cc,'-O2','-c',qcaller,'-o',mode_obj],True);assert r.returncode==0,r.stderr
        r=run([qbe,'-t',qtarget,'-o',asm,mode_source] if mode=='qbe' else [compiler,'--target',target,*flags,source,'-o',asm],mode=='qbe');assert r.returncode==0,(mode,r.stderr)
        modes[mode]='emitted'
        if execute:
            r=run([cc,mode_obj,asm,'-o',exe]+(['-no-pie'] if mode=='qbe' else []),True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr);modes[mode]='passed'
    if execute:
        original=(case/'baseline.s').read_text();mutated=original.replace('\taddiw t0, t0, 1\n','\taddiw t0, t0, 2\n',1);assert mutated!=original
        asm,exe=case/'wrong-immediate.s',case/'wrong-immediate';asm.write_text(mutated)
        r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==1,'wrong immediate escaped independent C oracle'
    report={'target':target,'functions':2*len(OPS)*len(CONSTANTS),'seeds':len(SEEDS),'checks_per_mode':2*len(OPS)*len(CONSTANTS)*len(SEEDS),'modes':modes,'wrong_immediate_detected':execute,'qbe_profile':'all arithmetic/bitwise constants; only 0 <= constant shift < width','qbe_functions':fixture(True)[0].count('export function')}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    import argparse
    import os
    import shutil
    import subprocess
    import tempfile
    from fuzz import ROOT, LCB
    from unused_environment import native_target
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native',action='store_true')
    args=ap.parse_args();execute=native_target()=='riscv64-linux'
    if args.require_native:assert execute,'native RV64 target required'
    def run(cmd,inside=False):
        return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-rv-immediates-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,execute=execute,qbe=qbe)


if __name__=='__main__':main()
