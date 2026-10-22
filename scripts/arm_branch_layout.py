#!/usr/bin/env python3
"""ARM empty-edge layout: independent C branches, phi cycles and expanded range."""
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

SEEDS = [0,1,2,7,255,65535,0x7fffffff,0x80000000,0xffffffff,0x100000000,
         0x7fffffffffffffff,0x8000000000000000,0xffffffffffffffff]
OPS = [('eq','==',False),('ne','!=',False),('slt','<',True),('sle','<=',True),
       ('sgt','>',True),('sge','>=',True),('ult','<',False),('ule','<=',False),
       ('ugt','>',False),('uge','>=',False)]


def fixture():
    ir=[];decl=[];checks=[]
    for width,bits in [('w',32),('l',64)]:
        for op,cmp,signed in OPS:
            for layout in ['yes_first','no_first','same_target']:
                name=f'{op}_{width}_{layout}'
                branches='@yes, @yes' if layout=='same_target' else '@yes, @no'
                blocks=['@yes\n ret 11','@no\n ret 23']
                if layout=='no_first': blocks.reverse()
                if layout=='same_target':blocks=blocks[:1]
                ir.append(f'export function l ${name}({width} %a,{width} %b) {{\n@s\n %c =w c{op}{width} %a,%b\n jnz %c,{branches}\n'+ '\n'.join(blocks)+'\n}\n')
                typ=f'{"int" if signed else "uint"}{bits}_t'
                expected='11' if layout=='same_target' else f'((({typ})a {cmp} ({typ})b)?11:23)'
                decl.append(f'extern uint64_t {name}(uint{bits}_t,uint{bits}_t);')
                checks.append(f'if({name}(a,b)!={expected})return 1;')
    ir.append('''export function l $truth(w %a) {
@s
 jnz %a,@yes,@no
@yes
 ret 11
@no
 ret 23
}
export function l $phi_cycle(l %a,l %b,w %n) {
@s
 jmp @loop
@loop
 %x =l phi @s %a,@body %y
 %y =l phi @s %b,@body %x
 %i =w phi @s %n,@body %next
 jnz %i,@body,@done
@body
 %next =w sub %i,1
 jmp @loop
@done
 ret %x
}
export function l $phi_edges(l %a,l %b,w %pick,w %loop) {
@s
 jnz %pick,@yes,@no
@yes
 %x =l phi @s %a,@again %b
 jnz %loop,@again,@done
@again
 jmp @yes
@no
 ret %b
@done
 ret %x
}
''')
    # phi_edges runs only with loop=0; the other predecessor forces a real phi.
    decl += ['extern uint64_t truth(uint32_t);','extern uint64_t phi_cycle(uint64_t,uint64_t,uint32_t);','extern uint64_t phi_edges(uint64_t,uint64_t,uint32_t,uint32_t);']
    checks += ['if(truth(a)!=((uint32_t)a?11:23))return 2;',
               'for(unsigned n=0;n<6;n++)if(phi_cycle(a,b,n)!=((n&1)?b:a))return 3;',
               'if(phi_edges(a,b,0,0)!=b||phi_edges(a,b,1,0)!=a)return 4;']
    c='#include <stdint.h>\n'+ '\n'.join(decl)+'\nstatic const uint64_t seeds[]={'+','.join(f'UINT64_C({x})' for x in SEEDS)+'};\nint main(void){for(unsigned i=0;i<sizeof(seeds)/sizeof(*seeds);i++)for(unsigned j=0;j<sizeof(seeds)/sizeof(*seeds);j++){uint64_t a=seeds[i],b=seeds[j];'+''.join(checks)+'}return 0;}\n'
    return ''.join(ir),c


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None,large=True):
    assert target in ['aarch64-linux','aarch64-macos']
    case=Path(work)/'arm-branch-layout';case.mkdir(parents=True,exist_ok=True)
    src,c=case/'input.ssa',case/'caller.c';ir,ct=fixture();src.write_text(ir);c.write_text(ct)
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-O2','-c',c,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(mode+'.s'),case/mode
        r=run([compiler,'--target',target,*flags,src,'-o',asm]);assert r.returncode==0,r.stderr
        text=asm.read_text();modes[mode]='emitted'
        if mode!='baseline':
            assert re.search(r'\tb\.\w+ L_lcb_block_.*_no\nL_lcb_block_.*_yes:',text), 'direct conditional missing'
        if execute:
            r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr);modes[mode]='passed'
    if execute:
        asm,exe=case/'wrong-target.s',case/'wrong-target'
        text=(case/'optimized.s').read_text()
        text,n=re.subn(r'(\tb\.\w+ L_lcb_block_\S+)_no\n(L_lcb_block_\S+_yes:)',r'\1_yes\n\2',text,count=1)
        assert n==1
        asm.write_text(text);r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==1,'wrong conditional target escaped independent C oracle'
    if execute and qbe:
        asm,exe=case/'qbe.s',case/'qbe'
        r=run([qbe,'-t',qtarget,'-o',asm,src],True);assert r.returncode==0,r.stderr
        r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==0,r.stderr
    large_modes={}
    if large:
        big=case/'large.ssa';caller=case/'large.c'
        big.write_text('export function w $large(w %c,l %p) {\n@s\n jnz %c,@body,@end\n@body\n'+
                       ' storel 81985529216486895,%p\n'*55000+' ret 1\n@end\n ret 2\n}\n')
        caller.write_text('#include <stdint.h>\nextern unsigned large(unsigned,void*);int main(void){uint64_t x=0;if(large(0,&x)!=2||x)return 1;if(large(1,&x)!=1||x!=UINT64_C(81985529216486895))return 2;return 0;}\n')
        for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
            asm,exe=case/('large-'+mode+'.s'),case/('large-'+mode)
            r=run([compiler,'--target',target,*flags,big,'-o',asm]);assert r.returncode==0,r.stderr
            text=asm.read_text();assert text.count('\n')*4>1024*1024
            assert re.search(r'\tcbz w\d+, L_lcb_edge_5_large_s\n\tb L_lcb_block_5_large_body\nL_lcb_edge_5_large_s:\n\tb L_lcb_block_5_large_end',text),'expanded large function lost nearby trampoline'
            large_modes[mode]={'status':'emitted','physical_lines':text.count('\n')}
            if execute:
                r=run([cc,caller,asm,'-o',exe],True);assert r.returncode==0,r.stderr
                r=run([exe],True);assert r.returncode==0,(mode,r.stderr);large_modes[mode]['status']='passed'
    report={'target':target,'modes':modes,'c_checks_per_mode':69*len(SEEDS)**2 if execute else 0,
            'wrong_target_detected':execute,'original_qbe': 'passed' if execute and qbe else 'not_executed',
            'large_expanded_function':large_modes}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');a=ap.parse_args()
    target=native_target();execute=target in ['aarch64-linux','aarch64-macos']
    if a.require_native:assert execute,'ARM native target required'
    target=target if execute else 'aarch64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-arm-branch-') as d:
        work=Path(d);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target,execute,qbe,'arm64_apple' if target.endswith('macos') else 'arm64')


if __name__=='__main__':main()
