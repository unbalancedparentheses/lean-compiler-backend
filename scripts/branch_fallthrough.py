#!/usr/bin/env python3
"""AMD64/RV64 next-block fallthrough with independent C and unchanged QBE."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB
from unused_environment import native_target
from arm_branch_layout import fixture as branch_fixture, SEEDS

TARGETS={'x86_64-linux':'amd64_sysv','x86_64-macos':'amd64_apple','riscv64-linux':'rv64'}


def fixture():
    ir,c=branch_fixture()
    ir+='''export function l $fallthrough_jump(l %a) {
@start
 jmp @next
@next
 %r =l add %a,7
 ret %r
@wrong
 ret 0
}
dbgfile "fallthrough source.c"
export function l $debug_phi(l %a,l %b,w %pick) {
@start
 dbgloc 1001,2
 jnz %pick,@yes,@no
@no
 dbgloc 1002,3
 jmp @join
@yes
 dbgloc 1003,4
 jmp @join
@join
 %r =l phi @yes %a,@no %b
 dbgloc 1004,5
 ret %r
}
'''
    c=c.replace('int main(void){','extern uint64_t fallthrough_jump(uint64_t),debug_phi(uint64_t,uint64_t,uint32_t);\nint main(void){')
    c=c.replace('}return 0;}','if(fallthrough_jump(a)!=a+7)return 5;if(debug_phi(a,b,0)!=b||debug_phi(a,b,1)!=a)return 6;}return 0;}')
    return ir,c


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None):
    assert target in TARGETS
    case=Path(work)/'branch-fallthrough';case.mkdir(parents=True,exist_ok=True)
    src,c=case/'input.ssa',case/'caller.c';ir,ct=fixture();src.write_text(ir);c.write_text(ct)
    obj=case/'caller.o';jump='\tj ' if target=='riscv64-linux' else '\tjmp '
    adjacent=re.escape(jump)+r'([^\n]+)\n\1:'
    if execute:
        r=run([cc,'-O2','-c',c,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(mode+'.s'),case/mode
        r=run([compiler,'--target',target,*flags,src,'-o',asm]);assert r.returncode==0,r.stderr
        text=asm.read_text();count=len(re.findall(adjacent,text))
        assert (count>0) if mode=='baseline' else (count==0),(mode,count)
        for line,col in [(1001,2),(1002,3),(1003,4),(1004,5)]:
            assert re.search(r'\t\.loc \d+ '+str(line)+' '+str(col)+r'\n',text),(mode,line)
        modes[mode]={'status':'emitted','jump_to_next_label':count}
        if execute:
            r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr);modes[mode]['status']='passed'
    if execute:
        asm,exe=case/'wrong-target.s',case/'wrong-target'
        text=(case/'allocated.s').read_text();stem=('L' if target.endswith('macos') else '.L')+'_lcb_9_debug_phi_'
        needle=stem+'no:\n';assert text.count(needle)==1
        asm.write_text(text.replace(needle,jump+stem+'yes\n'+needle,1))
        r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==6,'wrong fallthrough target escaped independent C oracle'
    if execute and qbe:
        asm,exe=case/'qbe.s',case/'qbe'
        r=run([qbe,'-t',qtarget or TARGETS[target],'-o',asm,src],True);assert r.returncode==0,r.stderr
        flags=['-no-pie'] if target=='riscv64-linux' else []
        r=run([cc,*flags,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==0,r.stderr
    report={'target':target,'modes':modes,'c_checks_per_mode':72*len(SEEDS)**2 if execute else 0,
            'wrong_target_detected':execute,'original_qbe':'passed' if execute and qbe else 'not_executed',
            'qbe_link_flags':['-no-pie'] if execute and qbe and target=='riscv64-linux' else []}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');a=ap.parse_args()
    target=native_target();execute=target in TARGETS
    if a.require_native:assert execute,'AMD64 or RV64 native target required'
    target=target if execute else 'x86_64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-fallthrough-') as d:
        work=Path(d);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target,execute,qbe)


if __name__=='__main__':main()
